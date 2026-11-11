require 'rails_helper'

RSpec.describe 'Google sign-in vs. connecting YouTube', type: :request do
  let(:channels_url) { 'https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true' }
  let(:user) { create(:user) }

  def sign_in
    post session_path, params: { user: { email: user.email, password: 'password123' } }
  end

  def stub_channel(handle: '@MassMutter')
    snippet = { title: 'Mass Mutter' }
    snippet[:customUrl] = handle if handle
    stub_request(:get, channels_url).with(headers: { 'Authorization' => 'Bearer mock_token' })
                                    .to_return(status: 200, headers: { 'Content-Type' => 'application/json' },
                                               body: { items: [{ id: 'UC123', snippet: snippet }] }.to_json)
  end

  def connect_youtube(uid: 'g-uid-1')
    mock_provider_auth(provider: 'youtube', uid: uid, nickname: nil, email: 'g@example.com', name: 'G Person')
    post '/auth/youtube?connect=true'
    follow_redirect! # -> /auth/youtube/callback
  end

  describe 'connecting YouTube from the profile page' do
    before { sign_in }

    it "links the person's channel handle (which Google sign-in alone never provides) to their account" do
      stub_channel

      expect { connect_youtube }.to change { user.identities.where(provider: 'youtube').count }.by(1)

      identity = user.identities.find_by!(provider: 'youtube')
      expect(identity.username).to eq('MassMutter')
      expect(session[:user_id]).to eq(user.id)
      expect(flash[:notice]).to include('YouTube')
    end

    it 'still connects when YouTube cannot be reached, just without a channel name yet' do
      stub_request(:get, channels_url).to_return(status: 500, body: '')

      connect_youtube

      expect(user.identities.find_by!(provider: 'youtube').username).to be_nil
      expect(flash[:notice]).to include('YouTube')
    end

    it 'is a separate connection from signing in with Google, even for the same Google account' do
      stub_channel
      create(:identity, user: user, provider: 'google_oauth2', uuid: 'g-uid-1', username: nil)

      expect { connect_youtube(uid: 'g-uid-1') }.to change(Identity, :count).by(1)

      expect(user.identities.pluck(:provider)).to contain_exactly('google_oauth2', 'youtube')
    end

    it 'fills in the handle on an already-connected YouTube identity when reconnecting' do
      stub_channel(handle: '@renamed')
      identity = create(:identity, user: user, provider: 'youtube', uuid: 'g-uid-1', username: 'OldName')

      connect_youtube(uid: 'g-uid-1')

      expect(identity.reload.username).to eq('renamed')
      expect(flash[:notice]).to match(/already connected/i)
    end
  end

  describe 'YouTube is only for connecting, never for signing in or signing up' do
    it 'refuses to create an account from a YouTube authorization' do
      mock_provider_auth(provider: 'youtube', uid: 'g-uid-9', email: 'new@example.com', nickname: nil)

      expect { get '/auth/youtube/callback' }.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to match(/youtube/i).and match(/profile/i)
      expect(session[:user_id]).to be_nil
    end

    it 'does not sign an existing YouTube-connected user in' do
      create(:identity, user: user, provider: 'youtube', uuid: 'g-uid-9')
      mock_provider_auth(provider: 'youtube', uid: 'g-uid-9', email: user.email, nickname: nil)

      get '/auth/youtube/callback'

      expect(session[:user_id]).to be_nil
    end

    it 'is not offered on the sign-in or sign-up pages, while Google still is' do
      [new_session_path, new_registration_path].each do |path|
        get path
        expect(response.body).not_to include('/auth/youtube')
        expect(response.body).to include('/auth/google_oauth2')
      end
    end
  end

  describe 'the profile page' do
    before { sign_in }

    it 'offers Connect YouTube separately from Connect Google, and says what it asks for' do
      get edit_registration_path

      page = Nokogiri::HTML(response.body)
      expect(page.at_css('form[action="/auth/youtube?connect=true"]')).to be_present
      expect(page.at_css('form[action="/auth/google_oauth2?connect=true"]')).to be_present
      expect(response.body).to match(/YouTube.*read-only/im)
    end

    it 'shows each connected service with its own handle and a link to it, even when the handles differ' do
      create(:identity, user: user, provider: 'twitch', uuid: 't-1', username: 'BevyBabble')
      create(:identity, user: user, provider: 'youtube', uuid: 'y-1', username: 'MassMutter')
      create(:identity, user: user, provider: 'github', uuid: 'gh-1', username: nil)

      get edit_registration_path

      page = Nokogiri::HTML(response.body)
      items = page.css('li').select { |li| li.text.include?('connected') }.to_h { |li| [li.text[/Twitch|YouTube|GitHub/], li] }

      expect(items['Twitch'].at_css('a[href="https://www.twitch.tv/BevyBabble"]').text).to include('BevyBabble')
      expect(items['YouTube'].at_css('a[href="https://www.youtube.com/@MassMutter"]').text).to include('MassMutter')
      expect(items['YouTube'].text).not_to include('BevyBabble')
      expect(items['GitHub'].css('a').map { |a| a['href'] }).to all(include('/identities/'))
    end

    it 'names providers properly instead of showing internal keys' do
      create(:identity, user: user, provider: 'twitter2', uuid: 'tw2-1', username: 'x_user')
      create(:identity, user: user, provider: 'google_oauth2', uuid: 'g-1')

      get edit_registration_path

      expect(response.body).not_to include('Twitter2')
      expect(response.body).not_to include('Google_oauth2')
      expect(response.body).to include('Twitter').and include('Google')
    end
  end
end
