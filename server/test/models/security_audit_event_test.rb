# frozen_string_literal: true

require "test_helper"

# the append-only, tamper-evident trail.
class SecurityAuditChainTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(slug: "audit-org", name: "Audit Org")
    @user = User.create!(name: "Admin", email: "audit-admin@example.com", password: "password")
  end

  test "the writer chains each row to its predecessor" do
    # sha256(previous_hash + canonical payload).
    first = Refineguard::SecurityAuditWriter.call(
      organization: @org, user: @user, action_type: "AUTH_LOGIN", result: "Success"
    )
    second = Refineguard::SecurityAuditWriter.call(
      organization: @org, user: @user, action_type: "ACKNOWLEDGE", result: "Success"
    )

    assert_nil first.previous_hash
    assert_equal first.tamper_proof_hash, second.previous_hash
    assert first.tamper_proof?
    assert second.tamper_proof?
    assert_empty Refineguard::SecurityAuditWriter.verify_chain(@org)
  end

  test "a tampered row fails verification" do
    event = Refineguard::SecurityAuditWriter.call(
      organization: @org, action_type: "AUTH_LOGIN", result: "Success"
    )
    event.update_column(:action_type, "REWRITTEN")

    assert_not event.reload.tamper_proof?
    assert_includes Refineguard::SecurityAuditWriter.verify_chain(@org), event.id
  end

  test "no role is granted store, update or destroy on the audit resource" do
    # the trail is immutable *through the API*, not just by
    # convention — the permissions are what enforce it.
    %w[admin reliability_engineer machinery_specialist maintenance_planner
       operations_superintendent].each do |role_slug|
      permissions = RefineguardTestData.permission_list[role_slug] || []
      assert_empty permissions.grep(/\Asecurity_audit_events\.(store|update|destroy)\z/),
                   "#{role_slug} must not be able to write the audit trail"
    end
  end
end
