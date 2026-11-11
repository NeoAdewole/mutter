require 'rails_helper'

RSpec.describe 'Home page stream setting', type: :request do
  let(:user) { create(:user) }

  before { post session_path, params: { user: { email: user.email, password: 'password123' } } }

  def checkbox
    get edit_registration_path
    Nokogiri::HTML(response.body).at_css('input[type="checkbox"][name="user[show_stream_on_homepage]"]')
  end

  it 'is on by default, and offered on the profile page with an explanation' do
    expect(checkbox).to be_present
    expect(checkbox['checked']).to be_present
    expect(response.body).to match(/home ?page/i).and match(/live/i)
  end

  it 'can be turned off from the profile page' do
    patch registration_path, params: { user: { show_stream_on_homepage: '0' } }

    expect(response).to redirect_to(root_path)
    expect(user.reload.show_stream_on_homepage).to be false
    expect(checkbox['checked']).to be_nil
  end

  it 'can be turned back on' do
    user.update!(show_stream_on_homepage: false)

    patch registration_path, params: { user: { show_stream_on_homepage: '1' } }

    expect(user.reload.show_stream_on_homepage).to be true
    expect(checkbox['checked']).to be_present
  end

  it 'leaves the rest of the profile alone when only the setting is submitted' do
    original = user.slice(:email, :username, :firstname, :lastname)

    patch registration_path, params: { user: { show_stream_on_homepage: '0' } }

    expect(user.reload.slice(:email, :username, :firstname, :lastname)).to eq(original)
  end
end
