module ApplicationHelper
  # Single source of truth for which OmniAuth identity providers exist as
  # buttons, so the sessions and registrations views (and any future ones)
  # can't drift out of sync with config/initializers/omniauth.rb. Display
  # names live on Identity (Identity.label_for).
  IDENTITY_PROVIDER_KEYS = %w[github twitter2 google_oauth2 twitch discord youtube].freeze

  # Every provider that can be connected from the profile page.
  def identity_providers
    providers = IDENTITY_PROVIDER_KEYS.map { |key| { key: key, label: Identity.label_for(key) } }

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
