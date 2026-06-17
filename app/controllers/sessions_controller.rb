class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def new
    @user = User.new
  end

  def create
    if params[:user].present?
      email_or_username = params[:user][:email]
      @user = User.find_by(email: email_or_username) || User.find_by(username: email_or_username)

      if @user&.authenticate(params[:user][:password])
        login(@user)
        redirect_to about_path, notice: 'Signed in!'
      else
        redirect_to new_session_path, alert: 'Invalid email/username or password.'
      end
    elsif request.env['omniauth.auth']
      user = User.find_or_create_from_auth_hash(request.env['omniauth.auth'])

      if user.persisted?
        login(user)
        if user.email.blank?
          redirect_to edit_registration_path, notice: 'Please update your email address.'
        else
          redirect_to about_path, notice: 'Signed in!'
        end
      else
        redirect_to root_path, alert: 'Failed to sign in!'
      end
    end
  end

  def destroy
    logout current_user
    redirect_to root_path, notice: 'You have been logged out.'
  end
end
