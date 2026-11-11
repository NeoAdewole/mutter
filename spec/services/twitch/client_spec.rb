require 'rails_helper'

RSpec.describe Twitch::Client do
  subject(:client) { described_class.new(client_id: 'cid', client_secret: 'csecret') }

  let(:token_url) { 'https://id.twitch.tv/oauth2/token' }
  let(:streams_url) { 'https://api.twitch.tv/helix/streams' }
  let(:json) { { 'Content-Type' => 'application/json' } }

  before { described_class.token_cache.clear }

  def stub_token(*tokens)
    responses = tokens.map do |token|
      { status: 200, headers: json, body: { access_token: token, expires_in: 5_000_000, token_type: 'bearer' }.to_json }
    end
    stub_request(:post, token_url)
      .with(body: { client_id: 'cid', client_secret: 'csecret', grant_type: 'client_credentials' })
      .to_return(*responses)
  end

  def live_json(login, viewers: 10)
    { id: "s-#{login}", user_login: login, user_name: login.capitalize, title: "#{login} is live", game_name: 'Just Chatting',
      viewer_count: viewers, type: 'live' }
  end

  def stub_streams(query, token: 'tok-1', data: [])
    stub_request(:get, "#{streams_url}?#{query}")
      .with(headers: { 'Client-Id' => 'cid', 'Authorization' => "Bearer #{token}" })
      .to_return(status: 200, headers: json, body: { data: data }.to_json)
  end

  describe '#live_streams' do
    it 'asks Twitch which of the channels are live, authenticating as the app, and returns them as streams' do
      stub_token('tok-1')
      request = stub_streams('user_login=alice&user_login=bob', data: [live_json('alice', viewers: 42)])

      streams = client.live_streams(%w[alice bob])

      expect(request).to have_been_requested.once
      expect(streams.size).to eq(1)
      expect(streams.first).to have_attributes(login: 'alice', name: 'Alice', title: 'alice is live', game: 'Just Chatting', viewers: 42)
    end

    it 'does not call Twitch at all when there is nothing to ask about' do
      expect(client.live_streams([])).to eq([])
      expect(a_request(:any, /twitch\.tv/)).not_to have_been_made
    end

    it 'splits long channel lists into batches within Twitch\'s 100-login limit' do
      stub_token('tok-1')
      logins = (1..150).map { |n| "channel#{n}" }
      first = stub_streams(logins.first(100).map { |l| "user_login=#{l}" }.join('&'), data: [live_json('channel1')])
      second = stub_streams(logins.last(50).map { |l| "user_login=#{l}" }.join('&'), data: [live_json('channel150')])

      streams = client.live_streams(logins)

      expect(first).to have_been_requested.once
      expect(second).to have_been_requested.once
      expect(streams.map(&:login)).to contain_exactly('channel1', 'channel150')
    end

    it 'reuses the app token across calls instead of requesting a new one each time' do
      token_request = stub_token('tok-1')
      stub_streams('user_login=alice')

      client.live_streams(['alice'])
      described_class.new(client_id: 'cid', client_secret: 'csecret').live_streams(['alice'])

      expect(token_request).to have_been_requested.once
    end

    it 'fetches a fresh token and retries once if Twitch rejects the cached one' do
      token_request = stub_token('stale', 'fresh')
      stub_request(:get, "#{streams_url}?user_login=alice")
        .with(headers: { 'Authorization' => 'Bearer stale' }).to_return(status: 401, body: '{}')
      retried = stub_streams('user_login=alice', token: 'fresh', data: [live_json('alice')])

      expect(client.live_streams(['alice']).map(&:login)).to eq(['alice'])
      expect(token_request).to have_been_requested.twice
      expect(retried).to have_been_requested.once
    end

    it 'ignores entries with a login that could not be a Twitch channel' do
      stub_token('tok-1')
      stub_streams('user_login=alice', data: [live_json('alice'), live_json('not a channel!')])

      expect(client.live_streams(['alice']).map(&:login)).to eq(['alice'])
    end

    it 'raises a Twitch::Client::Error when Twitch fails' do
      stub_token('tok-1')
      stub_request(:get, "#{streams_url}?user_login=alice").to_return(status: 500, body: 'boom')

      expect { client.live_streams(['alice']) }.to raise_error(Twitch::Client::Error, /500/)
    end

    it 'raises a Twitch::Client::Error when the network times out' do
      stub_request(:post, token_url).to_timeout

      expect { client.live_streams(['alice']) }.to raise_error(Twitch::Client::Error)
    end
  end

  describe '.from_credentials' do
    it 'builds a client from flat or nested credentials, and is nil when none are configured' do
      allow(described_class).to receive(:from_credentials).and_call_original # specs stub it out globally
      credentials = double('credentials') # EncryptedConfiguration delegates #dig dynamically, so it can't be verified
      allow(Rails.application).to receive(:credentials).and_return(credentials)

      allow(credentials).to receive(:dig).with(:twitch, :client_id).and_return(nil)
      allow(credentials).to receive(:dig).with(:twitch, :client_secret).and_return(nil)
      allow(credentials).to receive(:[]).with(:twitch_client_id).and_return('flat-id')
      allow(credentials).to receive(:[]).with(:twitch_client_secret).and_return('flat-secret')
      expect(described_class.from_credentials).to be_a(described_class)

      allow(credentials).to receive(:[]).with(:twitch_client_id).and_return(nil)
      expect(described_class.from_credentials).to be_nil
    end
  end
end
