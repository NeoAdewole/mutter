require 'rails_helper'

RSpec.describe 'Admin site settings', type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in_as(admin) }

  def field(key)
    html.at_css("[data-setting='#{key}']")
  end

  describe 'GET /admin/settings' do
    it 'shows every setting with its current value and an explanation' do
      SiteSetting.update_values('announcement_message' => 'Maintenance on Friday', 'homepage_streams_limit' => '3', 'signups_enabled' => 'false')

      get admin_settings_path

      expect(response).to have_http_status(:success)
      SiteSetting::DEFINITIONS.each_key { |key| expect(field(key)).to be_present, "missing #{key}" }
      expect(field('signups_enabled').at_css('input[type=checkbox]')['checked']).to be_nil
      expect(field('maintenance_mode').at_css('input[type=checkbox]')['checked']).to be_nil
      expect(field('homepage_streams_enabled').at_css('input[type=checkbox]')['checked']).to be_present
      expect(field('announcement_message').at_css('input')['value']).to eq('Maintenance on Friday')
      expect(field('homepage_streams_limit').at_css('input')['value']).to eq('3')
      expect(field('announcement_level').at_css('option[selected]')['value']).to eq('info')
      expect(field('homepage_streams_limit').text).to include('Between 1 and 10')
    end

    it 'labels every field' do
      get admin_settings_path
      html.css('[data-setting] input:not([type=hidden]), [data-setting] select').each do |input|
        expect(html.at_css("label[for='#{input['id']}']")).to be_present, "no label for #{input['id']}"
      end
    end

    it 'warns when maintenance mode is on' do
      get admin_settings_path
      expect(html.at_css('[data-maintenance-active]')).to be_nil

      SiteSetting.update_values('maintenance_mode' => 'true')
      get admin_settings_path
      expect(html.at_css('[data-maintenance-active]')).to be_present
    end
  end

  describe 'PATCH /admin/settings' do
    it 'saves the settings, and records exactly what changed' do
      patch admin_settings_path, params: { settings: { signups_enabled: '0', homepage_streams_limit: '2', announcement_level: 'warning', maintenance_mode: '0' } }

      expect(response).to redirect_to(admin_settings_path)
      expect(flash[:notice]).to eq('Settings saved.')
      expect(SiteSetting.get('signups_enabled')).to be(false)
      expect(SiteSetting.get('homepage_streams_limit')).to eq(2)
      entry = AuditLog.order(:id).last
      expect(entry).to have_attributes(action: 'settings.updated', actor: admin)
      expect(entry.details['changes']).to eq(
        'signups_enabled' => [true, false], 'homepage_streams_limit' => [5, 2], 'announcement_level' => %w[info warning]
      )
    end

    it 'switches things on through the form checkboxes' do
      patch admin_settings_path, params: { settings: { maintenance_mode: '1', announcement_enabled: '1' } }

      expect(SiteSetting.get('maintenance_mode')).to be(true)
      expect(SiteSetting.get('announcement_enabled')).to be(true)
    end

    it 'says so, and logs nothing, when nothing was changed' do
      expect { patch admin_settings_path, params: { settings: { signups_enabled: '1' } } }.not_to change(AuditLog, :count)
      expect(flash[:notice]).to eq('No changes to save.')
    end

    it 'saves nothing and points at the problem when a value is invalid' do
      expect do
        patch admin_settings_path, params: { settings: { signups_enabled: '0', homepage_streams_limit: '50', announcement_message: 'x' * 400 } }
      end.not_to change(AuditLog, :count)

      expect(response).to have_http_status(422)
      expect(html.css('[data-setting-error]').size).to eq(2)
      expect(field('homepage_streams_limit').text).to include('must be between 1 and 10').or include('whole number between 1 and 10')
      expect(SiteSetting.get('signups_enabled')).to be(true)
    end

    it 'keeps what was typed when the form is shown again with errors' do
      patch admin_settings_path, params: { settings: { announcement_message: 'My banner', homepage_streams_limit: '50' } }

      expect(field('announcement_message').at_css('input')['value']).to eq('My banner')
      expect(field('homepage_streams_limit').at_css('input')['value']).to eq('50')
    end

    it 'ignores parameters that are not settings' do
      patch admin_settings_path, params: { settings: { signups_enabled: '0', admin: 'true', key: 'x' }, admin: true }

      expect(SiteSetting.count).to eq(1)
      expect(admin.reload).to be_admin
    end

    it 'copes with no settings being submitted at all' do
      patch admin_settings_path
      expect(response).to redirect_to(admin_settings_path)
    end
  end
end
