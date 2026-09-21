require 'rails_helper'

RSpec.describe 'Sessions (log in)', type: :request do
  describe 'GET /session/new' do
    it 'renders the log in form with every configured identity provider offered' do
      get new_session_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('/auth/github')
      expect(response.body).to include('/auth/google_oauth2')
      expect(response.body).to include('/auth/discord')
      expect(response.body).to include('/auth/twitch')
      expect(response.body).to include('/auth/twitter2')
      expect(response.body).to include('/auth/developer')
    end
  end

  describe 'password log in' do
    let!(:user) { create(:user, email: 'alice@example.com', password: 'password123', password_confirmation: 'password123') }

    it 'logs in with valid credentials' do
      post session_path, params: { user: { email: 'alice@example.com', password: 'password123' } }
      expect(response).to redirect_to(about_path)
      expect(flash[:notice]).to eq('Signed in!')
      expect(session[:user_id]).to eq(user.id)
    end

    it 'logs in by username as well as email' do
      post session_path, params: { user: { email: user.username, password: 'password123' } }
      expect(session[:user_id]).to eq(user.id)
    end

    it 'rejects an invalid password without revealing whether the account exists' do
      post session_path, params: { user: { email: 'alice@example.com', password: 'wrongpassword' } }
      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq('Invalid email/username or password.')
      expect(session[:user_id]).to be_nil
    end

    it 'rejects an unknown account with the same generic message' do
      post session_path, params: { user: { email: 'nobody@example.com', password: 'whatever1' } }
      expect(flash[:alert]).to eq('Invalid email/username or password.')
    end
  end

  describe 'OAuth log in / sign up' do
    it 'creates a new account on first sign-in via a provider and explains the account has no password yet' do
      mock_provider_auth(provider: 'developer', email: 'new-oauth-user@example.com', nickname: 'newoauthuser', name: 'New OAuth')

      expect do
        get '/auth/developer/callback'
      end.to change(User, :count).by(1)

      user = User.find_by(email: 'new-oauth-user@example.com')
      expect(user.password_set).to be false
      expect(session[:user_id]).to eq(user.id)
      expect(flash[:notice]).to include('Developer').and include('password')
    end

    it 'logs an existing OAuth user back in without creating a duplicate account, with a returning-user message' do
      auth = mock_provider_auth(provider: 'developer', email: 'returning@example.com', uid: 'dev-uid-1')
      get '/auth/developer/callback'
      sign_out

      OmniAuth.config.mock_auth[:developer] = auth
      expect do
        get '/auth/developer/callback'
      end.not_to change(User, :count)

      expect(flash[:notice]).to include('Welcome back')
    end

    it 'sends a user with no email from the provider to complete their profile' do
      mock_provider_auth(provider: 'developer', email: '', nickname: 'noemailuser')
      get '/auth/developer/callback'

      expect(response).to redirect_to(edit_registration_path)
      expect(flash[:notice]).to match(/email/i)
    end
  end

  def sign_out
    delete session_path
  end
end
