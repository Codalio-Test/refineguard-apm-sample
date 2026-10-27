# frozen_string_literal: true

# Discard-backed soft deletes, wired the way Rhino v4's engine expects.
#
# Rhino resolves member endpoints with `model_class.all` and lists trashed rows
# with `model_class.discarded`; the engine applies no `.kept` filter of its own,
# so hiding discarded rows is the model's job. Two engine details shape how it
# has to be done:
#
#  1. `Rhino::ScopesToOrganization` applies tenancy by MERGING
#     `model_class.for_organization(org)` into the caller's relation. A
#     default-scoped `for_organization` re-imports the `discarded_at IS NULL`
#     predicate, which silently cancels the `discarded` relation the engine uses
#     for `/trashed`, `/:id/restore` and `/:id/force-delete` (every one of them
#     would 404). `for_organization` is therefore rebuilt from `unscoped` so the
#     merge stays purely additive.
#  2. Discard's own `discarded` scope chains onto whatever relation the class
#     default-scopes to, so it is overridden here with `with_discarded` (which
#     un-scopes the `discarded_at` predicate) to keep listing trashed rows.
#
# Resulting behaviour:
#
#   DELETE /{slug}/:id          -> discard!  -> gone from index and show
#   GET    /{slug}/trashed                   -> the discarded rows
#   POST   /{slug}/:id/restore               -> undiscard!
#   DELETE /{slug}/:id/force-delete          -> purge
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    include Discard::Model

    default_scope -> { kept }
    scope :discarded, -> { with_discarded.where.not(discarded_at: nil) }
    scope :undiscarded, -> { with_discarded.where(discarded_at: nil) }
  end

  class_methods do
    # Declared here (the concern is included AFTER Rhino::BelongsToOrganization)
    # to override the engine's default-scoped version, which would otherwise
    # re-apply `discarded_at IS NULL` during the tenancy merge.
    def for_organization(organization)
      unscoped.where(organization_id: organization.id)
    end
  end
end
