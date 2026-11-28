require 'rails_helper'

# Every service people can sign in with, driven the way a real person does it: the button posts to
# /auth/:provider, the service sends them back to its callback. The hashes below have the shape each
# OmniAuth strategy really returns (read from the strategy gems), including what each one leaves out:
# Google sends no handle, Twitter never sends an email, Discord's "name" is the username.
# YouTube is connect-only and has its own spec (youtube_connection_spec.rb).
RSpec.describe 'Signing in with each provider', type: :request do
  shapes = {
    'github' => { uid: '583231', handle: 'octocat', username: 'octocat', email: 'octocat@github.example',
                  info: { nickname: 'octocat', name: 'The Octocat', email: 'octocat@github.example' } },
    'twitter2' => { uid: '2244994945', handle: 'xdev', username: 'xdev', email: nil,
                    info: { nickname: 'xdev', name: 'X Dev', email: nil } },
    'google_oauth2' => { uid: '110169484474386276334', handle: nil, username: 'Ada Lovelace', email: 'ada@gmail.example',
                         info: { name: 'Ada Lovelace', email: 'ada@gmail.example', first_name: 'Ada', last_name: 'Lovelace' } },
    'twitch' => { uid: '141981764', handle: 'twitchdev', username: 'twitchdev', email: 'dev@twitch.example',
                  info: { nickname: 'twitchdev', name: 'TwitchDev', email: 'dev@twitch.example' } },
    'discord' => { uid: '80351110224678912', handle: nil, username: 'Nelly', email: 'nelly@discord.example',
                   info: { name: 'Nelly', email: 'nelly@discord.example' } }
  }

  def mock_provider(provider, shape)
    OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
      provider: provider, uid: shape[:uid], info: OmniAuth::AuthHash::InfoHash.new(shape[:info]),
      credentials: OmniAuth::AuthHash.new(token: 'a-token')
    )
  end

  def press_button(provider, query = '')
    post "/auth/#{provider}#{query}"
    follow_redirect! # -> /auth/:provider/callback
  end

  shapes.each do |provider, shape|
    describe Identity.label_for(provider) do
      before { mock_provider(provider, shape) }

      it 'is offered on the sign-in, sign-up and profile pages' do
        get new_session_path
        expect(html.at_css("form[action='/auth/#{provider}']")).to be_present

        get new_registration_path
        expect(html.at_css("form[action='/auth/#{provider}']")).to be_present
      end

      it 'creates an account on first sign-in, with the handle the service gave and a unique Mutter username' do
        expect { press_button(provider) }.to change(User, :count).by(1).and change(Identity, :count).by(1)

        user = User.last
        identity = user.identities.sole
        expect(session[:user_id]).to eq(user.id)
        expect(identity).to have_attributes(provider: provider, uuid: shape[:uid], username: shape[:handle])
        expect(user.username).to eq(shape[:username])
        expect(user.password_set).to be false
      end

      it 'uses the email the service gave, or asks for one when it gave none' do
        press_button(provider)

        user = User.last
        if shape[:email]
          expect(user.email).to eq(shape[:email])
          expect(response).to redirect_to(about_path)
          expect(flash[:notice]).to include('Welcome').and include(Identity.label_for(provider))
        else
          expect(user).to be_placeholder_email
          expect(response).to redirect_to(edit_registration_path)
          expect(flash[:notice]).to include('add an email address')
        end
      end

      it 'signs the same person back in next time, without a second account' do
        press_button(provider)
        User.last.update!(email: 'given-by-hand@example.com') if shape[:email].nil? # Twitter sends none; they add one once
        delete session_path

        expect { press_button(provider) }.not_to change(User, :count)

        expect(session[:user_id]).to eq(Identity.find_by!(provider: provider, uuid: shape[:uid]).user_id)
        expect(flash[:notice]).to include('Welcome back')
      end

      it 'connects to a signed-in account instead of creating one, and can be disconnected' do
        user = create(:user)
        sign_in_as(user)

        expect { press_button(provider, '?connect=true') }.to change { user.identities.where(provider: provider).count }.by(1)

        expect(User.count).to eq(1)
        expect(session[:user_id]).to eq(user.id)
        expect(flash[:notice]).to include("Connected your #{Identity.label_for(provider)} account")

        delete identity_path(user.identities.find_by!(provider: provider))
        expect(user.identities.where(provider: provider)).to be_empty
      end

      it 'refuses someone else\'s connected account, naming the service' do
        create(:identity, provider: provider, uuid: shape[:uid])
        sign_in_as(create(:user))

        press_button(provider, '?connect=true')

        expect(flash[:alert]).to include("That #{Identity.label_for(provider)} account is already connected to a different Mutter account")
      end

      it 'explains a refusal rather than failing, and goes back to where the person was' do
        OmniAuth.config.mock_auth[provider.to_sym] = :access_denied

        get "/auth/#{provider}/callback"
        follow_redirect! # OmniAuth's fail! redirects to /auth/failure first

        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq('Authentication failed: Access denied.')
      end

      it 'does not sign anyone up while sign-ups are paused, but still lets existing members in' do
        SiteSetting.update_values('signups_enabled' => 'false')

        expect { press_button(provider) }.not_to change(User, :count)
        expect(response).to redirect_to(new_session_path)

        create(:identity, provider: provider, uuid: shape[:uid])
        press_button(provider)
        expect(flash[:notice]).to include('Welcome back')
      end
    end
  end

  describe 'disconnecting a connected account from the profile page' do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it 'offers a button for each connected account' do
      identity = create(:identity, user: user, provider: 'github', username: 'octocat')

      get edit_registration_path

      expect(html.at_css("form[action='#{identity_path(identity)}'] button, form[action='#{identity_path(identity)}'] input[type=submit]")).to be_present
    end

    it 'removes the account and says so' do
      identity = create(:identity, user: user, provider: 'twitch')

      expect { delete identity_path(identity) }.to change(Identity, :count).by(-1)

      expect(response).to redirect_to(edit_registration_path)
      expect(flash[:notice]).to eq('Disconnected your Twitch account.')
    end

    it 'never removes someone else\'s account' do
      other = create(:identity, provider: 'github')

      expect { delete identity_path(other) }.not_to change(Identity, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'keeps the last way in when there is no password, and explains how to fix that' do
      passwordless = create(:user, password_set: false)
      sign_in_as(passwordless)
      only_way = create(:identity, user: passwordless, provider: 'github')

      expect { delete identity_path(only_way) }.not_to change(Identity, :count)

      expect(flash[:alert]).to include('GitHub is the only way you can sign in')
    end

    it 'lets a person with no password disconnect an account when another way in remains' do
      passwordless = create(:user, password_set: false)
      sign_in_as(passwordless)
      create(:identity, user: passwordless, provider: 'twitch')
      github = create(:identity, user: passwordless, provider: 'github')

      expect { delete identity_path(github) }.to change(Identity, :count).by(-1)
    end

    it 'always lets YouTube go, since it was never a way in' do
      passwordless = create(:user, password_set: false)
      sign_in_as(passwordless)
      create(:identity, user: passwordless, provider: 'github')
      youtube = create(:identity, user: passwordless, provider: 'youtube')

      expect { delete identity_path(youtube) }.to change(Identity, :count).by(-1)
    end

    it 'needs a signed-in person' do
      identity = create(:identity, user: user)
      delete session_path

      expect { delete identity_path(identity) }.not_to change(Identity, :count)

      expect(response).to redirect_to(new_session_path)
    end
  end

  describe 'a provider that has not been set up' do
    it 'sends the visitor back with an explanation instead of an error page' do
      post '/auth/myspace'

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("That sign-in method isn't available on this site right now.")
    end

    it 'returns signed-in people to their profile' do
      sign_in_as(create(:user))

      get '/auth/unknown_service'

      expect(response).to redirect_to(edit_registration_path)
    end

    it 'has nothing to do for a callback that nothing started' do
      get '/auth/myspace/callback'

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to include('could not be completed')
    end

    it 'is not offered on the pages, and stays hidden from the sign-in list' do
      github = AuthProviders.find('github')
      allow(AuthProviders).to receive(:credential).and_call_original
      allow(AuthProviders).to receive(:credential).with(github, anything).and_return(nil)

      get new_session_path

      expect(html.at_css("form[action='/auth/github']")).to be_nil
      expect(html.at_css("form[action='/auth/twitch']")).to be_present
    end
  end
end
