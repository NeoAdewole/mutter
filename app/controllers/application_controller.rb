class ApplicationController < ActionController::Base
  before_action :set_current_user

  def set_current_user
    return unless session[:user_id]

    Current.user = User.find_by(id: session[:user_id])
  end

  private

  def authenticate_user!
    redirect_to new_session_path, alert: 'You must be logged in to do that.' unless user_signed_in?
  end

  def current_user
    Current.user ||= authenticate_user_from_session
  end
  helper_method :current_user

  def authenticate_user_from_session
    User.find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end
  helper_method :user_signed_in?

  def admin_signed_in?
    current_user&.admin? || false
  end
  helper_method :admin_signed_in?

  # Same plain 404 for "no such page" and "not allowed to know it exists".
  def render_not_found
    render file: Rails.public_path.join('404.html'), status: :not_found, layout: false
  end

  def login(user)
    Current.user = user
    reset_session
    session[:user_id] = user.id
  end

  def logout(_user)
    Current.user = nil
    reset_session
  end
end
