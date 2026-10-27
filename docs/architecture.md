# RefineGuard APM — architecture

RefineGuard APM is a Rhino v4 application: a Rails API (`server/`) plus a
standalone Vite/React browser client (`client/`). This document describes how the
two are layered, how tenant isolation and authorization work, how the CMMS and
LDAP adapters behave (including their simulated mode), and the session model.

## Layering

```
.rhino/blueprints/*.yaml   declarative resource specs (models, columns, relationships, permissions)
        │  rails rhino:blueprint
        ▼
app/models                 ActiveRecord models on Rhino::RhinoModel (query whitelists, validations, concerns)
app/policies               authorization: permission gates + attribute read/write surfaces + row scopes
app/services/refineguard   domain logic (classification, dispatch, imports, adapters, serializers)
app/controllers/api        custom (non-CRUD) endpoints, one thin controller per resource
client/src                 React SPA: pages, hooks, contexts, routes
```

### Blueprints

`server/.rhino/blueprints/*.yaml` are the source of truth for the schema and the
per-role permission matrix. `bundle exec rails rhino:blueprint` generates the
migrations, models, policies and seed data. `_roles.yaml` declares the role
registry. The test suite reads the blueprints directly
(`test/test_helper.rb#RefineguardTestData`) and asserts that the seeded
permission chain and the policies agree with them, so a blueprint edit and a
policy edit cannot silently drift apart.

### Models

Every resource subclasses `Rhino::RhinoModel`, which pre-includes the query DSL
(`rhino_filters/sorts/search/fields/includes`), per-action validation, column
hiding and the auto-applied row scope. Capabilities are opt-in concerns:

- `Rhino::BelongsToOrganization` — tenant ownership,
- `Discard::Model` / `SoftDeletable` — soft deletes (`trashed`/`restore`/`force-delete`),
- `Rhino::HasAuditTrail` — model-level change history in the polymorphic `audit_logs` table.

Whitelists are the query API: an unlisted `?filter[...]`, `?sort`, `?include`,
`?search` or `?fields[...]` parameter is ignored by design.

Model validations describe *format* (`presence`, `numericality`, `inclusion`,
`length`); the policy describes *writability*. A field a role may not write is
rejected with 403; a permitted field with a malformed value returns 422.

### Policies

`app/policies/*_policy.rb` subclass `Rhino::ResourcePolicy`. Each CRUD action
checks its permission string `{slug}.{action}` (for example
`prescriptive_advisories.update`), resolved through the layered chain
`(role ∪ granted) − denied` (deny wins; no membership row is default-deny).

Policies also own the per-role attribute surfaces
(`permitted_attributes_for_show/create/update`, `hidden_attributes_for_show`), so
field visibility is enforced server-side rather than by the browser.

Row-level visibility lives in `app/models/scopes/{model}_scope.rb`, applied as an
always-on default scope.

### Services

`app/services/refineguard/` holds the domain logic that is not CRUD: the
diagnostics classifier, prognostics, severity mapping, the CMMS dispatch
orchestration, the file importers, the hierarchy builder/validator, the audit
writer, and the LDAP/CMMS adapters. Services never render; they return result
structs the controllers serialize.

### Custom controllers

`app/controllers/api/*` serve the endpoints Rhino does not generate (dashboards,
imports, dispatch, sign-off, exports). They stay thin: resolve the tenant,
authorize, call a service, serialize. They inherit four invariants from
`Api::BaseController`:

1. the organization comes from the URL segment, resolved against
   `organizations.slug` — never from a client-supplied body or parameter;
2. data access goes through `Rhino.query`, which is tenant-scoped and fails
   closed (`Rhino::MissingTenantContext`) outside a tenant request;
3. every action runs an explicit policy gate;
4. every failure answers with one error envelope, `{ "errors": ["message", ...] }`.

`app/serializers/refineguard/serializers/` owns one serializer per resource, so a
custom endpoint never hand-builds a response hash inline.

## Tenancy

Multi-tenancy is path-based. `config.route_group :tenant, prefix:
':organization'` draws `/api/{organization}/{slug}` for every registered model,
and `Rhino::Middleware::ResolveOrganizationFromRoute` resolves the slug against
`organizations.slug` (`config.multi_tenant.organization_identifier_column`).

- `Rhino::BelongsToOrganization` sets `organization_id` from the resolved
  request organization on create — a client-supplied value is stripped, and
  changing it on update is a 403.
- `Rhino.query(Model)` returns the org-scoped relation. It **fails closed**: with
  no organization context it raises rather than returning every tenant's rows.
- Cross-tenant reads are answered with **404**, never 403 — an unknown
  organization and an organization the caller is not a member of are
  indistinguishable (information hiding).
- Cross-tenant foreign keys are rejected: every `belongs_to` referenced by a
  write is validated to reach the current organization.

## Authorization per custom action

