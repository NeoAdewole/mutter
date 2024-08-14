class OmniauthCallbacksController < ApplicationController
  def twitter
    Rails.logger.info request.env['omniauth.auth'].to_yaml
    logger.info "Check value of auth..."
    Rails.logger.info auth.to_yaml
    redirect_to about_path, notice: "Successfully connected your Twitter account."
  end

  def failure
    redirect_to twitter_accounts_path, alert: 'Failed to connect your Twitter account'
  end

  private
  # retieve a hash of credentials from api response
  def auth
    request.env['omniauth.auth']
  end
end