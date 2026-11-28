# Every service people can sign in with or connect, and everything the app needs
# to know about each in one place: which OmniAuth strategy and scopes it uses,
# where its credentials come from, and where to register the app.
#
# This file lives in config/ (not app/) because config/initializers/omniauth.rb
# needs it while the app boots, before autoloaded code is available.
#
# Credentials are looked up, first match wins:
#   1. an environment variable, e.g. GITHUB_CLIENT_ID / GITHUB_CLIENT_SECRET (hosting platforms)
#   2. nested Rails credentials:  github: { client_id:, client_secret: }
#   3. flat Rails credentials:    github_client_id / github_client_secret (how Twitch was stored)
#
# A provider with no credentials is not registered with OmniAuth and is not
# offered on the sign-in, sign-up or profile pages. See docs/AUTH_SETUP.md.
module AuthProviders
  Provider = Struct.new(:key, :strategy, :group, :options, :console_url, keyword_init: true) do
    def label
      Identity.label_for(key)
    end

    def client_id
      AuthProviders.credential(self, :client_id)
    end

    def client_secret
      AuthProviders.credential(self, :client_secret)
    end

    def configured?
      client_id.present? && client_secret.present?
    end

    def connect_only?
      Identity::CONNECT_ONLY_PROVIDERS.include?(key)
    end

    # The address the service sends people back to; it must be registered with them exactly.
    def callback_path
      "/auth/#{key}/callback"
    end
  end

  # Order is the order the buttons appear in.
  ALL = [
    Provider.new(key: 'github', strategy: :github, group: :github,
                 # Without user:email GitHub only reveals a public email, which many people don't have.
                 options: { scope: 'user:email' },
                 console_url: 'https://github.com/settings/developers'),
    Provider.new(key: 'twitter2', strategy: :twitter2, group: :twitter,
                 options: { callback_path: '/auth/twitter2/callback', scope: 'tweet.read users.read bookmark.read offline.access' },
                 console_url: 'https://developer.x.com/en/portal/dashboard'),
    Provider.new(key: 'google_oauth2', strategy: :google_oauth2, group: :google, options: {},
                 console_url: 'https://console.cloud.google.com/apis/credentials'),
    Provider.new(key: 'twitch', strategy: :twitch, group: :twitch, options: { scope: 'user:read:email' },
                 console_url: 'https://dev.twitch.tv/console/apps'),
    Provider.new(key: 'discord', strategy: :discord, group: :discord, options: { scope: 'identify email' },
                 console_url: 'https://discord.com/developers/applications'),
    # YouTube is Google OAuth again (the same client), registered under its own name so it is a separate
    # connection from "Sign in with Google": it also asks for read-only access to the person's channel (to
    # learn their channel handle, which Google sign-in never provides) and can only be connected, never
    # used to sign in. Google Cloud needs /auth/youtube/callback as a second redirect URI and the
    # YouTube Data API v3 enabled.
    Provider.new(key: 'youtube', strategy: OmniAuth::Strategies::GoogleOauth2, group: :google,
                 options: { name: 'youtube', scope: 'email,profile,https://www.googleapis.com/auth/youtube.readonly',
                            prompt: 'select_account' }, # the channel belongs to one Google account; let them pick it
                 console_url: 'https://console.cloud.google.com/apis/credentials')
  ].freeze

  class << self
    def all
      ALL
    end

    def find(key)
      ALL.find { |provider| provider.key == key.to_s }
    end

    def configured
      ALL.select(&:configured?)
    end

    def configured?(key)
      find(key)&.configured? || false
    end

    # The value for one credential, or nil. Never logged or rendered.
    def credential(provider, name)
      prefix = provider.group.to_s.upcase
      from_env = ENV.fetch("#{prefix}_#{name.to_s.upcase}", nil)
      return from_env if from_env.present?

      credentials = Rails.application.credentials
      credentials.dig(provider.group, name).presence || credentials[:"#{provider.group}_#{name}"].presence
    end
  end
end
