# frozen_string_literal: true

# Coverage must be started before any application code is loaded. Set
# COVERAGE=false to skip the instrumentation (e.g. for a quick focused run, or
# for a mutation run, where the per-mutant runtime is what matters).
require "simplecov"

unless ENV["COVERAGE"] == "false"
  SimpleCov.start do
    skip "/test/"
    skip "/config/"
    skip "/db/"
    skip "/vendor/"
    skip "/lib/"
    enable_coverage :branch
    minimum_coverage line: 80, branch: 85
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "json"
require "yaml"

# `mutant-minitest` supplies the `cover` declaration the mutation-test classes use
# (see `.mutant.yml` and `bin/mutation`). Loading it here keeps those declarations
# defined for an ordinary `bin/rails test` run; the extension only records the
# expressions a test class claims, it does not change how the suite runs.
begin
  require "mutant/minitest/coverage"
rescue LoadError
  # The `mutation` bundle group is optional (BUNDLE_WITHOUT=mutation): without the
  # gem the declaration is a plain no-op and the suite runs unchanged.
  Minitest::Test.define_singleton_method(:cover) { |_expression| }
end

# Runtime fixtures for the RefineGuard test suite
# The suite deliberately builds its data through the same objects the seeds use
# (organizations, roles, OrgRolePermission, UserRole) instead of YAML fixtures,
# because the *hierarchy* of those rows is what authorization actually depends
# on: `OrgRolePermission[(organization, role)]` is the permission chain, and a
# missing row is a silent default-deny.
module RefineguardTestData
  BLUEPRINT_DIR = Rails.root.join(".rhino/blueprints")
  ROLES = %w[admin reliability_engineer machinery_specialist maintenance_planner
             operations_superintendent].freeze

  ALL_ACTIONS = %w[index show store update destroy trashed restore forceDelete].freeze

  class << self
    # role_slug => { model_slug => [actions] } straight from the blueprints.
    def blueprint_permissions
      @blueprint_permissions ||= begin
        matrix = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }

        Dir.glob(File.join(BLUEPRINT_DIR, "*.yaml")).sort.each do |path|
          next if File.basename(path).start_with?("_")

          blueprint = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ], aliases: true)
          slug = blueprint["slug"]
          (blueprint["permissions"] || {}).each do |role, config|
            matrix[role][slug] = Array(config["actions"])
          end
        end

        matrix
      end
    end

    def model_slugs
      blueprint_permissions.values.flat_map(&:keys).uniq.sort
    end

    # role_slug => { model_slug => { create_fields:, update_fields: } } from the
    # blueprints. '*' means every column; [] means none.
    def blueprint_writable_fields
      @blueprint_writable_fields ||= begin
        matrix = {}

        Dir.glob(File.join(BLUEPRINT_DIR, "*.yaml")).sort.each do |path|
          next if File.basename(path).start_with?("_")

          blueprint = YAML.safe_load(File.read(path), permitted_classes: [ Symbol ], aliases: true)
          slug = blueprint["slug"]
          (blueprint["permissions"] || {}).each do |role, config|
            matrix[role] ||= {}
            matrix[role][slug] = {
              create_fields: config["create_fields"] || [],
              update_fields: config["update_fields"] || []
            }
          end
        end

        matrix
      end
    end

    # Role slug => ["slug.action", ...] with the extra read grants the SPA needs.
    def permission_list
      list = Hash.new { |h, k| h[k] = [] }
      blueprint_permissions.each do |role, models|
        models.each do |slug, actions|
          actions.each { |action| list[role] << "#{slug}.#{action}" }
        end
      end

      ROLES.each { |role| list[role] |= [ "users.index", "users.show" ] }
      list["admin"] |= [ "roles.index", "roles.show" ]
      list
    end
  end
end

module ActiveSupport
  class TestCase
    # The suite drives a single Postgres database and builds its own tenancy
    # graph, so it runs in-process (transactional) rather than forked.
    parallelize(workers: 1)

    # No YAML fixtures — every test builds what it needs through `setup_runtime`.
    self.use_transactional_tests = true

    include RefineguardTestData

    def teardown
      RequestStore.clear! if defined?(RequestStore)
      super
    end
  end
end

