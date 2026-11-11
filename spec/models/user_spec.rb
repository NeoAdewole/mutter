require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe 'associations' do
    it { is_expected.to have_many(:identities).dependent(:destroy) }
    it { is_expected.to have_many(:twitter_accounts).dependent(:destroy) }
    it { is_expected.to have_many(:tweets).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:firstname) }
    it { is_expected.to validate_presence_of(:lastname) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username).case_insensitive }

    it { is_expected.to validate_presence_of(:password_confirmation) }
    it { is_expected.to validate_length_of(:password).is_at_least(6) }

    it 'is invalid with a malformed email' do
      user.email = 'not-an-email'
      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end
  end

  describe 'email normalization' do
    it 'strips and downcases the email before saving' do
      user = create(:user, email: '  Mixed.Case@Example.com  ')
      expect(user.email).to eq('mixed.case@example.com')
    end
  end

  describe '.find_or_create_from_auth_hash' do
    let(:auth_hash) do
      OmniAuth::AuthHash.new(
        provider: 'github',
        uid: 'uid-123',
        info: OmniAuth::AuthHash::InfoHash.new(
          email: 'oauth-user@example.com',
          nickname: 'oauthuser',
          name: 'Oauth User'
        )
      )
    end

    it 'creates a new user and identity on first sign-in' do
      expect do
        described_class.find_or_create_from_auth_hash(auth_hash)
      end.to change(described_class, :count).by(1).and change(Identity, :count).by(1)
    end

    it 'reuses the existing user on subsequent sign-ins with the same identity' do
      first_user = described_class.find_or_create_from_auth_hash(auth_hash)

      expect do
        described_class.find_or_create_from_auth_hash(auth_hash)
      end.not_to change(described_class, :count)

      expect(described_class.find_or_create_from_auth_hash(auth_hash)).to eq(first_user)
    end

    describe 'when the provider handle is already someone else\'s Mutter username' do
      # Provider handles only have to be unique within their own service, but the
      # Mutter username is one namespace for everyone, so different people can clash.
      it 'signs the new person up under a free variant instead of failing, keeping the real handle on the identity' do
        create(:user, username: 'oauthuser')

        user = described_class.find_or_create_from_auth_hash(auth_hash)

        expect(user).to be_persisted
        expect(user.username).to eq('oauthuser2')
        expect(user.identities.sole.username).to eq('oauthuser')
      end

      it 'treats usernames case-insensitively' do
        create(:user, username: 'OAuthUser')

        expect(described_class.find_or_create_from_auth_hash(auth_hash).username).to eq('oauthuser2')
      end

      it 'keeps counting until it finds a free one' do
        %w[oauthuser oauthuser2 oauthuser3].each { |name| create(:user, username: name) }

        expect(described_class.find_or_create_from_auth_hash(auth_hash).username).to eq('oauthuser4')
      end

      it 'uses the handle as-is when nobody has it' do
        expect(described_class.find_or_create_from_auth_hash(auth_hash).username).to eq('oauthuser')
      end

      it 'does not touch the account of someone who signs in again with the same identity' do
        first = described_class.find_or_create_from_auth_hash(auth_hash)
        create(:user, username: 'oauthuser3') # a later clash must not rename the existing user

        expect(described_class.find_or_create_from_auth_hash(auth_hash)).to eq(first)
        expect(first.reload.username).to eq('oauthuser')
      end
    end

    it 'still signs up when the provider gives neither a nickname nor a name, using the email name' do
      bare = OmniAuth::AuthHash.new(
        provider: 'github', uid: 'uid-bare',
        info: OmniAuth::AuthHash::InfoHash.new(email: 'quiet.person@example.com')
      )

      user = described_class.find_or_create_from_auth_hash(bare)

      expect(user).to be_persisted
      expect(user).to have_attributes(username: 'quiet.person', firstname: 'quiet.person', lastname: 'quiet.person')
    end

    it "records the provider's handle (e.g. a Twitch login) on the identity at first sign-in" do
      user = described_class.find_or_create_from_auth_hash(auth_hash)
      expect(user.identities.sole.username).to eq('oauthuser')
    end

    it 'backfills and refreshes the handle on later sign-ins, including for an identity created before it was stored' do
      user = described_class.find_or_create_from_auth_hash(auth_hash)
      identity = user.identities.sole
      identity.update!(username: nil)

      described_class.find_or_create_from_auth_hash(auth_hash)
      expect(identity.reload.username).to eq('oauthuser')

      renamed = OmniAuth::AuthHash.new(auth_hash.to_hash.merge('info' => auth_hash.info.to_hash.merge('nickname' => 'renameduser')))
      described_class.find_or_create_from_auth_hash(renamed)
      expect(identity.reload.username).to eq('renameduser')
    end

    it 'marks a newly created OAuth user as not having a real password set' do
      user = described_class.find_or_create_from_auth_hash(auth_hash)
      expect(user.password_set).to be false
    end

    it 'links a new identity to an existing password-registered account with the same email, leaving password_set untouched' do
      existing = create(:user, email: 'oauth-user@example.com', password_set: true)

      user = described_class.find_or_create_from_auth_hash(auth_hash)

      expect(user).to eq(existing)
      expect(user.password_set).to be true
    end

    it 'does not reset password_set on repeat OAuth sign-ins' do
      user = described_class.find_or_create_from_auth_hash(auth_hash)
      user.update!(password_set: true, password: 'realpassword', password_confirmation: 'realpassword')

      returning_user = described_class.find_or_create_from_auth_hash(auth_hash)
      expect(returning_user.password_set).to be true
    end
  end

  describe 'password_set default' do
    it 'defaults to true for a normally registered user' do
      expect(create(:user).password_set).to be true
    end
  end

  describe 'show_stream_on_homepage default' do
    it 'is on until the user opts out' do
      expect(create(:user).show_stream_on_homepage).to be true
    end
  end
end
