# Enables OmniAuth's test mode so OAuth flows can be exercised in request
# specs without hitting real providers, and provides a helper for building a
# mock auth hash (mirrors test/test_helper.rb's Minitest equivalent).
OmniAuth.config.test_mode = true
OmniAuth.config.logger = Logger.new(File::NULL)

module OmniauthTestHelpers
  def mock_auth_hash(provider: 'developer', uid: '123456', email: 'oauth@example.com', nickname: 'oauthuser',
                     name: 'OAuth User')
    OmniAuth::AuthHash.new(
      provider: provider.to_s,
      uid: uid,
      info: OmniAuth::AuthHash::InfoHash.new(
        email: email,
        nickname: nickname,
        name: name,
        image: 'https://example.com/avatar.png'
      ),
      credentials: OmniAuth::AuthHash.new(token: 'mock_token', secret: 'mock_secret')
    )
  end

  # Points OmniAuth's test-mode mock at the given provider so a real request
  # through /auth/:provider (and its callback) returns this auth hash instead
  # of hitting the network.
  def mock_provider_auth(**)
    hash = mock_auth_hash(**)
    OmniAuth.config.mock_auth[hash.provider.to_sym] = hash
    hash
  end

  def mock_provider_failure(provider, error = :invalid_credentials)
    OmniAuth.config.mock_auth[provider.to_sym] = error
  end
end

RSpec.configure do |config|
  config.include OmniauthTestHelpers, type: :request

  # mock_auth is global state; don't let one example's provider mock leak into the next.
  config.after(:each, type: :request) do
    OmniAuth.config.mock_auth.each_key { |provider| OmniAuth.config.mock_auth[provider] = nil unless provider == :default }
  end
end
