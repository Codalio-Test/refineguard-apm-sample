# frozen_string_literal: true

# RefineGuard APM — idempotent runtime seed.
#
# Creates:
#   * the roles declared in `.rhino/blueprints/_roles.yaml`
#   * `OrgRolePermission` rows for every (organization, role) built FROM the
#     blueprint `permissions:` blocks, so the permission chain is never
#     default-deny (the classic "the role can't access anything" bug)
#   * the three runtime identities the host contract proves through real logins:
#       administrator@example.com / password -> demo-org, full CRUD on assets
#       viewer@example.com        / password -> demo-org, read-only assets
#       outsider@example.com      / password -> runtime-other-org only
#   * one identity per blueprint role so every role's API surface is reachable
#   * the PRD `sample_data` and the locked prototype's narrative rows
#
# Safe to run repeatedly: every write is a find-or-initialise + assign + save.

require 'yaml'
require 'digest'

BLUEPRINT_DIR = Rails.root.join('.rhino/blueprints')

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def blueprint_files
  Dir.glob(File.join(BLUEPRINT_DIR, '*.yaml')).reject { |f| File.basename(f).start_with?('_') }.sort
end

def load_blueprint(path)
  content = File.read(path)
  # `aliases: true` because the plan-authored YAML reuses anchored field lists.
  YAML.safe_load(content, permitted_classes: [ Symbol ], aliases: true)
end

def permission_matrix
  matrix = Hash.new { |hash, key| hash[key] = [] }

  blueprint_files.each do |path|
    blueprint = load_blueprint(path)
    slug = blueprint['slug']
    next if slug.blank?

    (blueprint['permissions'] || {}).each do |role_slug, config|
      Array(config['actions']).each { |action| matrix[role_slug] << "#{slug}.#{action}" }
    end
  end

  matrix.each_value { |perms| perms.uniq! }
  matrix
end

def upsert(model, lookup, attributes)
  record = model.find_or_initialize_by(lookup)
  record.assign_attributes(attributes)
  record.save!
  record
end

# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------

roles_source = YAML.safe_load(
  File.read(BLUEPRINT_DIR.join('_roles.yaml')), permitted_classes: [ Symbol ]
)['roles']

role_records = roles_source.map do |slug, definition|
  upsert(Role, { slug: slug }, name: definition['name'], description: definition['description'])
end
role_by_slug = role_records.index_by(&:slug)

# The engine treats the literal `admin` slug as the privileged role.
raise "role 'admin' is required" unless role_by_slug.key?('admin')

# ---------------------------------------------------------------------------
# Organizations
# ---------------------------------------------------------------------------

demo_org = upsert(
  Organization, { slug: 'demo-org' },
  name: 'Baton Rouge Refinery - Zone 1',
  description: 'Primary air-gapped RefineGuard APM tenant (CDU / FCC / HCU / ALKY).'
)

other_org = upsert(
  Organization, { slug: 'runtime-other-org' },
  name: 'Other Refinery (isolation fixture)',
  description: 'Second tenant used to prove cross-organization isolation.'
)

# ---------------------------------------------------------------------------
# Permission chain: OrgRolePermission[(organization, role)] from the blueprints
# ---------------------------------------------------------------------------

matrix = permission_matrix

# Read access the SPA needs outside the blueprint models.
matrix['admin'] |= [ 'users.index', 'users.show', 'roles.index', 'roles.show',
                    'organizations.index', 'organizations.show' ]
matrix['reliability_engineer'] |= [ 'users.index', 'users.show', 'roles.index', 'roles.show' ]
matrix['machinery_specialist'] |= [ 'users.index', 'users.show' ]
matrix['maintenance_planner'] |= [ 'users.index', 'users.show' ]
matrix['operations_superintendent'] |= [ 'users.index', 'users.show', 'roles.index' ]

role_by_slug.each do |slug, role|
  permissions = matrix[slug] || []

  [ demo_org, other_org ].each do |organization|
    record = OrgRolePermission.find_or_initialize_by(organization: organization, role: role)
    record.permissions = permissions
    record.save!
  end
