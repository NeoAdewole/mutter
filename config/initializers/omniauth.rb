require_relative '../auth_providers'

# Only providers with credentials are registered, so a service nobody has set up
# yet is simply not offered (see AuthProviders and docs/AUTH_SETUP.md). A request
# to one that isn't registered ends at AuthProvidersController#unavailable.
Rails.application.config.middleware.use OmniAuth::Builder do
  # The developer strategy has no external credentials, so it's also what
  # request specs use to exercise the OAuth sign-up/log-in flow end to end.
  provider :developer if Rails.env.local?

  AuthProviders.configured.each do |config|
    provider config.strategy, config.client_id, config.client_secret, **config.options
  end

  OmniAuth.config.logger = Rails.logger
end
