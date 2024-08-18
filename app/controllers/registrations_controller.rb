class RegistrationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user_and_identities, only: [:edit, :update]

  def create
    auth_hash = request.env['omniauth.auth']
    @user = User.new(registration_params)
    if @user.save
      RegistrationMailer.with(user: @user).account_registered.deliver_now
      login @user
      redirect_to root_path, notice: "Account created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @user = current_user
  end

  def update
    @user = current_user
    if @user.update(update_params)
      redirect_to root_path, notice: "Profile updated successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @user = current_user
    @user.destroy
    session[:user_id] = nil
    redirect_to root_path, notice: 'Account deleted successfully.'
  end

  private

  def set_user_and_identities
    @user = current_user
    @identities = @user.identities
  end

  def registration_params
    params.require(:user).permit(:email, :firstname, :lastname, :username, :password, :password_confirmation)
  end
  
  def update_params
    params.require(:user).permit(:email, :firstname, :lastname, :username)
  end
end