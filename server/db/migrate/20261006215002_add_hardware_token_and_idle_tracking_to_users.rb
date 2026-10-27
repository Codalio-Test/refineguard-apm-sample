# frozen_string_literal: true

# air-gapped session + credential hardening state.
#
# `token_last_used_at` is the idle clock the request guard reads: a bearer token
# that has not been used for 30 minutes is revoked and the request answered 401
# so the SPA redirects to /login. `hardware_token_secret` is the per-user shared
# secret the local hardware-token verifier checks; when it is present the second
# factor is *required* for that identity.
class AddHardwareTokenAndIdleTrackingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :token_last_used_at, :datetime
    add_column :users, :hardware_token_secret, :string
  end
end
