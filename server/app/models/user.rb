# frozen_string_literal: true

# Personnel identity. Authentication is Bearer `api_token` (has_secure_token) —
# there is no Devise and no session cookie in Rhino v4.
class User < ApplicationRecord
  include Rhino::HasPermissions
  include Rhino::HidableColumns

  has_secure_password
  has_secure_token :api_token

  has_many :user_roles, dependent: :destroy
  has_many :organizations, through: :user_roles
  has_many :roles, through: :user_roles

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :first_name, length: { maximum: 255 }, allow_nil: true
  validates :last_name, length: { maximum: 255 }, allow_nil: true
  validates :approved, inclusion: { in: [ true, false ] }

  # Never expose the bearer token or the reset material through the API.
  rhino_additional_hidden :api_token, :reset_password_token, :reset_password_sent_at,
                          :failed_login_attempts

  # The PRD's "data model stores first name / last name / approved / profile
  # completed" criteria resolve here.
  def profile_completed
    first_name.present? && last_name.present? && email.present?
  end

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || name
  end

  def rhino_computed_attributes
    {
      "profile_completed" => profile_completed,
      "display_name" => display_name,
      "role_slugs" => roles.map(&:slug)
    }
  end

  # ------------------------------------------------------------------
  # Air-gapped session hardening
  # ------------------------------------------------------------------

  LOCKOUT_THRESHOLD = 5

  def locked?
    locked_at.present?
  end

  def register_failed_login!
    update_columns(failed_login_attempts: failed_login_attempts.to_i + 1)
    return unless failed_login_attempts.to_i >= LOCKOUT_THRESHOLD

    update_columns(locked_at: Time.current)
  end

  def register_successful_login!
    update_columns(
      failed_login_attempts: 0,
      locked_at: nil,
      sign_in_count: sign_in_count.to_i + 1,
      last_sign_in_at: Time.current
    )
  end
end
