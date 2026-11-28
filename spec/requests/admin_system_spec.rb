require 'rails_helper'

RSpec.describe 'Admin system page', type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in_as(admin) }

  it 'shows the environment, database state and record counts' do
    create(:user)

    get admin_system_path

    expect(response).to have_http_status(:success)
    app = html.at_css('[data-app-info]').text
    expect(app).to include(Rails.version).and include(RUBY_VERSION).and include('test')
    database = html.at_css('[data-database]').text
    expect(database).to include('Connected').and include('PostgreSQL').and include('Up to date')
    records = html.at_css('[data-records]').text
    expect(records).to match(/Users\s*2/)
  end

  it 'flags pending migrations' do
    allow_any_instance_of(ActiveRecord::MigrationContext).to receive(:needs_migration?).and_return(true)

    get admin_system_path

    expect(html.at_css('[data-database]').text).to include('Pending')
  end

  it 'says whether each sign-in provider has credentials, and never prints them' do
    values = { %w[github client_id] => 'gh-id-VISIBLE?', %w[github client_secret] => 'gh-secret-VISIBLE?',
               %w[discord client_id] => 'only-an-id' }
    allow(AuthProviders).to receive(:credential) { |provider, name| values[[provider.key, name.to_s]] }

    get admin_system_path

    rows = html.css('[data-providers] tbody tr').to_h { |row| [row.at_css('td').text.strip, row.text] }
    expect(rows.keys).to eq(%w[GitHub Twitter Google Twitch Discord YouTube])
    expect(rows['GitHub']).to include('Configured')
    expect(rows['Discord']).to include('Missing')
    expect(rows['Google']).to include('Missing')
    expect(response.body).not_to include('VISIBLE')
    expect(response.body).not_to include('only-an-id')
  end

  describe 'POST /admin/system/clear_cache' do
    it 'clears the cache and records it' do
      expect(Rails.cache).to receive(:clear).and_call_original

      post clear_cache_admin_system_path

      expect(response).to redirect_to(admin_system_path)
      expect(flash[:notice]).to match(/cache cleared/i)
      expect(AuditLog.order(:id).last).to have_attributes(action: 'system.cache_cleared', actor: admin)
    end

    it "doesn't sign anyone out" do
      post clear_cache_admin_system_path
      get admin_users_path
      expect(response).to have_http_status(:success)
    end
  end
end