class ActionDispatch::IntegrationTest
  # Build the tenancy graph once per test:
  #   demo-org + runtime-other-org, the five blueprint roles, one identity per
  #   role plus the three host-contract identities, and the permission chain.
  def setup_runtime
    @demo_org = Organization.find_or_create_by!(slug: "demo-org") { |o| o.name = "Demo Org" }
    @other_org = Organization.find_or_create_by!(slug: "runtime-other-org") { |o| o.name = "Other Org" }

    @roles = RefineguardTestData::ROLES.index_with do |slug|
      Role.find_or_create_by!(slug: slug) { |r| r.name = slug.titleize }
    end

    matrix = RefineguardTestData.permission_list

    @roles.each do |slug, role|
      [ @demo_org, @other_org ].each do |org|
        record = OrgRolePermission.find_or_initialize_by(organization: org, role: role)
        record.permissions = matrix[slug]
        record.save!
      end
    end

    @admin = create_user("administrator@example.com", @roles["admin"], @demo_org)
    @viewer = create_user("viewer@example.com", @roles["reliability_engineer"], @demo_org)
    @engineer = create_user("reliability_engineer@example.com", @roles["reliability_engineer"], @demo_org)
    @specialist = create_user("machinery_specialist@example.com", @roles["machinery_specialist"], @demo_org)
    @planner = create_user("maintenance_planner@example.com", @roles["maintenance_planner"], @demo_org)
    @superintendent = create_user("operations_superintendent@example.com",
                                  @roles["operations_superintendent"], @demo_org)
    @outsider = create_user("outsider@example.com", @roles["reliability_engineer"], @other_org)

    @unit = PlantUnit.create!(organization: @demo_org, unit_code: "CDU-1",
                             unit_name: "Crude Distillation Unit 1", rate_percent: 92.0,
                             exposure_usd_per_day: 418_000.0,
                             derate_recommendation: "Reduce charge rate by 8%.")
    @asset = Asset.create!(organization: @demo_org, asset_tag: "P-204A",
                          asset_name: "Crude charge pump A", equipment_class: "Centrifugal Pump",
                          plant_unit: @unit, health_state: "Trip", health_index: 28.0,
                          health_index_delta: -33.0, rms_velocity_mms: 8.42, bearing_temp_c: 96.0,
                          estimated_rul_days: 8.5, estimated_rul_window: "6–11 d",
                          bearing_de_model: "SKF 6314 C3", bearing_nde_model: "SKF 7314 BECBM",
                          rated_rpm: 1795.0, monitored: true,
                          last_sample_at: Time.current - 12.seconds,
                          data_completeness_pct: 98.4,
                          hierarchy_path: "BRR Complex / CDU-1 / P-204A")
    @healthy_asset = Asset.create!(organization: @demo_org, asset_tag: "P-101B",
                                  asset_name: "Crude charge pump B", equipment_class: "Centrifugal Pump",
                                  plant_unit: @unit, health_state: "Normal", health_index: 96.0,
                                  rms_velocity_mms: 1.04, bearing_temp_c: 39.0,
                                  monitored: true, last_sample_at: Time.current - 5.seconds,
                                  data_completeness_pct: 99.4)
    @other_asset = Asset.create!(organization: @other_org, asset_tag: "X-900A",
                                asset_name: "Other org pump", equipment_class: "Centrifugal Pump",
                                health_state: "Normal", health_index: 91.0, monitored: true)
    @failure_mode = FailureMode.create!(organization: @demo_org,
                                        iso_code: "ISO14224-MECH-BRG-BPFO",
                                        failure_name: "Bearing Outer Race Defect (BPFO)",
                                        equipment_category: "Centrifugal Pump", severity_weight: 0.85)
  end

  def create_user(email, role, organization)
    user = User.find_or_initialize_by(email: email)
    user.name = email.split("@").first.titleize
    user.first_name = "Test"
    user.last_name = "User"
    user.approved = true
    user.password = "password" if user.new_record? || user.password_digest.blank?
    user.api_token ||= SecureRandom.hex(32)
    user.failed_login_attempts = 0
    user.locked_at = nil
    user.save!

    UserRole.find_or_create_by!(user: user, organization: organization, role: role)
    user
  end

  def auth_headers(user)
    { "Authorization" => "Bearer #{user.reload.api_token}" }
  end

  def json_headers(user = nil)
    headers = { "Content-Type" => "application/json" }
    headers.merge!(auth_headers(user)) if user
    headers
  end

  def json_body
    JSON.parse(response.body)
  rescue JSON::ParserError
    response.body
  end
end
