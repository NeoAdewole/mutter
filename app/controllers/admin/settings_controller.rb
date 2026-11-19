module Admin
  class SettingsController < BaseController
    def show
      @submitted = {}
      @errors = {}
    end

    def update
      @submitted = submitted_settings
      result = SiteSetting.update_values(@submitted)

      if result.success?
        audit 'settings.updated', details: { changes: result.changes } if result.changes.any?
        redirect_to admin_settings_path, notice: result.changes.any? ? 'Settings saved.' : 'No changes to save.'
      else
        @errors = result.errors
        flash.now[:alert] = "Nothing was saved. #{result.errors.size} setting#{'s' if result.errors.size > 1} need attention."
        render :show, status: :unprocessable_entity
      end
    end

    private

    def submitted_settings
      params.fetch(:settings, {}).permit(*SiteSetting::DEFINITIONS.keys).to_h
    end
  end
end
