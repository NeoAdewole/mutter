require 'rails_helper'

RSpec.describe 'Admin disconnecting a linked account', type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user, username: 'linker') }

  before { sign_in_as(admin) }

  it "removes one of the person's linked accounts and records it, leaving the others" do
    twitch = create(:identity, user: user, provider: 'twitch', uuid: 't', username: 'linker_tv')
    github = create(:identity, user: user, provider: 'github', uuid: 'g')

    expect { delete admin_user_identity_path(user, twitch) }.to change(Identity, :count).by(-1)

    expect(response).to redirect_to(admin_user_path(user))
    expect(user.identities).to contain_exactly(github)
    expect(flash[:notice]).to include('Twitch (linker_tv)')
    entry = AuditLog.order(:id).last
    expect(entry).to have_attributes(action: 'user.identity_disconnected', actor: admin, target_id: user.id)
    expect(entry.details).to eq('provider' => 'twitch', 'handle' => 'linker_tv')
  end

  it 'is fine when the person has a password, even if it is their only linked account' do
    github = create(:identity, user: user, provider: 'github', uuid: 'g')

    delete admin_user_identity_path(user, github)

    expect(user.identities).to be_empty
    expect(user.reload).to be_password_set
  end

  it "refuses to remove someone's only way to sign in, and says how to fix it" do
    user.update!(password_set: false)
    github = create(:identity, user: user, provider: 'github', uuid: 'g')

    expect { delete admin_user_identity_path(user, github) }.not_to change(Identity, :count)

    expect(flash[:alert]).to include('only way to sign in').and include('password reset')
    expect(AuditLog.count).to eq(0)
  end

  it 'allows removing a YouTube connection from an account that signs in some other way' do
    user.update!(password_set: false)
    create(:identity, user: user, provider: 'github', uuid: 'g')
    youtube = create(:identity, user: user, provider: 'youtube', uuid: 'y', username: 'chan')

    expect { delete admin_user_identity_path(user, youtube) }.to change(Identity, :count).by(-1)
  end

  it "is a 404 for another person's linked account, and removes nothing" do
    other = create(:identity, user: create(:user), provider: 'github', uuid: 'other')

    expect { delete admin_user_identity_path(user, other) }.not_to change(Identity, :count)
    expect(response).to have_http_status(:not_found)
  end
end
