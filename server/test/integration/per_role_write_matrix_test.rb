# frozen_string_literal: true

require "test_helper"

# Phase C step 2b — the per-role API write smoke, driven from the blueprints.
#
# For every feature model × every blueprint role × every write action:
#
#   * a role WITHOUT the grant must be refused with 403 (the permission gate),
#   * a role WITH the grant must NOT be refused — it either succeeds or fails
#     validation (422), which is not a policy failure.
#
# `assets` additionally gets the full 2xx contract in AssetsCrudTest; here we
# assert the gate itself across the whole surface, which is what catches a
# missing OrgRolePermission row (default-deny) or a policy that denies a grant.
class PerRoleWriteMatrixTest < ActionDispatch::IntegrationTest
  # Mutation coverage for the policies is claimed by the focused policy tests
  # (`test/policies/*`), which assert the same decisions action by action without
  # running the whole matrix; this end-to-end sweep stays a plain regression test
  # so a mutant is not judged by a multi-second integration run.
  setup do
    setup_runtime
    @matrix = RefineguardTestData.blueprint_permissions
    @actors = {
      "admin" => @admin,
      "reliability_engineer" => @engineer,
      "machinery_specialist" => @specialist,
      "maintenance_planner" => @planner,
      "operations_superintendent" => @superintendent
    }
    provision_samples!
  end

  test "store is granted exactly to the roles that hold the action" do
    @payloads.each_key do |slug|
      next if @payloads[slug].nil?

      @actors.each do |role_slug, user|
        # An empty body is the pure authorization probe: forbidden-field checks
        # and format validation both sit behind the `create?` gate, so a role
        # without the grant sees 403 and a role with it sees 422/201.
        post "/api/demo-org/#{slug}", params: {}.to_json, headers: json_headers(user)
        assert_gate(role_slug, slug, "store")
        assert_denied(role_slug, slug, "store")

        next unless granted?(role_slug, slug, "store")

        # A role holding the grant can also submit the fields its own blueprint
        # permission block declares writable. (A narrower field set than the
        # union is intentional — e.g. the specialist writes only findings.)
        role_payload = payload_for_role(role_slug, slug)
        post "/api/demo-org/#{slug}", params: role_payload.to_json, headers: json_headers(user)
        assert_not_equal 403, response.status,
                         "#{role_slug} holds #{slug}.store but its own fields were refused: " \
                         "#{response.body[0, 200]}"
      end
    end
  end

  test "update is granted exactly to the roles that hold the action" do
    @route_keys.each do |slug, route_key|
      @actors.each do |role_slug, user|
        put "/api/demo-org/#{slug}/#{route_key}", params: {}.to_json, headers: json_headers(user)
        assert_gate(role_slug, slug, "update")
        assert_denied(role_slug, slug, "update")
      end
    end
  end

  test "destroy is granted exactly to the roles that hold the action" do
    @payloads.each_key do |slug|
      next if @payloads[slug].nil?

      @actors.each do |role_slug, user|
        record = build_record(slug)
        next if record.nil?

        delete "/api/demo-org/#{slug}/#{route_key_for(record)}", headers: auth_headers(user)
        assert_gate(role_slug, slug, "destroy")
        assert_denied(role_slug, slug, "destroy")
      end
    end
  end

  test "trashed, restore and forceDelete are separate grants, not implied by destroy" do
    @payloads.each_key do |slug|
      next if @payloads[slug].nil?

      model = Rhino.config.resolve_model(slug)
      next unless model.uses_soft_deletes?

      @actors.each do |role_slug, user|
        record = build_record(slug)
        next if record.nil?
        record.discard!

        get "/api/demo-org/#{slug}/trashed", headers: auth_headers(user)
        assert_gate(role_slug, slug, "trashed")
        assert_denied(role_slug, slug, "trashed")

        post "/api/demo-org/#{slug}/#{route_key_for(record)}/restore", headers: auth_headers(user)
        assert_gate(role_slug, slug, "restore")
        assert_denied(role_slug, slug, "restore")

        record.reload
        record.discard! unless record.discarded?
        delete "/api/demo-org/#{slug}/#{route_key_for(record)}/force-delete", headers: auth_headers(user)
        assert_gate(role_slug, slug, "forceDelete")
        assert_denied(role_slug, slug, "forceDelete")
      end
    end
  end

  private

  # The subset of a model's create payload the role's blueprint grants it.
  def payload_for_role(role_slug, slug)
    fields = RefineguardTestData.blueprint_writable_fields.dig(role_slug, slug, :create_fields)
    return @payloads[slug] if fields.nil? || fields == "*" || fields == [ "*" ]

    allowed = Array(fields).map(&:to_s)
    @payloads[slug].select { |key, _| allowed.include?(key.to_s) }
  end

  # Whether the blueprint grants +action+ on +slug+ to +role_slug+.
  def granted?(role_slug, slug, action)
    Array((@matrix[role_slug] || {})[slug]).include?(action)
  end

  def assert_gate(role_slug, slug, action)
    return unless granted?(role_slug, slug, action)

    assert_not_equal 403, response.status,
                     "#{role_slug} holds #{slug}.#{action} but got 403: #{response.body[0, 200]}"
  end

  # A role WITHOUT the grant must be refused. Kept separate so the positive
  # assertion above reads clearly.
  def assert_denied(role_slug, slug, action)
    return if granted?(role_slug, slug, action)

    assert_equal 403, response.status,
                 "#{role_slug} lacks #{slug}.#{action} but got #{response.status}"
  end

  def route_key_for(record)
    key = record.class.try(:rhino_resolved_route_key) || record.class.primary_key
    record.public_send(key)
  end

  def build_record(slug)
    model = Rhino.config.resolve_model(slug)
    model.create!(@payloads[slug].merge(organization: @demo_org))
  rescue ActiveRecord::RecordInvalid, ActiveModel::UnknownAttributeError, ActiveRecord::StatementInvalid
    nil
  end

  # One valid payload per model, built in dependency order.
  def provision_samples!
    @payloads = {}
    @route_keys = {}

    @payloads["plant_units"] = { unit_code: "FCC-2", unit_name: "Fluid Catalytic Cracking Unit" }

    @payloads["assets"] = { asset_tag: "P-204B", asset_name: "Crude charge pump B",
                            equipment_class: "Centrifugal Pump", plant_unit_id: @unit.id }

    @payloads["asset_components"] = { asset_id: @asset.id, component_name: "Outboard Bearing",
                                      component_type: "Angular Contact Ball Bearing Pair" }

    @payloads["failure_modes"] = { iso_code: "ISO14224-MECH-ALIGN-ANG",
                                   failure_name: "Angular & Parallel Shaft Misalignment" }

    @payloads["historian_connectors"] = { connector_name: "PI Primary",
                                          historian_type: "OSIsoft_PI", status: "Connected" }

    connector = HistorianConnector.create!(@payloads["historian_connectors"].merge(organization: @demo_org))
    @payloads["historian_tags"] = { historian_type: "OSIsoft_PI", source_tag_name: "P204A.VIB.OH",
                                    tag_path: "PI:P204A.VIB.OH", engineering_unit: "mm/s",
                                    scan_rate_ms: 1000, deadband_val: 0.1,
                                    asset_id: @asset.id, historian_connector_id: connector.id }
    tag = HistorianTag.create!(@payloads["historian_tags"].merge(organization: @demo_org))

    @payloads["telemetry_records"] = { historian_tag_id: tag.id,
                                       recorded_at: Time.current.iso8601, recorded_value: 8.42 }

    @payloads["asset_health_indices"] = { asset_id: @asset.id, calculated_at: Time.current.iso8601,
                                          health_score: 28.0, health_state: "Trip",
                                          reconstruction_error: 0.14, threshold_p99: 0.09 }

    @payloads["diagnostic_incidents"] = { asset_id: @asset.id, incident_code: "INC-TEST-1",
                                          status: "Active", severity_level: "High",
                                          health_state: "Alarm", detected_at: Time.current.iso8601,
                                          rul_days_estimate: 18.0, pf_interval_days: 26.0 }
    incident = DiagnosticIncident.create!(@payloads["diagnostic_incidents"].merge(organization: @demo_org))

    @payloads["failure_mode_assessments"] = { asset_id: @asset.id, failure_mode_id: @failure_mode.id,
                                              probability: 87.0, assessed_at: Time.current.iso8601,
                                              marker_label: "BPFO", match_score: 0.87 }

    @payloads["spectrum_snapshots"] = { asset_id: @asset.id, captured_at: Time.current.iso8601,
                                        channel: "OB Horizontal", rms_velocity: 8.42,
                                        running_speed_hz: 29.92 }

    @payloads["model_baselines"] = { asset_id: @asset.id, model_version: "v0.0.1-TEST",
                                     algorithm_type: "Deep Autoencoder", status: "Candidate" }
    baseline = ModelBaseline.create!(@payloads["model_baselines"].merge(organization: @demo_org))

    @payloads["baseline_windows"] = { asset_id: @asset.id, model_baseline_id: baseline.id,
                                      label: "Apr 02", window_start: 30.days.ago.iso8601,
                                      window_end: 23.days.ago.iso8601, load_percent: 88.0,
                                      completeness_percent: 99.8 }

    @payloads["prescriptive_advisories"] = { diagnostic_incident_id: incident.id,
                                             advisory_code: "ADV-TEST-1",
                                             recommended_action: "Replace the outboard bearing pair.",
                                             status: "Ready for Dispatch" }
    advisory = PrescriptiveAdvisory.create!(@payloads["prescriptive_advisories"].merge(organization: @demo_org))

    @payloads["cmms_work_orders"] = { prescriptive_advisory_id: advisory.id, cmms_type: "SAP PM",
                                      sync_status: "Pending Sync" }

    @payloads["shift_log_entries"] = { occurred_at: Time.current.iso8601, shift_label: "Day shift",
                                       event_type: "Derate approval", severity: "warning",
                                       message: "CDU-1 charge rate reduced 8%",
                                       plant_unit_id: @unit.id }

    # Every model now has a payload; remember the created route key for update.
    @payloads.each_key do |slug|
      record = build_record(slug)
      @route_keys[slug] = record && route_key_for(record)
    end
    @route_keys.compact!
  end
end
