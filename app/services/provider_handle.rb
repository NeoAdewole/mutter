# The person's handle on a provider's own service, as we should store it on
# their identity. For most providers the OAuth response carries it (a Twitch
# login, a GitHub login); Google sign-in carries none, so for YouTube it has
# to be asked of YouTube itself. Best-effort: a failure means "no handle yet",
# never a failed sign-in/connect.
module ProviderHandle
  def self.for(auth_hash)
    return youtube_handle(auth_hash) if auth_hash.provider.to_s == 'youtube'

    auth_hash.info&.nickname.presence
  end

  def self.youtube_handle(auth_hash)
    Youtube::Client.new(access_token: auth_hash.credentials&.token).channel&.handle
  rescue Youtube::Client::Error => e
    Rails.logger.warn("YouTube channel lookup failed: #{e.message}")
    nil
  end
  private_class_method :youtube_handle
end
