require 'rails_helper'

RSpec.describe User, 'admin flag', type: :model do
  it 'is false by default' do
    expect(described_class.new).not_to be_admin
    expect(create(:user)).not_to be_admin
  end

  it 'can be granted through the factory trait' do
    expect(create(:user, :admin)).to be_admin
  end

  it 'is not set for accounts created through a provider sign-in' do
    auth_hash = OmniAuth::AuthHash.new(
      provider: 'github',
      uid: 'uid-admin-check',
      info: OmniAuth::AuthHash::InfoHash.new(email: 'oauth-admin@example.com', nickname: 'sneaky', name: 'Sneaky Admin', admin: true)
    )
    expect(described_class.find_or_create_from_auth_hash(auth_hash)).not_to be_admin
  end
end
