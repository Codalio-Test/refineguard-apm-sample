# frozen_string_literal: true

# Engine-owned table for Rhino::OrganizationInvitation. The rhino:install wizard
# publishes the invitation controller and model but no migration for this table,
# so without it every /api/{org}/invitations request raises
# ActiveRecord::StatementInvalid. Shape mirrors Rhino::OrganizationInvitation and
# Rhino::InvitationsController (organization/role/inviter are nullable for
# non-tenant group invites).
class CreateOrganizationInvitations < ActiveRecord::Migration[8.0]
  def change
    create_table :organization_invitations do |t|
      t.bigint :organization_id
      t.bigint :role_id
      t.bigint :invited_by
      t.string :email, null: false
      t.string :token, null: false
      t.string :status, null: false, default: 'pending'
      t.datetime :expires_at
      t.datetime :accepted_at
      t.string :route_group

      t.timestamps
    end

    add_index :organization_invitations, :token, unique: true
    add_index :organization_invitations, %i[organization_id email status]
  end
end
