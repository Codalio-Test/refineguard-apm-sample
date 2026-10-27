# frozen_string_literal: true

# Bearer-token auth + personnel profile columns for the RefineGuard identities.
#
# Rhino v4 authenticates with `Authorization: Bearer <api_token>` resolved via
# `User.find_by_api_token`, which `has_secure_token :api_token` provides. The
# remaining columns back the PRD's "data model stores email / first name /
# last name / approved / profile completed" criteria.
class AddRefineguardColumnsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :api_token, :string
    add_index :users, :api_token, unique: true

    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :approved, :boolean, default: true, null: false
    add_column :users, :sign_in_count, :integer, default: 0, null: false
    add_column :users, :last_sign_in_at, :datetime

    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime

    # Air-gapped lockout state.
    add_column :users, :failed_login_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
  end
end
