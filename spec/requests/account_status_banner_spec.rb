require 'rails_helper'

RSpec.describe 'Account status banner', type: :request do
  it 'reminds a signed-in user with no real password to add one, on any page' do
    user = create(:user, password: 'generated-secret', password_confirmation: 'generated-secret', password_set: false)
    post session_path, params: { user: { email: user.email, password: 'generated-secret' } }

    get about_path

    expect(response.body).to match(/add a password/i)
    expect(response.body).to include(edit_password_path)
  end

  it 'shows no such reminder for a user who already has a real password' do
    user = create(:user, password: 'password123', password_confirmation: 'password123', password_set: true)
    post session_path, params: { user: { email: user.email, password: 'password123' } }

    get about_path

    expect(response.body).not_to match(/add a password/i)
  end

  it 'shows no reminder to a signed-out visitor' do
    get about_path
    expect(response.body).not_to match(/add a password/i)
  end
end
