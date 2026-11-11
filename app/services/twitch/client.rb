require 'net/http'
require 'json'

module Twitch
  # Minimal client for the one thing we need from Twitch's Helix API: which of
  # a set of channels are live right now. It authenticates as the app
  # (client-credentials grant), so no user token is involved.
  class Client
    class Error < StandardError; end

    TOKEN_URL = URI('https://id.twitch.tv/oauth2/token')
    STREAMS_URL = 'https://api.twitch.tv/helix/streams'.freeze
    MAX_LOGINS_PER_REQUEST = 100
    LOGIN_PATTERN = /\A[A-Za-z0-9_]{1,25}\z/
    NETWORK_TIMEOUTS = { open_timeout: 3, read_timeout: 5 }.freeze
    TOKEN_SAFETY_MARGIN_SECONDS = 300

    # The app token lasts weeks, so it is shared across instances and requests.
    def self.token_cache
      @token_cache ||= ActiveSupport::Cache::MemoryStore.new(size: 64.kilobytes)
    end

    # Twitch's credentials are stored flat (twitch_client_id / twitch_client_secret);
    # the nested form used by the other providers is also honored.
    def self.from_credentials
      credentials = Rails.application.credentials
      id = credentials.dig(:twitch, :client_id) || credentials[:twitch_client_id]
      secret = credentials.dig(:twitch, :client_secret) || credentials[:twitch_client_secret]
      new(client_id: id, client_secret: secret) if id.present? && secret.present?
    end

    def initialize(client_id:, client_secret:)
      @client_id = client_id
      @client_secret = client_secret
    end

    # Returns a Twitch::Stream for each of the given channel logins that is live.
    def live_streams(logins)
      logins.each_slice(MAX_LOGINS_PER_REQUEST).flat_map { |batch| fetch_streams(batch) }
    end

    private

    attr_reader :client_id, :client_secret

    def fetch_streams(logins, retried: false)
      query = logins.map { |login| "user_login=#{CGI.escape(login)}" }.join('&')
      uri = URI("#{STREAMS_URL}?#{query}")
      request = Net::HTTP::Get.new(uri, 'Client-Id' => client_id, 'Authorization' => "Bearer #{token}")
      response = perform(uri, request)

      if response.code == '401' && !retried
        self.class.token_cache.delete(token_key) # rejected: fetch a fresh one and try once more
        return fetch_streams(logins, retried: true)
      end
      raise Error, "Twitch streams request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      parse(response).fetch('data', []).filter_map { |entry| build_stream(entry) }
    end

    def build_stream(entry)
      login = entry['user_login'].to_s
      return unless entry['type'] == 'live' && login.match?(LOGIN_PATTERN)

      Stream.new(login: login, name: entry['user_name'].presence || login, title: entry['title'].to_s,
                 game: entry['game_name'].to_s, viewers: entry['viewer_count'].to_i)
    end

    def token
      cached = self.class.token_cache.read(token_key)
      return cached if cached

      data = request_token
      lifetime = [data['expires_in'].to_i - TOKEN_SAFETY_MARGIN_SECONDS, 60].max
      self.class.token_cache.write(token_key, data['access_token'], expires_in: lifetime)
      data['access_token']
    end

    def request_token
      request = Net::HTTP::Post.new(TOKEN_URL)
      request.set_form_data(client_id: client_id, client_secret: client_secret, grant_type: 'client_credentials')
      response = perform(TOKEN_URL, request)
      raise Error, "Twitch token request failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      data = parse(response)
      raise Error, 'Twitch token response had no access_token' if data['access_token'].blank?

      data
    end

    def token_key
      "twitch/app-token/#{client_id}"
    end

    def parse(response)
      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Error, 'Twitch returned an unreadable response'
    end

    def perform(uri, request)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, **NETWORK_TIMEOUTS) { |http| http.request(request) }
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::SSL::SSLError => e
      raise Error, "Twitch request failed (#{e.class})"
    end
  end
end
