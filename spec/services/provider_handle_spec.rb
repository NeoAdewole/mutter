require 'rails_helper'

RSpec.describe ProviderHandle do
  def auth(provider, nickname: nil, token: 'tok')
    OmniAuth::AuthHash.new(
      provider: provider, uid: 'uid-1',
      info: OmniAuth::AuthHash::InfoHash.new(nickname: nickname),
      credentials: OmniAuth::AuthHash.new(token: token)
    )
  end

  describe '.for' do
    it "is the provider's nickname for most services (a Twitch login, a GitHub login...)" do
      expect(described_class.for(auth('twitch', nickname: 'bevybabble'))).to eq('bevybabble')
      expect(described_class.for(auth('github', nickname: 'coder'))).to eq('coder')
    end

    it 'is nil when the provider gave no nickname' do
      expect(described_class.for(auth('google_oauth2'))).to be_nil
      expect(described_class.for(auth('twitch', nickname: ''))).to be_nil
    end

    describe 'for YouTube' do
      let(:client) { instance_double(Youtube::Client) }

      before { allow(Youtube::Client).to receive(:new).with(access_token: 'tok').and_return(client) }

      it "asks YouTube for the person's channel handle (Google sign-in itself has none)" do
        allow(client).to receive(:channel).and_return(Youtube::Channel.new(id: 'UC1', title: 'Mass Mutter', handle: 'MassMutter'))

        expect(described_class.for(auth('youtube'))).to eq('MassMutter')
      end

      it 'is nil when there is no channel or no handle' do
        allow(client).to receive(:channel).and_return(nil)
        expect(described_class.for(auth('youtube'))).to be_nil

        allow(client).to receive(:channel).and_return(Youtube::Channel.new(id: 'UC1', title: 'x', handle: nil))
        expect(described_class.for(auth('youtube'))).to be_nil
      end

      it 'is nil, and logs, when YouTube cannot be reached, so connecting is not blocked by it' do
        allow(client).to receive(:channel).and_raise(Youtube::Client::Error, 'boom')
        allow(Rails.logger).to receive(:warn)

        expect(described_class.for(auth('youtube'))).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/boom/)
      end
    end
  end
end
