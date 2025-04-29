class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def new
    @user = User.new
  end

  # Handles two types of authentication:
  # 1. Email/Password authentication
  # 2. OAuth provider authentication (e.g., Google, Facebook)
  def create
    # Email/Password or Username/Password Authentication Flow
    if user_params
      # Try to find user by email first, then by username
      email_search = User.find_by(email: params[:user][:email])
      username_search = User.find_by(username: params[:user][:email])
      @user = email_search || username_search

      if @user
        submitted_password = params[:user][:password]        
                
        if @user.authenticate(submitted_password)
          login(@user)
          redirect_to about_path, notice: 'Signed in!'
        else
          redirect_to new_session_path, alert: 'Invalid email/username or password.'
        end
      else
        redirect_to new_session_path, alert: 'Invalid email/username or password.'
      end
    end

    # OAuth Provider Authentication Flow
    if request.env['omniauth.auth']
      auth_hash = request.env['omniauth.auth']
      
      user = User.find_or_create_from_auth_hash(auth_hash)
      
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

  # Handles user logout
  def destroy
    logout current_user
    redirect_to root_path, notice: 'You have been logged out.'
  end

  # Strong parameters for email/password authentication
  def user_params
    params.require(:user).permit(:email, :username, :password)
  end
end
