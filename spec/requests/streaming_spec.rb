require 'rails_helper'

RSpec.describe 'Streaming page', type: :request do
  let(:user) { create(:user) }

  def sign_in
    post session_path, params: { user: { email: user.email, password: 'password123' } }
  end

  def page
    Nokogiri::HTML(response.body)
  end

  it 'requires being signed in' do
    get streaming_path
    expect(response).to redirect_to(new_session_path)
  end

  describe 'with a connected Twitch account that has a stored channel name' do
    before do
      create(:identity, user: user, provider: 'twitch', uuid: 'tw-1', username: 'mychannel')
      sign_in
      get streaming_path
    end

    it 'renders one chat feed wired to the Stimulus controller, configured with the connected channels' do
      chat = page.at_css('[data-controller="chat"]')
      expect(chat).to be_present

      channels = JSON.parse(chat['data-chat-channels-value'])
      expect(channels).to eq([{ 'provider' => 'twitch', 'channel' => 'mychannel', 'label' => 'Twitch: mychannel' }])
      expect(chat.css('[data-chat-target="feed"][role="log"]').size).to eq(1)
    end

    it 'shows a connection status chip for each channel, starting as connecting' do
      statuses = page.css('[data-chat-target="status"]')
      expect(statuses.size).to eq(1)
      expect(statuses.first['data-key']).to eq('twitch:mychannel')
      expect(statuses.first['data-state']).to eq('connecting')
    end

    it 'does not show the connect prompt' do
      expect(response.body).not_to include('/auth/twitch?connect=true')
    end
  end

  describe 'with no chat-capable connection' do
    before do
      create(:identity, user: user, provider: 'github', uuid: 'gh-1', username: 'coder')
      sign_in
      get streaming_path
    end

    it 'explains there is nothing to show yet and offers to connect Twitch, returning here afterwards' do
      expect(page.at_css('[data-controller="chat"]')).to be_nil
      expect(response.body).to match(/connect/i)
      expect(page.at_css('form[action="/auth/twitch?connect=true&return=streaming"]')).to be_present
    end

    it 'ignores providers whose chat we cannot read' do
      expect(response.body).not_to include('coder')
    end
  end

  describe 'with Twitch connected before channel names were stored' do
    before do
      create(:identity, user: user, provider: 'twitch', uuid: 'tw-old', username: nil)
      sign_in
      get streaming_path
    end

    it 'asks the user to reconnect once so the channel can be linked, rather than showing an empty chat' do
      expect(page.at_css('[data-controller="chat"]')).to be_nil
      expect(response.body).to match(/reconnect/i)
      expect(page.at_css('form[action="/auth/twitch?connect=true&return=streaming"]')).to be_present
    end
  end

  it 'shows a single reconnect prompt per provider even when several accounts of it lack a channel name' do
    create(:identity, user: user, provider: 'twitch', uuid: 'tw-old-1', username: nil)
    create(:identity, user: user, provider: 'twitch', uuid: 'tw-old-2', username: nil)
    sign_in
    get streaming_path

    expect(page.css('form[action="/auth/twitch?connect=true&return=streaming"]').size).to eq(1)
  end

  it 'is linked from the navigation' do
    sign_in
    get root_path
    expect(page.css('a[href="/streaming"]')).not_to be_empty
  end
end
