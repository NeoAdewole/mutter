require 'net/http'
require 'json'

module Youtube
  # Reads a person's own YouTube channel using the access token they just
  # granted (read-only, youtube.readonly). Google sign-in on its own says
  # nothing about a YouTube channel, which is why this exists.
  class Client
    class Error < StandardError; end

    CHANNELS_URI = URI('https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true')
    HANDLE_PATTERN = /\A[\p{L}\p{N}_.-]{3,30}\z/
    NETWORK_TIMEOUTS = { open_timeout: 3, read_timeout: 5 }.freeze

    def initialize(access_token:)
      @access_token = access_token
    end

    # The token's own channel, or nil if there is no token or the Google
    # account has no YouTube channel. Raises Error if YouTube fails.
    def channel
      return if @access_token.blank?

      response = perform(Net::HTTP::Get.new(CHANNELS_URI, 'Authorization' => "Bearer #{@access_token}"))
      raise Error, "YouTube channel request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      item = Array(parse(response)['items']).first
      build_channel(item) if item
    end

    private

    def build_channel(item)
      snippet = item['snippet'] || {}
      handle = snippet['customUrl'].to_s.delete_prefix('@')
      Channel.new(id: item['id'], title: snippet['title'], handle: (handle if handle.match?(HANDLE_PATTERN)))
    end

    def parse(response)
      data = JSON.parse(response.body)
      raise Error, 'YouTube returned an unreadable response' unless data.is_a?(Hash)

      data
    rescue JSON::ParserError
      raise Error, 'YouTube returned an unreadable response'
    end

    def perform(request)
      Net::HTTP.start(CHANNELS_URI.host, CHANNELS_URI.port, use_ssl: true, **NETWORK_TIMEOUTS) { |http| http.request(request) }
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "YouTube request failed (#{e.class})"
    end
  end
end
