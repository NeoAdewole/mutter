require 'rails_helper'

RSpec.describe 'Passwords', type: :request do
  describe 'GET /password/edit' do
    it 'redirects unauthenticated visitors to log in' do
      get edit_password_path
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'a user who already has a real password (password_set: true)' do
    let(:user) { create(:user, password: 'password123', password_confirmation: 'password123', password_set: true) }

    before { sign_in(user, 'password123') }

    it 'shows a "change password" form that asks for the current password' do
      get edit_password_path
      expect(response.body).to match(/change.*password/i)
      expect(response.body).to include('Current Password')
    end

    it 'requires the correct current password to change it' do
      patch password_path, params: {
        user: { password_challenge: 'password123', password: 'newpassword1', password_confirmation: 'newpassword1' }
      }
      expect(response).to redirect_to(edit_password_path)
      expect(flash[:notice]).to eq('Your password has been updated successfully.')
      expect(user.reload.authenticate('newpassword1')).to be_truthy
      expect(user.password_set).to be true
    end

    it 'rejects the wrong current password and leaves the password unchanged' do
      patch password_path, params: {
        user: { password_challenge: 'wrongpassword', password: 'newpassword1', password_confirmation: 'newpassword1' }
      }
      expect(response).to have_http_status(422)
      expect(user.reload.authenticate('password123')).to be_truthy
    end
  end

  describe 'a user who has no real password yet (password_set: false, e.g. OAuth sign-up)' do
    # password_set is independent of whether a password_digest exists (every
    # user has one, per has_secure_password) -- it tracks whether the user
    # themself knows/chose it. Here we give the test a known password so it
    # can log in, while marking the account as not having set one for real,
    # the same state an OAuth sign-up leaves behind.
    let(:user) { create(:user, password: 'generated-secret', password_confirmation: 'generated-secret', password_set: false) }

    before { sign_in(user, 'generated-secret') }

    it 'shows an "add a password" form with no current-password field' do
      get edit_password_path
      expect(response.body).to match(/add.*password/i)
      expect(response.body).not_to include('Current Password')
    end

    it 'lets them add a password without knowing the old (generated) one' do
      patch password_path, params: {
        user: { password: 'mynewpassword', password_confirmation: 'mynewpassword' }
      }
      expect(response).to redirect_to(edit_password_path)
      expect(flash[:notice]).to eq('Your password has been added. You can now log in with your email and this password too.')
      expect(user.reload.password_set).to be true
      expect(user.authenticate('mynewpassword')).to be_truthy
    end

    it 'still enforces the normal password validations' do
      patch password_path, params: {
        user: { password: 'short', password_confirmation: 'short' }
      }
      expect(response).to have_http_status(422)
      expect(user.reload.password_set).to be false
    end
  end

  def sign_in(user, password)
    post session_path, params: { user: { email: user.email, password: password } }
  end
end
