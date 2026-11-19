module Admin
  class DashboardController < BaseController
    def show
      @stats = DashboardStats.new
    end
  end
end
