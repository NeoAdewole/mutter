class Identity < ApplicationRecord
  # Providers whose live chat the Streaming page can read, keyed to the
  # per-provider client in app/javascript/chat/.
  CHAT_PROVIDERS = %w[twitch].freeze

  # Providers that can only be *connected* to an account you're already signed
  # in to, never used to sign in or sign up. (YouTube is Google OAuth again, but
  # asking for channel access; "Sign in with Google" is a separate provider.)
  CONNECT_ONLY_PROVIDERS = %w[youtube].freeze

  PROVIDER_LABELS = {
    'github' => 'GitHub',
    'twitter2' => 'Twitter',
    'google_oauth2' => 'Google',
    'twitch' => 'Twitch',
    'discord' => 'Discord',
    'youtube' => 'YouTube',
    'developer' => 'Developer'
  }.freeze

  # Where a handle on each service lives, for linking to it. Services without
  # a public by-handle profile page are left out (no link rather than a wrong one).
  PROFILE_URL_PREFIXES = {
    'twitch' => 'https://www.twitch.tv/',
    'youtube' => 'https://www.youtube.com/@',
    'github' => 'https://github.com/',
    'twitter2' => 'https://x.com/'
  }.freeze

  belongs_to :user
  validates :uuid, :provider, presence: true
  validates :uuid, uniqueness: { scope: :provider }

  scope :chat_capable, -> { where(provider: CHAT_PROVIDERS) }

  def self.label_for(provider)
    PROVIDER_LABELS.fetch(provider.to_s) { provider.to_s.titleize }
  end

  # This person's page on the service itself (their handle there, which may
  # differ from their handle elsewhere and from their Mutter username).
  def profile_url
    prefix = PROFILE_URL_PREFIXES[provider]
    return if prefix.nil? || username.blank?

    "#{prefix}#{ERB::Util.url_encode(username)}"
  end

  # The channel to read chat from: the handle the provider gave us at
  # sign-in (a Twitch login is the channel name).
  def chat_channel
    username.presence if CHAT_PROVIDERS.include?(provider)
  end

  # Handles can change (a Twitch rename) and identities linked before we
  # stored them have none, so every sign-in/connect refreshes it.
  def refresh_handle(handle)
    update(username: handle) if handle.present? && username != handle
  end
end
