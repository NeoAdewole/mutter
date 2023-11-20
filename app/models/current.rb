class Current < ActiveSupport::CurrentAttributes
  before_action :set_current_user

  def set_current_user
    if session[:user_id]
      Current.user ||= authenticate_user_from_session
    end
  end

  def authenticate_user_from_session
    User.find_by(id: session[:user_id])
  end

end