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

  provider :discord,
           Rails.application.credentials.dig(:discord, :client_id),
           Rails.application.credentials.dig(:discord, :client_secret),
           scope: 'identify email'

  provider :twitch,
           Rails.application.credentials.dig(:twitch, :client_id),
           Rails.application.credentials.dig(:twitch, :client_secret),
           scope: 'user:read:email'

  OmniAuth.config.logger = Rails.logger
end
