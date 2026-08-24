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
    it { is_expected.to validate_uniqueness_of(:username) }

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
  end
end
