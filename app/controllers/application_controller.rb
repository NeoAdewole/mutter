class ApplicationController < ActionController::Base
  before_action :set_current_user
  before_action :enforce_maintenance_mode

  def set_current_user
    return unless session[:user_id]

    user = User.find_by(id: session[:user_id])
    if user&.suspended?
      # An admin suspended this account while it was signed in: end the session now,
      # not when it would have expired.
      reset_session
      flash[:alert] = 'This account has been suspended. Contact a site admin if you think that is a mistake.'
    else
      Current.user = user
    end
  end

  private

  # While maintenance mode is on, only admins get through. The sign-in screens
  # opt out (skip_before_action) so an admin can still log in to turn it off.
  def enforce_maintenance_mode
    return unless SiteSetting.get('maintenance_mode')
    return if admin_signed_in?

    response.set_header('Retry-After', '3600')
    render 'maintenance/show', status: :service_unavailable, layout: 'bare'
  end

  def authenticate_user!
    return if user_signed_in?

    # Keep a more specific message (such as "your account was suspended") if one was just set.
    redirect_to new_session_path, alert: flash[:alert].presence || 'You must be logged in to do that.'
  end

  def current_user
    Current.user ||= authenticate_user_from_session
  end
  helper_method :current_user

  # A suspended account is never "signed in", whatever the session says.
  def authenticate_user_from_session
    User.active.find_by(id: session[:user_id])
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
    user.record_sign_in!
  end

  def logout(_user)
    Current.user = nil
    reset_session
  end
end
