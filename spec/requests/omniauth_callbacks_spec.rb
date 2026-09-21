require 'rails_helper'

RSpec.describe 'OmniAuth failures', type: :request do
  it 'sends a signed-out visitor back to log in with a clear, provider-agnostic error' do
    mock_provider_failure('developer', :invalid_credentials)

    get '/auth/developer/callback'
    follow_redirect! # OmniAuth's fail! redirects to /auth/failure first

    expect(response).to redirect_to(new_session_path)
    expect(flash[:alert]).to match(/authentic/i)
  end

  it 'sends an already signed-in user back to their profile instead of logging them out' do
    user = create(:user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    mock_provider_failure('developer', :invalid_credentials)
    get '/auth/developer/callback'
    follow_redirect!

    expect(response).to redirect_to(edit_registration_path)
    expect(session[:user_id]).to eq(user.id)
  end
end
