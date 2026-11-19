require 'rails_helper'

RSpec.describe 'Suspended accounts', type: :request do
  let(:user) { create(:user, email: 'member@example.com', username: 'member') }

  describe 'signing in with a password' do
    before { user.suspend!(reason: 'Spamming') }

    it 'is refused, with the reason, and creates no session' do
      post session_path, params: { user: { email: 'member@example.com', password: 'password123' } }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include('suspended').and include('Spamming')
      expect(session[:user_id]).to be_nil
      expect(user.reload.sign_in_count).to eq(0)
    end

    it "doesn't reveal that an account is suspended to someone who doesn't know the password" do
      post session_path, params: { user: { email: 'member@example.com', password: 'wrong-guess' } }

      expect(flash[:alert]).to eq('Invalid email/username or password.')
    end

    it 'works again once the suspension is lifted' do
      user.unsuspend!
      post session_path, params: { user: { email: 'member@example.com', password: 'password123' } }

      expect(session[:user_id]).to eq(user.id)
    end

    it 'is refused without a reason when none was given' do
      user.suspend!
      post session_path, params: { user: { email: 'member@example.com', password: 'password123' } }

      expect(flash[:alert]).to include('suspended')
      expect(flash[:alert]).not_to include('suspended:')
    end
  end

  describe 'signing in with a provider' do
    it 'is refused for a suspended account, and the account is untouched' do
      identity = create(:identity, user: user, provider: 'developer', uuid: 'dev-suspended')
      user.suspend!(reason: 'Ban evasion')
      mock_provider_auth(uid: identity.uuid, email: user.email)

      post '/auth/developer'
      follow_redirect!

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include('suspended').and include('Ban evasion')
      expect(session[:user_id]).to be_nil
      expect(User.count).to eq(1)
    end

    it 'is refused when the provider email matches a suspended account, without linking the new identity' do
      user.suspend!
      mock_provider_auth(uid: 'brand-new', email: 'member@example.com')

      expect do
        post '/auth/developer'
        follow_redirect!
      end.not_to change(User, :count)

      expect(session[:user_id]).to be_nil
    end
  end

  describe 'an account suspended while it is signed in' do
    it 'is signed out on its next request and told why' do
      sign_in_as(user)
      get edit_registration_path
      expect(response).to have_http_status(:success)

      user.suspend!
      get edit_registration_path

      expect(response).to redirect_to(new_session_path)
      expect(session[:user_id]).to be_nil
      follow_redirect!
      expect(response.body).to include('This account has been suspended')
    end

    it "can't keep using the admin area after being suspended" do
      admin = create(:user, :admin)
      sign_in_as(admin)
      admin.suspend!

      get admin_users_path

      expect(response).to redirect_to(new_session_path)
    end

    it 'does not look signed in on public pages either' do
      sign_in_as(user)
      user.suspend!

      get root_path

      expect(Nokogiri::HTML(response.body).css("a[href='#{new_session_path}']")).not_to be_empty
    end
  end

  describe 'recording sign-ins' do
    it 'counts each successful sign-in and remembers the latest' do
      freeze_time do
        2.times do
          post session_path, params: { user: { email: user.email, password: 'password123' } }
          delete session_path
        end

        expect(user.reload.sign_in_count).to eq(2)
        expect(user.last_sign_in_at).to eq(Time.current)
      end
    end

    it "doesn't count a failed sign-in" do
      post session_path, params: { user: { email: user.email, password: 'nope' } }
      expect(user.reload.sign_in_count).to eq(0)
      expect(user.last_sign_in_at).to be_nil
    end

    it 'counts a provider sign-in' do
      create(:identity, user: user, provider: 'developer', uuid: 'dev-count')
      mock_provider_auth(uid: 'dev-count', email: user.email)

      post '/auth/developer'
      follow_redirect!

      expect(user.reload.sign_in_count).to eq(1)
    end
  end
end
