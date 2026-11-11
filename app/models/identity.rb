class Identity < ApplicationRecord
  belongs_to :user
  validates :uuid, :provider, presence: true
  validates :uuid, uniqueness: { scope: :provider }

  # Handles can change (a Twitch rename) and identities linked before we
  # stored them have none, so every sign-in/connect refreshes it.
  def refresh_handle(handle)
    update(username: handle) if handle.present? && username != handle
  end
end
