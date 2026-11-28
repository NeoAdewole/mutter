require 'rails_helper'

RSpec.describe AuthProviders do
  # The test environment gives every provider throwaway credentials through ENV (see rails_helper),
  # so a lookup spec first clears the variables it is about.
  def without_env(*names)
    allow(ENV).to receive(:fetch).and_call_original
    names.each { |name| allow(ENV).to receive(:fetch).with(name, nil).and_return(nil) }
  end

  let(:github) { described_class.find('github') }
  let(:credentials) { Rails.application.credentials }

  it 'lists every service, in the order their buttons appear' do
    expect(described_class.all.map(&:key)).to eq(%w[github twitter2 google_oauth2 twitch discord youtube])
    expect(described_class.all.map(&:label)).to eq(%w[GitHub Twitter Google Twitch Discord YouTube])
  end

  it 'knows the address each service must send people back to' do
    expect(described_class.all.to_h { |provider| [provider.key, provider.callback_path] }).to eq(
      'github' => '/auth/github/callback', 'twitter2' => '/auth/twitter2/callback',
      'google_oauth2' => '/auth/google_oauth2/callback', 'twitch' => '/auth/twitch/callback',
      'discord' => '/auth/discord/callback', 'youtube' => '/auth/youtube/callback'
    )
  end

  it 'finds a provider by key, and says nothing for one it does not know' do
    expect(described_class.find('twitch').key).to eq('twitch')
    expect(described_class.find(:twitch).key).to eq('twitch')
    expect(described_class.find('myspace')).to be_nil
    expect(described_class.configured?('myspace')).to be false
  end

  describe 'where credentials come from' do
    before { without_env('GITHUB_CLIENT_ID', 'GITHUB_CLIENT_SECRET') }

    it 'prefers an environment variable, then nested credentials, then flat ones' do
      allow(credentials).to receive(:dig).and_call_original
      allow(credentials).to receive(:[]).and_call_original
      allow(credentials).to receive(:dig).with(:github, :client_id).and_return('nested-id')
      allow(credentials).to receive(:[]).with(:github_client_id).and_return('flat-id')
      expect(github.client_id).to eq('nested-id')

      allow(credentials).to receive(:dig).with(:github, :client_id).and_return(nil)
      expect(github.client_id).to eq('flat-id')

      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('env-id')
      expect(github.client_id).to eq('env-id')
    end

    it 'treats a blank value as missing' do
      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('')
      allow(credentials).to receive(:dig).and_call_original
      allow(credentials).to receive(:dig).with(:github, :client_id).and_return('  ')

      expect(github.client_id).to be_nil
    end

    it 'is configured only with both an id and a secret' do
      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_ID', nil).and_return('an-id')
      expect(github.configured?).to be false

      allow(ENV).to receive(:fetch).with('GITHUB_CLIENT_SECRET', nil).and_return('a-secret')
      expect(github.configured?).to be true
      expect(described_class.configured?('github')).to be true
    end
  end

  it 'gives YouTube the same Google client as signing in with Google' do
    expect(described_class.find('youtube').group).to eq(described_class.find('google_oauth2').group)
    expect(described_class.find('youtube').client_id).to eq(described_class.find('google_oauth2').client_id)
  end

  it 'asks GitHub for the email scope, so a private email address still comes through' do
    expect(github.options).to include(scope: 'user:email')
  end

  it 'only ever offers connecting YouTube, never signing in with it' do
    expect(described_class.all.select(&:connect_only?).map(&:key)).to eq(['youtube'])
  end

  it 'keeps every credential out of what it prints' do
    expect(described_class.all.map(&:inspect).join).not_to include('test-github-secret')
    expect(described_class.all.map(&:to_s).join).not_to include('test-github-secret')
  end
end
