# frozen_string_literal: true

# RefineGuard APM — Rhino v4 configuration.
#
# Feature models are generated from the YAML blueprints under
# `.rhino/blueprints/` by `bundle exec rails rhino:blueprint`, which also
# registers them here. This file additionally declares the tenant route group
# (path-prefix multitenancy on `organizations.slug`), the air-gapped auth hooks
# and the test framework.

Rhino.configure do |config|
  # ---------------------------------------------------------------
  # Models
  # ---------------------------------------------------------------
  # Engine-provided identity resources (registered so the SPA can read them).
  config.model :organizations, "Organization"
  config.model :roles, "Role"
  config.model :users, "User"

  # Plant + machinery digital twin
  config.model :plant_units, "PlantUnit"
  config.model :assets, "Asset"
  config.model :asset_components, "AssetComponent"
  config.model :failure_modes, "FailureMode"
  config.model :failure_mode_assessments, "FailureModeAssessment"

  # Historian ingestion
  config.model :historian_connectors, "HistorianConnector"
  config.model :historian_tags, "HistorianTag"
  config.model :telemetry_records, "TelemetryRecord"

  # Health / diagnostics / prognostics
  config.model :asset_health_indices, "AssetHealthIndex"
  config.model :diagnostic_incidents, "DiagnosticIncident"
  config.model :spectrum_snapshots, "SpectrumSnapshot"

  # Model lifecycle
  config.model :model_baselines, "ModelBaseline"
  config.model :baseline_windows, "BaselineWindow"

  # Prescriptive action
  config.model :prescriptive_advisories, "PrescriptiveAdvisory"
  config.model :cmms_work_orders, "CmmsWorkOrder"

  # Operations + governance
  config.model :shift_log_entries, "ShiftLogEntry"
  config.model :security_audit_events, "SecurityAuditEvent"

  # ---------------------------------------------------------------
  # Route Groups
  # ---------------------------------------------------------------
  # Tenant group: `/api/:organization/<slug>`. The organization is resolved from
  # the `slug` column by Rhino::Middleware::ResolveOrganizationFromRoute, so the
  # SPA calls `/api/demo-org/assets` and every query is org-scoped.
  config.route_group :tenant,
                     prefix: ":organization",
                     middleware: [ Rhino::Middleware::ResolveOrganizationFromRoute ],
                     models: :all

  # Air-gapped authentication hardening.
  #
  # A group with an empty prefix and no domain *is* the legacy `/api/auth/*` set
  # (GROUP_AUTH_DESIGN §11.1), so declaring it here attaches the lifecycle hooks
  # to plain `POST /api/auth/login` without registering any resource routes
  # (`models: []`). Passing the class name as a String keeps boot free of
  # autoload-time constant resolution.
  config.route_group :default,
                     prefix: "",
                     models: [],
                     auth: true,
                     hooks: "Refineguard::AuthHooks"

  # ---------------------------------------------------------------
  # Multi-tenant
  # ---------------------------------------------------------------
  config.multi_tenant = {
    organization_identifier_column: "slug"
  }

  # ---------------------------------------------------------------
  # Invitations
  # ---------------------------------------------------------------
  config.invitations = {
    expires_days: 7,
    allowed_roles: nil
  }

  # ---------------------------------------------------------------
  # Nested operations
  # ---------------------------------------------------------------
  config.nested = {
    path: "nested",
    max_operations: 50,
    allowed_models: nil
  }

  # ---------------------------------------------------------------
  # Test Framework
  # ---------------------------------------------------------------
  config.test_framework = "minitest"
end
