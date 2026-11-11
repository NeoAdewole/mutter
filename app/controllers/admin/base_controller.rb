module Admin
  # Every admin controller inherits from this one, so authorization is
  # enforced server-side in a single place rather than by hiding links.
  #
  #   guests         -> sent to the login page
  #   signed in, not admin -> a plain 404, so the area's existence isn't confirmed
  #   admins         -> through
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!

    private

    def require_admin!
      render_not_found unless current_user.admin?
    end
  end
end
