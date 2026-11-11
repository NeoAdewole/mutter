class StreamingController < ApplicationController
  before_action :authenticate_user!

  def show
    identities = current_user.identities.chat_capable.to_a
    channel_identities, @needs_reconnect = identities.partition(&:chat_channel)

    @channels = channel_identities.map do |identity|
      { provider: identity.provider, channel: identity.chat_channel, label: "#{identity.provider.titleize}: #{identity.chat_channel}" }
    end
    @needs_reconnect = @needs_reconnect.map(&:provider).uniq
    @connectable = Identity::CHAT_PROVIDERS - identities.map(&:provider)
  end
end
