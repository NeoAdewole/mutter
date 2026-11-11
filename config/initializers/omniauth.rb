Rails.application.config.middleware.use OmniAuth::Builder do
  # The developer strategy has no external credentials, so it's also what
  # request specs use to exercise the OAuth sign-up/log-in flow end to end.
  provider :developer if Rails.env.local?
  provider :twitter2,
           Rails.application.credentials.dig(:twitter, :client_id),
           Rails.application.credentials.dig(:twitter, :client_secret),
           callback_path: '/auth/twitter2/callback',
           scope: 'tweet.read users.read bookmark.read offline.access'

  provider :github,
           Rails.application.credentials.dig(:github, :client_id),
           Rails.application.credentials.dig(:github, :client_secret)

  provider OmniAuth::Strategies::GoogleOauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret)

  # YouTube is Google OAuth again (same client), registered under its own name so
  # it is a separate connection from "Sign in with Google": it additionally asks for
  # read-only access to the person's channel (to learn their channel handle, which
  # Google sign-in never provides) and is connect-only (see Identity::CONNECT_ONLY_PROVIDERS).
  # Google Cloud Console needs /auth/youtube/callback added as an authorized redirect URI,
  # and the YouTube Data API v3 enabled for the project.
  provider OmniAuth::Strategies::GoogleOauth2,
           Rails.application.credentials.dig(:google, :client_id),
           Rails.application.credentials.dig(:google, :client_secret),
           name: 'youtube',
           scope: 'email,profile,https://www.googleapis.com/auth/youtube.readonly',
           prompt: 'select_account' # the channel belongs to a specific Google account; let them pick it

  provider :discord,
           Rails.application.credentials.dig(:discord, :client_id),
           Rails.application.credentials.dig(:discord, :client_secret),
           scope: 'identify email'

  # Twitch's credentials are stored flat (twitch_client_id / twitch_client_secret);
  # the nested form used by the other providers is still honored.
  provider :twitch,
           Rails.application.credentials.dig(:twitch, :client_id) || Rails.application.credentials[:twitch_client_id],
           Rails.application.credentials.dig(:twitch, :client_secret) || Rails.application.credentials[:twitch_client_secret],
           scope: 'user:read:email'

  OmniAuth.config.logger = Rails.logger
end
