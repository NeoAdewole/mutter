module ApplicationHelper
  # Single source of truth for which identity providers are offered as buttons,
  # so the sessions and registrations views can't drift out of sync with
  # config/initializers/omniauth.rb: both read AuthProviders. A provider with
  # no credentials is not registered, so it is not offered either.
  # Every provider that can be connected from the profile page.
  def identity_providers
    providers = AuthProviders.configured.map { |provider| { key: provider.key, label: provider.label } }

    # The developer strategy needs no real credentials, so it's how this app
    # is signed in/up with in development and exercised in specs.
    providers << { key: 'developer', label: 'Developer (test)' } if Rails.env.local?
    providers
  end

  # The subset that can be used to sign in or sign up (YouTube is connect-only).
  def sign_in_providers
    identity_providers.reject { |provider| Identity::CONNECT_ONLY_PROVIDERS.include?(provider[:key]) }
  end
end
