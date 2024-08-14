class RegistrationsController < ApplicationController
  def new
    @user = User.new
  end

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

  private

  def registration_params
    params.require(:user).permit(:email, :firstname, :lastname, :username, :password, :password_confirmation)
  end
  
  def update_params
    params.require(:user).permit(:email, :firstname, :lastname, :username)
  end
end