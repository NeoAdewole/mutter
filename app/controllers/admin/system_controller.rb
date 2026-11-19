module Admin
  class SystemController < BaseController
    def show
      @status = SystemStatus.new
    end

    def clear_cache
      Rails.cache.clear
      audit 'system.cache_cleared'
      redirect_to admin_system_path, notice: 'Application cache cleared.'
    end
  end
end
