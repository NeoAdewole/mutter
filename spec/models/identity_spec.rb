require 'rails_helper'

RSpec.describe Identity, type: :model do
  describe '.chat_capable' do
    it 'includes identities from providers whose chat we can read, and excludes the rest' do
      twitch = create(:identity, provider: 'twitch', username: 'streamer')
      create(:identity, provider: 'github', username: 'coder')

      expect(described_class.chat_capable).to contain_exactly(twitch)
    end
  end

  describe '#chat_channel' do
    it 'is the provider handle for a chat-capable provider' do
      expect(build(:identity, provider: 'twitch', username: 'streamer').chat_channel).to eq('streamer')
    end

    it 'is nil when no handle has been stored yet' do
      expect(build(:identity, provider: 'twitch', username: nil).chat_channel).to be_nil
      expect(build(:identity, provider: 'twitch', username: '').chat_channel).to be_nil
    end

    it 'is nil for providers without readable chat, even when a handle is stored' do
      expect(build(:identity, provider: 'github', username: 'coder').chat_channel).to be_nil
    end
  end

  describe 'the same person under different handles on different services' do
    it 'keeps each handle with its own connection, and allows them to differ' do
      user = create(:user)
      twitch = create(:identity, user: user, provider: 'twitch', username: 'BevyBabble')
      youtube = create(:identity, user: user, provider: 'youtube', username: 'MassMutter')

      expect(user.identities.reload).to contain_exactly(twitch, youtube)
      expect(twitch.username).to eq('BevyBabble')
      expect(youtube.username).to eq('MassMutter')
    end

    it 'lets different people share a handle on different services (and even the same one)' do
      create(:identity, provider: 'twitch', username: 'shared')

      expect { create(:identity, provider: 'youtube', username: 'shared') }.not_to raise_error
      expect { create(:identity, provider: 'twitch', username: 'shared') }.not_to raise_error
    end
  end

  describe '.label_for' do
    it 'gives each provider its proper display name' do
      expect(described_class.label_for('twitter2')).to eq('Twitter')
      expect(described_class.label_for('google_oauth2')).to eq('Google')
      expect(described_class.label_for('youtube')).to eq('YouTube')
      expect(described_class.label_for('github')).to eq('GitHub')
    end

    it 'falls back to a readable name for providers it does not know' do
      expect(described_class.label_for('some_new_service')).to eq('Some New Service')
    end
  end

  describe '#profile_url' do
    it 'links to the account on its own service' do
      expect(build(:identity, provider: 'twitch', username: 'BevyBabble').profile_url).to eq('https://www.twitch.tv/BevyBabble')
      expect(build(:identity, provider: 'youtube', username: 'MassMutter').profile_url).to eq('https://www.youtube.com/@MassMutter')
      expect(build(:identity, provider: 'github', username: 'coder').profile_url).to eq('https://github.com/coder')
    end

    it 'is nil when there is no handle, or no known profile page for the service' do
      expect(build(:identity, provider: 'twitch', username: nil).profile_url).to be_nil
      expect(build(:identity, provider: 'google_oauth2', username: 'whoever').profile_url).to be_nil
    end

    it 'escapes the handle so it can never change the link' do
      expect(build(:identity, provider: 'twitch', username: 'a b/../c').profile_url).to eq('https://www.twitch.tv/a%20b%2F..%2Fc')
    end
  end
end
