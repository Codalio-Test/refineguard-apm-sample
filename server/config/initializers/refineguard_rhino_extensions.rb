# frozen_string_literal: true

# Wires the RefineGuard auth hardening into Rhino's engine
# controllers. `to_prepare` runs after every code reload in development, so the
# guards are re-applied to the reloaded engine classes; the `ancestors.include?`
# checks keep the mixins idempotent.
Rails.application.config.to_prepare do
  unless Rhino::AuthController.ancestors.include?(Refineguard::AuthControllerExtensions)
    Rhino::AuthController.prepend(Refineguard::AuthControllerExtensions)
  end

  unless Rhino::AuthController.ancestors.include?(SessionIdleGuard)
    Rhino::AuthController.include(SessionIdleGuard)
  end

  unless Rhino::ResourcesController.ancestors.include?(SessionIdleGuard)
    Rhino::ResourcesController.include(SessionIdleGuard)
  end

  unless Rhino::InvitationsController.ancestors.include?(SessionIdleGuard)
    Rhino::InvitationsController.include(SessionIdleGuard)
  end
end
