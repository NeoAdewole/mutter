require 'webmock/rspec'

# Specs must never reach the real network.
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.before do
    # A developer machine has real Twitch credentials in config/credentials.yml.enc
    # (CI doesn't); either way specs start with Twitch unconfigured and opt in explicitly.
    allow(Twitch::Client).to receive(:from_credentials).and_return(nil)
    Twitch::Client.token_cache.clear
  end
end
