class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def new
    @user = User.new
  end

  def create
    if user_params
      @user = User.find(user_params)
      logger.info "User params: #{@user}"
      if @user.authenticate(params[:password])
        login(@user)
        redirect_to edit_registration_path, notice: 'Please update your email address.'
      else
        logger.info "Password mismatch for user: #{@user.email}"
        redirect_to new_session_path, alert: 'Invalid email or password.'
      end
    end

    if request.env['omniauth.auth']
      logger.info "Auth hash: #{auth_hash}"
      # if @user.persisted?
      #   logger.info "User logged in: #{@user.email}"
      #   redirect_to about_path, notice: 'Logged in successfully.'
      # else
      #   logger.info "Failed to log in: #{@user.errors.full_messages}"
      #   redirect_to root_path, alert: 'Failed to log in.'
      # end
      auth_hash = request.env['omniauth.auth']
      logger.info "auth hash entered: #{auth_hash}"
      # logger.info "Recieving this from client: #{auth_hash}"
      uid = auth_hash.uid
      provider = auth_hash.info['provider']
      email = auth_hash.info['email']
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

  def destroy
    logout current_user
    redirect_to root_path, notice: 'You have been logged out.'
  end

  def user_params
    params.require(:user).permit(:email, :password)
    logger.info "Credentials entered: #{params[:email]}"
  end
end
