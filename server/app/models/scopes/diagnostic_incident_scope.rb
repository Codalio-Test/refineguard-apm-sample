# frozen_string_literal: true

module Scopes
  # Auto-applied to every DiagnosticIncident query by Rhino::HasAutoScope.
  #
  # Conditional access (the plan's "Conditional access" Extra shape): the
  # operations superintendent's surface is the *active* plant-wide risk picture
  # so resolved incidents are narrowed out of their rows. Reliability,
  # specialist, planner and admin roles keep the full history. Tenancy and the
  # DiagnosticIncidentPolicy permission gates still apply on top — this scope only
  # ever NARROWS.
  class DiagnosticIncidentScope < Rhino::ResourceScope
    OPERATIONS_ONLY_ACTIVE = %w[operations_superintendent].freeze

    def apply(relation)
      return relation unless OPERATIONS_ONLY_ACTIVE.include?(role)

      relation.where.not(status: DiagnosticIncident::STATUS_RESOLVED)
    end
  end
end
