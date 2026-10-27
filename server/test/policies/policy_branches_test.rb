# frozen_string_literal: true

require "test_helper"

# Every policy's attribute surfaces and custom-action gates, evaluated for each
# role and for an anonymous caller.
#
# The point is branch completeness: each policy decides its permitted-field set
# and its custom-action gates with a chain of `has_role?` checks, and the only way
# to prove a role is handled is to call the method as that role. An anonymous
# caller (nil user) must never raise.
class PolicyBranchesTest < ActiveSupport::TestCase
  # Mutation coverage: this test calls every method of these policies for every
  # role and for an anonymous caller, so it is the unit-level killer for them.
  cover "AssetPolicy"
  cover "PrescriptiveAdvisoryPolicy"
  cover "DiagnosticIncidentPolicy"
  cover "CmmsWorkOrderPolicy"
  cover "HistorianConnectorPolicy"
  cover "SecurityAuditEventPolicy"

  ROLE_SLUGS = %w[admin reliability_engineer machinery_specialist maintenance_planner
                  operations_superintendent].freeze

  # The exact, role-scoped attribute surface each policy must return.
  #
  # These are asserted by VALUE, not merely by type: a mutant that drops a field,
  # widens a list to a role that must not hold it, or replaces the whole body with
  # `super` changes the returned set and is killed. The expected sets are the
  # reviewed field-visibility contract — the blueprint-declared writable fields
  # (create/update) plus the deliberate per-role `show`/`hide` decisions.
  SURFACES = {
    AssetPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [ "*" ], update: [ "*" ] },
      "reliability_engineer" => { show: [ "*" ], hidden: [], create: [], update: [] },
      "machinery_specialist" => {
        show: [ "*" ], hidden: [],
        create: %w[plant_unit_id parent_asset_id asset_tag asset_name equipment_class
                   equipment_type driver_type criticality_class manufacturer commissioned_on
                   design_speed_rpm rated_rpm rated_flow_m3h max_bearing_temp_c bearing_type
                   bearing_de_model bearing_nde_model seal_plan operating_status],
        update: %w[plant_unit_id parent_asset_id asset_tag asset_name equipment_class
                   equipment_type driver_type criticality_class manufacturer commissioned_on
                   design_speed_rpm rated_rpm rated_flow_m3h max_bearing_temp_c bearing_type
                   bearing_de_model bearing_nde_model seal_plan operating_status]
      },
      "maintenance_planner" => {
        show: %w[id asset_tag asset_name equipment_class plant_unit_id criticality_class
                 health_state health_index bearing_type seal_plan operating_status],
        hidden: %w[motor_current_a data_completeness_pct hierarchy_path], create: [], update: []
      },
      "operations_superintendent" => {
        show: [ "*" ],
        hidden: %w[manufacturer commissioned_on bearing_de_model bearing_nde_model
                   last_tag_validation_at],
        create: [], update: []
      }
    },
    PrescriptiveAdvisoryPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [ "*" ], update: [ "*" ] },
      "reliability_engineer" => {
        show: [ "*" ], hidden: [], create: [],
        update: %w[urgency status due_within_days recommended_action]
      },
      "machinery_specialist" => { show: [ "*" ], hidden: [], create: [], update: [] },
      "maintenance_planner" => {
        show: [ "*" ], hidden: [],
        create: %w[diagnostic_incident_id advisory_code recommended_action action_steps_json
                   throttle_percentage parts_required_json warehouse_status warehouse_bin
                   parts_lead_time_days urgency status due_within_days],
        update: %w[diagnostic_incident_id advisory_code recommended_action action_steps_json
                   throttle_percentage parts_required_json warehouse_status warehouse_bin
                   parts_lead_time_days urgency status due_within_days]
      },
      "operations_superintendent" => {
        show: [ "*" ], hidden: [], create: [],
        update: %w[throttle_percentage derate_approved_at status standby_asset_id standby_ready]
      }
    },
    DiagnosticIncidentPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [ "*" ], update: [ "*" ] },
      "reliability_engineer" => {
        show: [ "*" ], hidden: [],
        create: %w[asset_id failure_mode_id incident_code status severity_level health_state
                   rul_days_estimate rul_window_low_days rul_window_high_days rul_confidence_pct
                   pf_interval_days regime regime_confidence_pct acknowledged_at detected_at
                   resolved_at],
        update: %w[asset_id failure_mode_id incident_code status severity_level health_state
                   rul_days_estimate rul_window_low_days rul_window_high_days rul_confidence_pct
                   pf_interval_days regime regime_confidence_pct acknowledged_at detected_at
                   resolved_at]
      },
      "machinery_specialist" => {
        show: [ "*" ], hidden: [],
        create: %w[root_cause evidence_summary failure_mechanism finding_confidence finding_status
                   signed_off_at status severity_level acknowledged_at resolved_at],
        update: %w[root_cause evidence_summary failure_mechanism finding_confidence finding_status
                   signed_off_at status severity_level acknowledged_at resolved_at]
      },
      "maintenance_planner" => {
        show: [ "*" ], hidden: [], create: [], update: %w[status severity_level]
      },
      "operations_superintendent" => {
        show: %w[id asset_id incident_code status severity_level health_state rul_days_estimate
                 rul_window_low_days rul_window_high_days pf_interval_days regime detected_at],
        hidden: [], create: [], update: []
      }
    },
    CmmsWorkOrderPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [ "*" ], update: [ "*" ] },
      "reliability_engineer" => {
        show: [ "*" ], hidden: [],
        create: %w[prescriptive_advisory_id cmms_type priority required_by work_order_payload],
        update: []
      },
      "machinery_specialist" => {
        show: %w[id prescriptive_advisory_id cmms_type external_order_number sync_status priority
                 required_by dispatched_at confirmed_at],
        hidden: [], create: [], update: []
      },
      "maintenance_planner" => {
        show: [ "*" ], hidden: [],
        create: %w[prescriptive_advisory_id cmms_type priority required_by work_order_payload],
        update: %w[priority required_by external_order_number sync_status dispatched_at confirmed_at
                   work_order_payload material_reservations_json error_message]
      },
      "operations_superintendent" => {
        show: %w[id prescriptive_advisory_id cmms_type external_order_number sync_status priority
                 required_by dispatched_at],
        hidden: [], create: [], update: []
      }
    },
    HistorianConnectorPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [ "*" ], update: [ "*" ] },
      "reliability_engineer" => {
        show: %w[id connector_name historian_type status last_heartbeat poll_latency_ms
                 buffer_depth backfill_queue],
        hidden: [], create: [], update: []
      },
      "machinery_specialist" => {
        show: %w[id connector_name historian_type protocol_type status last_heartbeat
                 poll_latency_ms buffer_depth],
        hidden: [], create: [], update: []
      },
      "maintenance_planner" => { show: [], hidden: [], create: [], update: [] },
      "operations_superintendent" => { show: [], hidden: [], create: [], update: [] }
    },
    SecurityAuditEventPolicy => {
      "admin" => { show: [ "*" ], hidden: [], create: [], update: [] },
      "reliability_engineer" => { show: [], hidden: [], create: [], update: [] },
      "machinery_specialist" => { show: [], hidden: [], create: [], update: [] },
      "maintenance_planner" => { show: [], hidden: [], create: [], update: [] },
      "operations_superintendent" => { show: [], hidden: [], create: [], update: [] }
    }
  }.freeze

  setup do
    @org = Organization.create!(name: "Policy Org", slug: "policy-org")
    @roles = ROLE_SLUGS.index_with { |slug| Role.create!(slug: slug, name: slug.titleize) }
    @roles.each_value do |role|
      OrgRolePermission.create!(organization: @org, role: role, permissions: [ "*" ])
    end
    @users = @roles.transform_values { |role| user_with(role) }
    RequestStore.store[:rhino_organization] = @org
  end

  def teardown
    RequestStore.clear!
    super
  end

  def user_with(role)
    user = User.new(email: "#{role.slug}@policy.test", name: role.name, approved: true)
    user.password = "password"
    user.api_token ||= SecureRandom.hex(32)
    user.save!
    UserRole.create!(user: user, organization: @org, role: role)
    user
  end

  def policy_classes
    Dir[Rails.root.join("app/policies/*_policy.rb")].sort.map do |path|
      File.basename(path, ".rb").camelize.constantize
    end
  end

  def callable_methods(policy_class)
    policy_class.instance_methods(false).select do |name|
      name.to_s.end_with?("?") || name.to_s.start_with?("permitted_attributes", "hidden_attributes")
    end
  end

  # Attribute surfaces take the user; the custom-action gates are zero-arity.
  def invoke(policy, name, user)
    policy.method(name).arity.zero? ? policy.public_send(name) : policy.public_send(name, user)
  end

  test "every policy answers its read/write surfaces and gates for every role" do
    policy_classes.each do |policy_class|
      methods = callable_methods(policy_class)
      next if methods.empty?

      methods.each do |name|
        (@users.values + [ nil ]).each do |user|
          policy = policy_class.new(user, nil)
          result = invoke(policy, name, user)
          assert result.is_a?(Array) || [ true, false ].include?(result),
                 "#{policy_class}##{name} returned #{result.inspect} for #{user&.email || 'anonymous'}"
        end
      end
    end
  end

  test "an anonymous caller is never granted a write surface or a custom action" do
    policy_classes.each do |policy_class|
      methods = callable_methods(policy_class)
      methods.each do |name|
        policy = policy_class.new(nil, nil)
        result = invoke(policy, name, nil)

        if name.to_s.end_with?("?")
          assert_equal false, result, "#{policy_class}##{name} granted an anonymous caller"
        else
          assert_equal [], result, "#{policy_class}##{name} handed an anonymous caller fields"
        end
      end
    end
  end

  test "each policy returns exactly its role-scoped attribute surface" do
    SURFACES.each do |policy_class, by_role|
      by_role.each do |role_slug, expected|
        user = @users.fetch(role_slug)
        policy = policy_class.new(user, nil)

        assert_equal expected[:show], policy.permitted_attributes_for_show(user),
                     "#{policy_class}#permitted_attributes_for_show(#{role_slug})"
        assert_equal expected[:hidden], policy.hidden_attributes_for_show(user),
                     "#{policy_class}#hidden_attributes_for_show(#{role_slug})"
        assert_equal expected[:create], policy.permitted_attributes_for_create(user),
                     "#{policy_class}#permitted_attributes_for_create(#{role_slug})"
        assert_equal expected[:update], policy.permitted_attributes_for_update(user),
                     "#{policy_class}#permitted_attributes_for_update(#{role_slug})"
      end
    end
  end
end
