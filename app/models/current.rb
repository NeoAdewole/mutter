class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def authenticate_user_from_session
    User.find_by(id: session[:user_id])
  end

end