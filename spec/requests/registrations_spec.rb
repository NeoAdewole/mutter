require 'rails_helper'

RSpec.describe 'Registrations (sign up)', type: :request do
  describe 'GET /registration/new' do
    it 'renders the sign-up form with every configured identity provider offered' do
      get new_registration_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('/auth/github')
      expect(response.body).to include('/auth/google_oauth2')
      expect(response.body).to include('/auth/discord')
      expect(response.body).to include('/auth/twitch')
      expect(response.body).to include('/auth/twitter2')
      expect(response.body).to include('/auth/developer')
      expect(response.body).not_to match(/Sign In With/i), 'sign-up page should say "Sign Up", not "Sign In"'
    end
  end

  describe 'POST /registration (password sign-up)' do
    it 'creates the account, signs the user in, sends a welcome email, and flags a real password as set' do
      expect do
        post registration_path, params: {
          user: {
            email: 'newuser@example.com', firstname: 'New', lastname: 'User',
            username: 'newuser_reg', password: 'securepass', password_confirmation: 'securepass'
          }
        }
      end.to change(User, :count).by(1).and change { ActionMailer::Base.deliveries.count }.by(1)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Account created successfully.')

      user = User.find_by(email: 'newuser@example.com')
      expect(session[:user_id]).to eq(user.id)
      expect(user.password_set).to be true
    end

    it 're-renders with errors on a duplicate email' do
      existing = create(:user)

      expect do
        post registration_path, params: {
          user: {
            email: existing.email, firstname: 'Dup', lastname: 'User',
            username: 'dup_user_unique', password: 'pass123', password_confirmation: 'pass123'
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include('Email')
    end

    it 'rejects a username that only differs by case from an existing one' do
      create(:user, username: 'BevyBabble')

      expect do
        post registration_path, params: {
          user: {
            email: 'someone.else@example.com', firstname: 'Some', lastname: 'One',
            username: 'bevybabble', password: 'pass123', password_confirmation: 'pass123'
          }
        }
      end.not_to change(User, :count)

      expect(response).to have_http_status(422)
      expect(response.body).to include('Username')
    end

    it 're-renders with errors when passwords do not match' do
      post registration_path, params: {
        user: {
          email: 'mismatch@example.com', firstname: 'Mis', lastname: 'Match',
          username: 'mismatch_user', password: 'pass123', password_confirmation: 'different'
        }
      }
      expect(response).to have_http_status(422)
    end
  end
end
