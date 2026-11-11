class Identity < ApplicationRecord
  # Providers whose live chat the Streaming page can read, keyed to the
  # per-provider client in app/javascript/chat/.
  CHAT_PROVIDERS = %w[twitch].freeze

  belongs_to :user
  validates :uuid, :provider, presence: true
  validates :uuid, uniqueness: { scope: :provider }

  scope :chat_capable, -> { where(provider: CHAT_PROVIDERS) }

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
