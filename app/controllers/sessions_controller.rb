class SessionsController < ApplicationController
  # def new
  # end

  # def create
  #   auth_hash = request.env['omniauth.auth']
  #   logger.info "Auth has is something..."
  #   binding.b
  #   uid = auth_hash.uid
  #   email = auth_hash.info['email']    
  #   if(!auth_hash.nil? && !auth_hash.empty?)
  #     auth_hash = request.env['omniauth.auth']
  #     if user = User.authenticate_by(email: params[:email], password: params[:password])
  #       login user
  #       redirect_to root_path, notice: "You have signed in successfully."
  #       redirect_to twitter_accounts_path, notice: "Successfully signed in."
  #     else
  #       flash[:alert] = "Invalid email or password."
  #       render :new, status: :unprocessable_entity
  #     end
  #   else
  #     flash[:alert] = "Unable to authorize with identity provider."
  #     # binding.b
  #     render :new, status: :unprocessable_entity      
  #   end
  # end

  def create
    auth_hash = request.env['omniauth.auth']
    uid = auth_hash.uid
    email = auth_hash.info['email']
    provider = auth_hash.info['provider']
    user = User.find_or_create_from_auth_hash(auth_hash)
    if user.persisted?
      login user
      redirect_to root_path, notice: "Signed in!" #redirect to dashboard
    else
      redirect_to root_path, alert: "Failed to sign in!"
    end
  end

  def destroy
    logout current_user
    redirect_to root_path, notice: "You have been logged out."
  end
end