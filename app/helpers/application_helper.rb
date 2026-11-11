module ApplicationHelper
  # Single source of truth for which OmniAuth identity providers get a
  # sign-in/sign-up button, so the sessions and registrations views (and any
  # future ones) can't drift out of sync with config/initializers/omniauth.rb.
  IDENTITY_PROVIDERS = [
    { key: 'github', label: 'GitHub' },
    { key: 'twitter2', label: 'Twitter' },
    { key: 'google_oauth2', label: 'Google' },
    { key: 'twitch', label: 'Twitch' },
    { key: 'discord', label: 'Discord' }
  ].freeze

  def identity_providers
    return IDENTITY_PROVIDERS unless Rails.env.local?

    # The developer strategy needs no real credentials, so it's how this app
    # is signed in/up with in development and exercised in specs.
    IDENTITY_PROVIDERS + [{ key: 'developer', label: 'Developer (test)' }]
  end
end
