require 'rails_helper'

RSpec.describe Youtube::Client do
  subject(:client) { described_class.new(access_token: 'user-token') }

  let(:channels_url) { 'https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true' }
  let(:json) { { 'Content-Type' => 'application/json' } }

  def stub_channels(status: 200, body: {})
    stub_request(:get, channels_url)
      .with(headers: { 'Authorization' => 'Bearer user-token' })
      .to_return(status: status, headers: json, body: body.to_json)
  end

  describe '#channel' do
    it "returns the signed-in person's own channel, with its handle (without the leading @)" do
      request = stub_channels(body: { items: [{ id: 'UC123', snippet: { title: 'Mass Mutter', customUrl: '@MassMutter' } }] })

      channel = client.channel

      expect(request).to have_been_requested.once
      expect(channel).to have_attributes(id: 'UC123', title: 'Mass Mutter', handle: 'MassMutter')
    end

    it 'returns the channel with no handle when YouTube has not given it one' do
      stub_channels(body: { items: [{ id: 'UC123', snippet: { title: 'Old Channel' } }] })

      expect(client.channel).to have_attributes(id: 'UC123', handle: nil)
    end

    it 'does not trust a handle that could not be a YouTube handle' do
      stub_channels(body: { items: [{ id: 'UC123', snippet: { title: 'x', customUrl: '@bad handle/<script>' } }] })

      expect(client.channel.handle).to be_nil
    end

    it 'returns nil when the Google account has no YouTube channel' do
      stub_channels(body: { pageInfo: { totalResults: 0 } })

      expect(client.channel).to be_nil
    end

    it 'raises Youtube::Client::Error when YouTube refuses the request' do
      stub_channels(status: 403, body: { error: { message: 'API not enabled' } })

      expect { client.channel }.to raise_error(Youtube::Client::Error, /403/)
    end

    it 'raises Youtube::Client::Error when the token is rejected' do
      stub_channels(status: 401, body: {})

      expect { client.channel }.to raise_error(Youtube::Client::Error, /401/)
    end

    it 'raises Youtube::Client::Error on a network timeout' do
      stub_request(:get, channels_url).to_timeout

      expect { client.channel }.to raise_error(Youtube::Client::Error)
    end

    it 'raises Youtube::Client::Error on an unreadable response' do
      stub_request(:get, channels_url).to_return(status: 200, body: '<html>not json</html>')

      expect { client.channel }.to raise_error(Youtube::Client::Error)
    end

    it 'does nothing without an access token' do
      expect(described_class.new(access_token: nil).channel).to be_nil
      expect(a_request(:any, /googleapis/)).not_to have_been_made
    end
  end
end