end

# ---------------------------------------------------------------------------
# Identities
# ---------------------------------------------------------------------------

SEED_PASSWORD = ENV['SEED_DEFAULT_PASSWORD'].presence || 'password'

def seed_user(email:, name:, first_name:, last_name:, role:, organization:, password: SEED_PASSWORD)
  user = User.find_or_initialize_by(email: email)
  user.name = name
  user.first_name = first_name
  user.last_name = last_name
  user.approved = true
  user.password = password if user.new_record? || user.password_digest.blank?
  user.api_token ||= SecureRandom.hex(32)
  # Seeds must never resurrect a locked-out identity into a locked state.
  user.failed_login_attempts = 0
  user.locked_at = nil
  user.save!

  if organization
    UserRole.find_or_create_by!(user: user, organization: organization, role: role) do |ur|
      ur.permissions = []
      ur.granted_permissions = []
      ur.denied_permissions = []
    end
  end

  user
end

# Contract-carrying identities.
administrator = seed_user(
  email: 'administrator@example.com', name: 'System Administrator',
  first_name: 'Ada', last_name: 'Reyes', role: role_by_slug['admin'], organization: demo_org
)

viewer = seed_user(
  email: 'viewer@example.com', name: 'Read Only Viewer',
  first_name: 'Vera', last_name: 'Okafor',
  role: role_by_slug['reliability_engineer'], organization: demo_org
)

# One identity per blueprint role, so the per-role smoke has a real login.
role_users = {
  'reliability_engineer' => seed_user(
    email: 'reliability_engineer@example.com', name: 'Marcus Vance',
    first_name: 'Marcus', last_name: 'Vance',
    role: role_by_slug['reliability_engineer'], organization: demo_org
  ),
  'machinery_specialist' => seed_user(
    email: 'machinery_specialist@example.com', name: 'Dr. Elena Rostova',
    first_name: 'Elena', last_name: 'Rostova',
    role: role_by_slug['machinery_specialist'], organization: demo_org
  ),
  'maintenance_planner' => seed_user(
    email: 'maintenance_planner@example.com', name: 'Dave Kalu',
    first_name: 'Dave', last_name: 'Kalu',
    role: role_by_slug['maintenance_planner'], organization: demo_org
  ),
  'operations_superintendent' => seed_user(
    email: 'operations_superintendent@example.com', name: 'Priya Nair',
    first_name: 'Priya', last_name: 'Nair',
    role: role_by_slug['operations_superintendent'], organization: demo_org
  ),
  'admin' => administrator
}

viewer.update!(api_token: viewer.api_token)

# The outsider belongs ONLY to the second organization — never to demo-org.
outsider = seed_user(
  email: 'outsider@example.com', name: 'Outside Operator',
  first_name: 'Otto', last_name: 'Sandoval',
  role: role_by_slug['reliability_engineer'], organization: other_org
)

if UserRole.where(user: outsider, organization: demo_org).exists?
  UserRole.where(user: outsider, organization: demo_org).delete_all
end

puts "Seeded organizations: #{Organization.order(:slug).pluck(:slug).join(', ')}"
puts "Seeded roles: #{Role.order(:slug).pluck(:slug).join(', ')}"
puts "Seeded identities: #{User.order(:email).pluck(:email).join(', ')}"
puts "Seeded permission rows: #{OrgRolePermission.count}"

# ---------------------------------------------------------------------------
# Plant data (units, twins, historian), diagnostics, lifecycle and governance.
#
# Each file re-reads the identities it needs by slug/email, so these are safe to
# run in any order and repeatedly.
# ---------------------------------------------------------------------------

load Rails.root.join('db/seeds/refineguard_demo_data.rb')
load Rails.root.join('db/seeds/refineguard_diagnostics_data.rb')
load Rails.root.join('db/seeds/refineguard_lifecycle_data.rb')
