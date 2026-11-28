class OmniauthCallbacksController < ApplicationController
  skip_before_action :enforce_maintenance_mode # a failed admin sign-in must explain itself

  # Shared failure handler for every provider (github, google, discord,
  # twitch, twitter2, developer) -- OmniAuth routes any strategy failure here
  # regardless of which one was being used.
  def failure
    reason = params[:message].presence&.humanize || 'please try again'
    redirect_to return_destination, alert: "Authentication failed: #{reason}."
  end

  # Somebody asked for /auth/<name> and OmniAuth is not handling it: the service
  # has no credentials yet (see AuthProviders), or the name is not one we know.
  # Reaching here means a stale button or a typed address, so explain, don't error.
  def unavailable
    provider = AuthProviders.find(params[:provider])
    name = provider ? provider.label : 'That sign-in method'
    redirect_to return_destination, alert: "#{name} isn't available on this site right now."
  end

  private

  def return_destination
    user_signed_in? ? edit_registration_path : new_session_path
  end
end
