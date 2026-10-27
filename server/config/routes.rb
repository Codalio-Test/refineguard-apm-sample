Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # RefineGuard's non-CRUD endpoints. These live inside the same tenant path
  # prefix the engine uses (`/api/:organization/...`) so the organization is
  # resolved from `organizations.slug` exactly like every generated CRUD route,
  # and they are declared BEFORE the engine appends its own routes, so
  # `assets/hierarchy` is never mistaken for `assets/:id`.
  scope "api/:organization", defaults: { format: :json } do
    # Session identity. The engine's login response carries only the token and the
    # organization slug, so the flat-route SPA resolves the signed-in user's roles
    # (and the organization) from here.
    get "me", to: "api/session#show"

    # tenant-safe aggregates.
    get "dashboard/fleet_overview", to: "api/dashboard#fleet_overview"
    get "dashboard/active_anomalies", to: "api/dashboard#active_anomalies"
    get "dashboard/unit_risk_matrix", to: "api/dashboard#unit_risk_matrix"

    # on-prem infrastructure telemetry.
    get "system_health", to: "api/system_health#show"

    # signed audit evidence export.
    get "security_audit_events/export", to: "api/security_audit_events#export"

    # historian tag mapping import + batch validation harness.
    post "historian_tags/import", to: "api/historian_tags#import"
    post "historian_tags/validate_batch", to: "api/historian_tags#validate_batch"

    # connector probe / ring buffer.
    post "historian_connectors/:id/test_connection", to: "api/historian_connectors#test_connection"

    # asset hierarchy import, validate/publish, tree read model.
    get "assets/hierarchy", to: "api/assets#hierarchy"
    post "assets/import", to: "api/assets#import"
    post "assets/validate_hierarchy", to: "api/assets#validate_hierarchy"

    # local baseline training + gated promotion.
    post "model_baselines/:id/train", to: "api/model_baselines#train"
    post "model_baselines/:id/promote", to: "api/model_baselines#promote"

    # prescriptive dispatch, derate approval, standby switchover.
    post "prescriptive_advisories/:id/dispatch_work_order",
         to: "api/prescriptive_advisories#dispatch_work_order"
    post "prescriptive_advisories/:id/approve_derate",
         to: "api/prescriptive_advisories#approve_derate"
    post "prescriptive_advisories/:id/evaluate_standby",
         to: "api/prescriptive_advisories#evaluate_standby"

    # finding sign-off + persisted acknowledgement.
    post "diagnostic_incidents/:id/acknowledge", to: "api/diagnostic_incidents#acknowledge"
    post "diagnostic_incidents/:id/sign_off", to: "api/diagnostic_incidents#sign_off"
  end
end
