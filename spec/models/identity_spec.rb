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
end
