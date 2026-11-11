module Twitch
  # Which Mutter users' connected Twitch channels are live right now. This is
  # best-effort: if Twitch is unreachable, unconfigured, or erroring, callers
  # (e.g. the home page) get an empty list rather than an error.
  module LiveStreams
    CACHE_TTL = 1.minute
    FAILURE_TTL = 30.seconds # back off briefly so an outage doesn't slow every page view
    DEFAULT_LIMIT = 5 # the busiest streams, by current viewers

    def self.current(client: Client.from_credentials, limit: DEFAULT_LIMIT)
      channels = connected_channels
      return [] if client.nil? || channels.empty?

      fetch_cached(channels, client).sort_by { |stream| -stream.viewers }.first(limit)
    end

    # Only users who haven't opted out (users.show_stream_on_homepage). The cache key
    # below is built from this list, so opting out takes effect immediately rather
    # than after a cached answer that still includes the user expires.
    def self.connected_channels
      Identity.joins(:user)
              .where(provider: 'twitch', users: { show_stream_on_homepage: true })
              .where.not(username: [nil, ''])
              .pluck(:username).map(&:downcase).uniq.sort
    end

    def self.fetch_cached(channels, client)
      key = "twitch/live/#{Digest::SHA256.hexdigest(channels.join(','))}"
      Rails.cache.fetch(key, expires_in: CACHE_TTL) { client.live_streams(channels) }
    rescue Client::Error => e
      Rails.logger.warn("Twitch live-stream lookup failed: #{e.message}")
      Rails.cache.write(key, [], expires_in: FAILURE_TTL)
      []
    end

    private_class_method :connected_channels, :fetch_cached
  end
end
