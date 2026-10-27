# frozen_string_literal: true

# 30-minute idle session expiry.
#
# Mixed into Rhino::ResourcesController and Rhino::AuthController so *every*
# authenticated API request refreshes a `token_last_used_at` clock and a token
# that has been idle beyond the timeout is revoked and answered 401, which makes
# the SPA redirect to /login.
module SessionIdleGuard
  IDLE_TIMEOUT = 30.minutes
  TOUCH_INTERVAL = 60.seconds
  IDLE_EXPIRED_MESSAGE = "Session expired after 30 minutes of inactivity."

  def self.included(base)
    base.before_action :enforce_session_idle!
  end

  private

  def enforce_session_idle!
    user = current_user
    return if user.nil?

    last_seen = last_seen_at(user)
    if last_seen && Time.current - last_seen > IDLE_TIMEOUT
      revoke_idle_token(user)
      return render_idle_expiry
    end

    touch_last_seen(user, last_seen)
  end

  # The custom controllers (`Api::BaseController`) answer failures with the single
  # `{ "errors": ["message"] }` envelope, so the idle expiry uses `render_errors`
  # there. The engine's own controllers keep their `{ "message": "..." }` body, so
  # their existing response shape is unchanged.
  def render_idle_expiry
    if respond_to?(:render_errors, true)
      render_errors([ IDLE_EXPIRED_MESSAGE ], :unauthorized)
    else
      render json: { message: IDLE_EXPIRED_MESSAGE }, status: :unauthorized
    end
  end

  def last_seen_at(user)
    if user.class.column_names.include?("token_last_used_at")
      user.token_last_used_at || user.last_sign_in_at || user.created_at
    else
      user.last_sign_in_at || user.created_at
    end
  end

  def touch_last_seen(user, last_seen)
    return unless user.class.column_names.include?("token_last_used_at")
    return if last_seen && Time.current - last_seen < TOUCH_INTERVAL

    user.update_columns(token_last_used_at: Time.current)
  rescue StandardError
    nil
  end

  def revoke_idle_token(user)
    if user.respond_to?(:regenerate_api_token)
      user.regenerate_api_token
    elsif user.class.column_names.include?("api_token")
      user.update_column(:api_token, SecureRandom.hex(32))
    end
    user.update_column(:token_last_used_at, nil) if user.class.column_names.include?("token_last_used_at")
  rescue StandardError
    nil
  end
end
