require 'rails_helper'

RSpec.describe 'Password resets', type: :request do
  describe 'POST /password_reset' do
    it 'sends a reset email for a known address and does not reveal whether the account exists' do
      user = create(:user)

      expect do
        post password_reset_path, params: { email: user.email }
      end.to change { ActionMailer::Base.deliveries.count }.by(1)

      expect(flash[:notice]).to eq('Check your email to reset your password.')
    end

    it 'shows the same message for an unknown address, without sending an email' do
      expect do
        post password_reset_path, params: { email: 'nobody@example.com' }
      end.not_to(change { ActionMailer::Base.deliveries.count })

      expect(flash[:notice]).to eq('Check your email to reset your password.')
    end
  end

  describe 'PATCH /password_reset (completing a reset)' do
    it 'sets a new password and marks the account as having a real password, even for an OAuth-only account' do
      user = create(:user, password_set: false)
      token = user.signed_id(purpose: 'password_reset', expires_in: 15.minutes)

      patch password_reset_path(token: token), params: {
        user: { password: 'brandnewpassword', password_confirmation: 'brandnewpassword' }
      }

      expect(response).to redirect_to(new_session_path)
      user.reload
      expect(user.authenticate('brandnewpassword')).to be_truthy
      expect(user.password_set).to be true
    end
  end
end
