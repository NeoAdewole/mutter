ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

# Enable OmniAuth test mode so OAuth flows can be tested without real providers.
OmniAuth.config.test_mode = true
OmniAuth.config.logger = Logger.new('/dev/null')

# Required for mailer views that use _url helpers (needs a host).
Rails.application.routes.default_url_options[:host] = 'localhost'
ActionMailer::Base.default_url_options = { host: 'localhost' }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Build a mock OmniAuth auth hash for a given provider.
    def mock_auth_hash(provider: 'github', uid: '123456', email: 'oauth@example.com', nickname: 'oauthuser', name: 'OAuth User')
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
  end
end
