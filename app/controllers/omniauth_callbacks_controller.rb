class OmniauthCallbacksController < ApplicationController
  def twitter    
    twitter_account = Current.user.twitter_accounts.where(username: auth.info.nickname).first_or_initialize
    twitter_account.update(
      name: auth.info.name,
      image: auth.info.image,
      token: auth.info.token,
      secret:auth.info.secret,
    )

    redirect_to twitter_accounts_path, notice: "Successfully connected your account."
  end

  # retieve a hash of credentials from api response
  def auth
    request.env['omniauth.auth']
  end

end