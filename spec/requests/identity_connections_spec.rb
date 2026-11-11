require 'rails_helper'

RSpec.describe 'Connecting an identity provider to an existing, logged-in account', type: :request do
  def start_connect_flow(provider: 'developer', return_to: nil, **auth_attrs)
    mock_provider_auth(provider: provider, **auth_attrs)
    post "/auth/#{provider}?connect=true#{"&return=#{return_to}" if return_to}"
    follow_redirect! # -> /auth/:provider/callback
  end

  it "links a not-yet-connected provider identity to the signed-in user's own account, without changing who's logged in" do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    expect do
      start_connect_flow(uid: 'dev-uid-new')
    end.to change(Identity, :count).by(1)

    expect(session[:user_id]).to eq(user.id)
    expect(user.identities.sole.uuid).to eq('dev-uid-new')
    expect(flash[:notice]).to match(/connected/i).and match(/developer/i)
  end

  it "records the provider's handle on a newly connected identity" do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    start_connect_flow(uid: 'dev-uid-handle', nickname: 'mychannel')

    expect(user.identities.sole.username).to eq('mychannel')
  end

  it 'refreshes the handle when re-connecting an identity linked before handles were stored' do
    user = create(:user)
    identity = create(:identity, user: user, provider: 'developer', uuid: 'dev-uid-old', username: nil)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    start_connect_flow(uid: 'dev-uid-old', nickname: 'backfilled')

    expect(identity.reload.username).to eq('backfilled')
    expect(flash[:notice]).to match(/already connected/i)
  end

  it 'can send the user back to the Streaming page afterwards, and ignores any other return target' do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    start_connect_flow(uid: 'dev-uid-return', return_to: 'streaming')
    expect(response).to redirect_to(streaming_path)

    start_connect_flow(uid: 'dev-uid-return-2', return_to: 'https://evil.example')
    expect(response).to redirect_to(edit_registration_path)
  end

  it 'is idempotent when reconnecting a provider identity already linked to the same account' do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }
    start_connect_flow(uid: 'dev-uid-repeat')

    expect do
      start_connect_flow(uid: 'dev-uid-repeat')
    end.not_to change(Identity, :count)

    expect(session[:user_id]).to eq(user.id)
    expect(flash[:notice]).to match(/already connected/i)
  end

  it "refuses to steal an identity already connected to someone else's account, and leaves both accounts untouched" do
    owner = create(:user)
    other = create(:user)
    owner_identity = create(:identity, user: owner, provider: 'developer', uuid: 'dev-uid-taken')

    post session_path, params: { user: { email: other.email, password: 'password123' } }

    expect do
      start_connect_flow(uid: 'dev-uid-taken')
    end.not_to change(Identity, :count)

    expect(session[:user_id]).to eq(other.id)
    expect(owner_identity.reload.user).to eq(owner)
    expect(other.identities.count).to eq(0)
    expect(flash[:alert]).to match(/already connected to a different/i)
  end

  it 'requires being signed in' do
    mock_provider_auth(provider: 'developer')
    post '/auth/developer?connect=true'
    follow_redirect!

    expect(response).to redirect_to(new_session_path)
  end

  describe 'GET /registration/edit' do
    it 'offers a connect button for every provider not yet linked, and none for ones already linked' do
      user = create(:user)
      create(:identity, user: user, provider: 'github', uuid: 'gh-1')
      post session_path, params: { user: { email: user.email, password: 'password123' } }

      get edit_registration_path

      expect(response.body).to include('/auth/google_oauth2?connect=true')
      expect(response.body).not_to include('/auth/github?connect=true')
    end

    it 'describes each connected account meaningfully instead of printing the raw object' do
      user = create(:user)
      identity = create(:identity, user: user, provider: 'github', uuid: 'gh-1', created_at: Time.zone.local(2026, 1, 5))
      post session_path, params: { user: { email: user.email, password: 'password123' } }

      get edit_registration_path

      expect(response.body).not_to match(/#&lt;Identity/)
      expect(response.body).not_to include(identity.to_s)
      expect(response.body).to match(/Jan(?:uary)? 5,? 2026/)
    end
  end
end
