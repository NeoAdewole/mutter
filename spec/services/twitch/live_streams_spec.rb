require 'rails_helper'

RSpec.describe Twitch::LiveStreams do
  let(:client) { instance_double(Twitch::Client) }

  def stream(login, viewers = 1)
    Twitch::Stream.new(login: login, name: login.capitalize, title: "#{login} live", game: 'Celeste', viewers: viewers)
  end

  describe '.current' do
    it 'asks Twitch about every distinct connected Twitch channel, ignoring other providers and accounts with no channel name' do
      create(:identity, provider: 'twitch', username: 'alice')
      create(:identity, provider: 'twitch', username: 'Alice') # same channel, different casing
      create(:identity, provider: 'twitch', username: 'bob')
      create(:identity, provider: 'twitch', username: nil)
      create(:identity, provider: 'github', username: 'coder')
      allow(client).to receive(:live_streams).and_return([])

      described_class.current(client: client)

      expect(client).to have_received(:live_streams).with(%w[alice bob])
    end

    it 'returns the live streams, busiest first, up to the limit' do
      create(:identity, provider: 'twitch', username: 'alice')
      allow(client).to receive(:live_streams).and_return([stream('small', 5), stream('big', 500), stream('mid', 50)])

      expect(described_class.current(client: client, limit: 2).map(&:login)).to eq(%w[big mid])
    end

    it 'shows at most five streams by default: the five with the most viewers' do
      create(:identity, provider: 'twitch', username: 'alice')
      allow(client).to receive(:live_streams).and_return((1..8).map { |n| stream("channel#{n}", n * 10) })

      expect(described_class.current(client: client).map(&:viewers)).to eq([80, 70, 60, 50, 40])
    end

    describe 'users who opted out of being shown on the home page' do
      let(:shown) { create(:user) }
      let(:hidden) { create(:user, show_stream_on_homepage: false) }

      it 'never asks about, or returns, their channels' do
        create(:identity, user: shown, provider: 'twitch', username: 'alice')
        create(:identity, user: hidden, provider: 'twitch', username: 'bob')
        create(:identity, user: hidden, provider: 'twitch', username: 'bobs_alt') # every account of an opted-out user
        allow(client).to receive(:live_streams).and_return([])

        described_class.current(client: client)

        expect(client).to have_received(:live_streams).with(['alice'])
      end

      it 'does not call Twitch at all when everyone connected has opted out' do
        create(:identity, user: hidden, provider: 'twitch', username: 'bob')
        allow(client).to receive(:live_streams)

        expect(described_class.current(client: client)).to eq([])
        expect(client).not_to have_received(:live_streams)
      end

      it 'takes effect immediately, even though live results are cached' do
        allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
        create(:identity, user: shown, provider: 'twitch', username: 'alice')
        create(:identity, user: hidden, provider: 'twitch', username: 'bob')
        hidden.update!(show_stream_on_homepage: true)
        allow(client).to receive(:live_streams) { |logins| logins.map { |login| stream(login) } }

        expect(described_class.current(client: client).map(&:login)).to contain_exactly('alice', 'bob')

        hidden.update!(show_stream_on_homepage: false)

        expect(described_class.current(client: client).map(&:login)).to eq(['alice'])
      end
    end

    it 'does not call Twitch when no channels are connected' do
      allow(client).to receive(:live_streams)

      expect(described_class.current(client: client)).to eq([])
      expect(client).not_to have_received(:live_streams)
    end

    it 'returns nothing when Twitch credentials are not configured' do
      create(:identity, provider: 'twitch', username: 'alice')

      expect(described_class.current(client: nil)).to eq([])
    end

    it 'swallows a Twitch failure so the page that asked still renders, and logs it' do
      create(:identity, provider: 'twitch', username: 'alice')
      allow(client).to receive(:live_streams).and_raise(Twitch::Client::Error, 'boom')
      allow(Rails.logger).to receive(:warn)

      expect(described_class.current(client: client)).to eq([])
      expect(Rails.logger).to have_received(:warn).with(/boom/)
    end

    it 'caches the answer briefly so a busy home page does not hit Twitch on every view' do
      create(:identity, provider: 'twitch', username: 'alice')
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      allow(client).to receive(:live_streams).and_return([stream('alice')])

      2.times { described_class.current(client: client) }

      expect(client).to have_received(:live_streams).once
    end
  end
end