Each custom (non-CRUD) action has its **own** zero-argument policy method on the
relevant policy. A gate is never borrowed from `update?`/`create?`, so a role
that may edit an ordinary field does not inherit the ability to sign off a
derating, transmit a work order or export the audit trail.

| Endpoint | Policy method | Allowed roles |
|---|---|---|
| `POST .../prescriptive_advisories/:id/approve_derate` | `approve_derate?` | operations superintendent (and admin) |
| `POST .../prescriptive_advisories/:id/dispatch_work_order` | `dispatch_work_order?` | maintenance planner, reliability engineer, admin |
| `POST .../prescriptive_advisories/:id/evaluate_standby` | `evaluate_standby?` | operations superintendent, reliability engineer, admin |
| `POST .../diagnostic_incidents/:id/acknowledge` | `acknowledge?` | reliability engineer, admin |
| `POST .../diagnostic_incidents/:id/sign_off` | `sign_off?` | machinery specialist, admin |
| `POST .../model_baselines/:id/train` or `promote` | `train?` / `promote?` | machinery specialist, admin |
| `POST .../historian_connectors/:id/test_connection` | `test_connection?` | admin |
| `POST .../historian_tags/import` or `validate_batch` | `import?` / `validate_batch?` | depends on the tag grants |
| `POST .../assets/import` or `validate_hierarchy` | `import?` / `index?` | depends on the asset grants |
| `GET .../security_audit_events/export` | `export?` | admin |

`Api::BaseController#deny!` renders the 403 envelope; the resolver scopes rows and
the policy authorizes access — the two checks are separate.

## CMMS adapter (work-order dispatch)

`Refineguard::Cmms::Adapter.for` selects the adapter from
`REFINEGUARD_CMMS_ADAPTER`:

- `SimulatedAdapter` (**default**) — performs **no** network call. It reports the
  payload as handed to the simulated connector and never confirms, so
  `confirmed_at` stays empty and `budget_ms` is `nil`.
- `HttpAdapter` — POSTs the payload to `REFINEGUARD_CMMS_URL` over `Net::HTTP`
  and only reports `confirmed` when the remote returns a success status. It is the
  only path that produces a timed `budget_ms`.

Both the API (`/api/{org}/me`, the dispatch response) and the UI render
`SIMULATED` whenever `simulated?` is true, so an unconfigured deployment can
never imply a real transmission.

Dispatch is **idempotent**: the "already dispatched?" check and the work-order
write happen under one row lock (`advisory.with_lock`), so two concurrent
dispatches cannot both pass — the second is refused with **409** and no duplicate
work order is written. External order numbers come from a PostgreSQL sequence
(`cmms_work_order_number_seq`), not from the row id.

## LDAP adapter (directory credentials)

`Refineguard::Ldap::Adapter.for` selects the credential adapter from
`REFINEGUARD_LDAP_ADAPTER`:

- `SimulatedAdapter` (**default**) — verifies the local password store and reports
  `SIMULATED`; no directory is contacted.
- `DirectoryAdapter` — performs a real LDAPv3 simple bind with
  `Refineguard::Ldap::Client`.

Transport safety: `REFINEGUARD_LDAP_TLS` selects `start_tls` (**default**),
`ldaps` or `none`. A plaintext bind is **refused** unless it is explicitly opted
into with `REFINEGUARD_LDAP_ALLOW_PLAINTEXT=1`. The bind DN is assembled from an
RFC 4514-escaped principal, so a crafted email address cannot inject additional
RDNs. Independently, `Refineguard::LdapCredentialBroker` refuses to dial any host
that is not on the local OT network.

## Session model

- Authentication is a Bearer `api_token` on the `users` table (`has_secure_token`);
  there is no Devise and no cookie session.
- `SessionIdleGuard` is mixed into the engine's CRUD/auth/invitation controllers
  and into `Api::BaseController`. It refreshes a `token_last_used_at` clock on
  each authenticated request and, after **30 minutes** idle, revokes the token and
  answers **401**, which makes the SPA redirect to `/login`.
- `GET /api/{organization}/me` (`Api::SessionController`) is the client's
  server-side source for the signed-in identity: the user, their role slugs **in
  that organization**, and the live authentication/CMMS adapter modes. It sits
  behind the same tenant gates as every generated route — an unknown or
  non-member organization is a 404.
- The client resolves that payload through `AppOwnerProvider`
  (`client/src/contexts/`), which never rewrites the URL: the organization lives
  in the API path and in context, never in the browser path.

## Client

`client/src` is a standalone SPA. `src/lib/api.ts` calls `configureApi()` once at
startup (path tenancy, `/api` base URL, 401/403 handling). Every request goes
through the shared axios instance exposed by `@rhino-dev/rhino-react`; model data
uses the generated CRUD hooks and the custom endpoints use the typed hooks in
`src/hooks/useApiQueries.ts`. Routes are flat and code-split (`src/routes/`), and
role gates are positive checks (`hasRole('admin')`), never the negation of
another role.
