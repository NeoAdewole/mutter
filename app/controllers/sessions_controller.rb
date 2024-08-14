class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  # def new
  # end

  def create    
    auth_hash = request.env['omniauth.auth']
    uid = auth_hash.uid
    provider = auth_hash.info['provider']
    email = auth_hash.info['email']
    user = User.find_or_create_from_auth_hash(auth_hash)
    if user.persisted?
      login user
      if user.email.blank?
        redirect_to edit_registration_path, notice: "Please update your email address."
      else
        redirect_to about_path, notice: "Signed in!"
      end
    else
      redirect_to root_path, alert: "Failed to sign in!"
    end
  end

  def destroy
    logout current_user
    redirect_to root_path, notice: "You have been logged out."
  end
end