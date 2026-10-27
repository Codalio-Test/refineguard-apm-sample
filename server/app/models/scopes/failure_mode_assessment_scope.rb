# frozen_string_literal: true

module Scopes
  # Auto-applied to every FailureModeAssessment query by Rhino::HasAutoScope.
  #
  # Visibility for this resource is carried by (a) organization tenancy —
  # Rhino::BelongsToOrganization scopes every query to the resolved
  # organization — and (b) the FailureModeAssessmentPolicy permission gates. There is no
  # additional role-based row narrowing, so the scope is an explicit
  # pass-through rather than the generator's NotImplementedError stub.
  class FailureModeAssessmentScope < Rhino::ResourceScope
    def apply(relation)
      relation
    end
  end
end
