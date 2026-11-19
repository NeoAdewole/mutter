require 'rails_helper'

# The site settings that change what visitors see: maintenance mode, paused
# sign-ups, the announcement banner and the home page streams.
RSpec.describe 'Site settings in effect', type: :request do
  def banner
    html.at_css('[data-announcement]')
  end

  describe 'maintenance mode' do
    before { SiteSetting.update_values('maintenance_mode' => 'true') }

    it 'shows visitors a 503 maintenance page instead of the site, and asks search engines to come back later' do
      get root_path

      expect(response).to have_http_status(:service_unavailable)
      expect(response.headers['Retry-After']).to eq('3600')
      expect(html.at_css('[data-maintenance-message]').text).to include('down for maintenance')
      expect(html.css('nav')).to be_empty
    end

    it 'shows the admin-written message when there is one' do
      SiteSetting.update_values('maintenance_message' => 'Back at 6pm UTC')

      get about_path

      expect(html.at_css('[data-maintenance-message]').text).to include('Back at 6pm UTC')
    end

    it 'applies to every public page, including CMS pages' do
      create(:page, :published, section: 'content', title: 'Guides', slug: 'guides')

      [root_path, about_path, '/content', '/content/guides', new_registration_path, live_chat_path].each do |path|
        get path
        expect(response).to have_http_status(:service_unavailable), "#{path} should be in maintenance"
      end
    end

    it 'applies to signed-in members too' do
      SiteSetting.update_values('maintenance_mode' => 'false')
      sign_in_as(create(:user))
      SiteSetting.update_values('maintenance_mode' => 'true')

      get root_path

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'still lets people reach the sign-in screens so an admin can get in' do
      get new_session_path
      expect(response).to have_http_status(:success)

      get new_password_reset_path
      expect(response).to have_http_status(:success)
    end

    it 'lets an admin sign in, and use the whole site, to switch it off again' do
      admin = create(:user, :admin)

      post session_path, params: { user: { email: admin.email, password: 'password123' } }
      expect(session[:user_id]).to eq(admin.id)

      get root_path
      expect(response).to have_http_status(:success)
      get admin_settings_path
      expect(response).to have_http_status(:success)

      patch admin_settings_path, params: { settings: { maintenance_mode: '0' } }
      delete session_path
      get root_path
      expect(response).to have_http_status(:success)
    end

    it 'does not let a regular member into the admin area just because the sign-in page works' do
      member = create(:user)
      post session_path, params: { user: { email: member.email, password: 'password123' } }

      get admin_root_path

      expect(response).to have_http_status(:service_unavailable)
    end

    it 'leaves the health check alone so deploys and monitors still work' do
      get rails_health_check_path
      expect(response).to have_http_status(:success)
    end

    it 'goes away as soon as it is switched off' do
      SiteSetting.update_values('maintenance_mode' => 'false')
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'paused sign-ups' do
    before { SiteSetting.update_values('signups_enabled' => 'false') }

    it 'sends the sign-up page to the login page with an explanation' do
      get new_registration_path

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include('sign-ups are paused')
    end

    it "doesn't create an account from the sign-up form" do
      expect do
        post registration_path, params: { user: { email: 'new@example.com', firstname: 'N', lastname: 'U', username: 'newbie',
                                                  password: 'password123', password_confirmation: 'password123' } }
      end.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
    end

    it "doesn't create an account from a provider sign-in either, nor leave a half-made identity behind" do
      mock_provider_auth(uid: 'someone-new', email: 'someone-new@example.com')

      expect do
        post '/auth/developer'
        follow_redirect!
      end.to change(User, :count).by(0).and change(Identity, :count).by(0)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include('sign-ups are paused')
      expect(session[:user_id]).to be_nil
    end

    it 'still lets existing members sign in with their provider' do
      user = create(:user)
      create(:identity, user: user, provider: 'developer', uuid: 'dev-member')
      mock_provider_auth(uid: 'dev-member', email: user.email)

      post '/auth/developer'
      follow_redirect!

      expect(session[:user_id]).to eq(user.id)
    end

    it 'still lets a member whose provider email matches their account sign in with a new provider' do
      user = create(:user, email: 'match@example.com')
      mock_provider_auth(uid: 'dev-first-time', email: 'match@example.com')

      post '/auth/developer'
      follow_redirect!

      expect(session[:user_id]).to eq(user.id)
    end

    it 'still lets existing members sign in with a password' do
      user = create(:user)
      post session_path, params: { user: { email: user.email, password: 'password123' } }
      expect(session[:user_id]).to eq(user.id)
    end

    it 'lets sign-ups resume when switched back on' do
      SiteSetting.update_values('signups_enabled' => 'true')
      get new_registration_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'the announcement banner' do
    it 'is not shown by default' do
      get root_path
      expect(banner).to be_nil
    end

    it 'is shown on every page to every visitor, in the chosen style' do
      SiteSetting.update_values('announcement_enabled' => 'true', 'announcement_message' => 'Server move tonight', 'announcement_level' => 'warning')

      [root_path, about_path, new_session_path].each do |path|
        get path
        expect(banner.text.strip).to eq('Server move tonight')
        expect(banner['class']).to include('alert-warning')
        expect(banner['role']).to eq('status')
      end
    end

    it 'is shown inside the admin area and to signed-in members' do
      SiteSetting.update_values('announcement_enabled' => 'true', 'announcement_message' => 'Hello everyone')
      sign_in_as(create(:user, :admin))

      get admin_root_path
      expect(banner.text).to include('Hello everyone')
    end

    it 'is hidden when switched off, even if a message is saved' do
      SiteSetting.update_values('announcement_enabled' => 'false', 'announcement_message' => 'Hidden')
      get root_path
      expect(banner).to be_nil
    end

    it 'is hidden when switched on without a message' do
      SiteSetting.update_values('announcement_enabled' => 'true')
      get root_path
      expect(banner).to be_nil
    end

    it 'shows the message as plain text, never as HTML' do
      SiteSetting.update_values('announcement_enabled' => 'true', 'announcement_message' => '<script>alert(1)</script><b>bold</b>')

      get root_path

      expect(response.body).not_to include('<script>alert(1)</script>')
      expect(banner.at_css('script, b')).to be_nil
      expect(banner.text).to include('<script>alert(1)</script>')
    end

    it 'falls back to the info style for a style it does not know' do
      SiteSetting.create!(key: 'announcement_enabled', value: 'true')
      SiteSetting.create!(key: 'announcement_message', value: 'Hi')
      SiteSetting.create!(key: 'announcement_level', value: 'rainbow')

      get root_path

      expect(banner['class']).to include('alert-info')
    end
  end

  describe 'live streams on the home page' do
    let(:live) { [Twitch::Stream.new(login: 'alice', name: 'Alice', title: 'T', game: 'G', viewers: 5)] }

    it 'asks for at most the configured number of streams' do
      SiteSetting.update_values('homepage_streams_limit' => '2')
      expect(Twitch::LiveStreams).to receive(:current).with(limit: 2).and_return(live)

      get root_path

      expect(html.css('[data-carousel-target="slide"]').first.text).to include('Alice')
    end

    it 'uses the default of five when nothing has been changed' do
      expect(Twitch::LiveStreams).to receive(:current).with(limit: 5).and_return([])
      get root_path
    end

    it "doesn't ask Twitch at all, and shows no live slides, when switched off" do
      SiteSetting.update_values('homepage_streams_enabled' => 'false')
      expect(Twitch::LiveStreams).not_to receive(:current)

      get root_path

      expect(response).to have_http_status(:success)
      expect(html.css('[data-carousel-target="slide"] iframe')).to be_empty
    end
  end
end
