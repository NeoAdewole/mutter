class OmniauthCallbacksController < ApplicationController
  def twitter
    Rails.logger.info request.env['omniauth.auth'].to_yaml
    logger.info 'Check value of auth...'
    Rails.logger.info auth.to_yaml
    redirect_to about_path, notice: 'Successfully connected your Twitter account.'
  end

  # Shared failure handler for every provider (github, google, discord,
  # twitch, twitter2, developer) -- OmniAuth routes any strategy failure here
  # regardless of which one was being used.
  def failure
    reason = params[:message].presence&.humanize || 'please try again'
    destination = user_signed_in? ? edit_registration_path : new_session_path
    redirect_to destination, alert: "Authentication failed: #{reason}."
  end

  private

  # retieve a hash of credentials from api response
  def auth
    request.env['omniauth.auth']
  end
end
