class RegistrationsController < ApplicationController
  before_action :authenticate_user!, only: %i[edit update destroy]
  before_action :set_user_and_identities, only: %i[edit update]
  before_action :require_signups_open, only: %i[new create]

  def create
    auth_hash = request.env['omniauth.auth']
    @user = User.new(registration_params)
    if @user.save
      RegistrationMailer.with(user: @user).account_registered.deliver_now
      login @user
      redirect_to root_path, notice: 'Account created successfully.'
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
      redirect_to root_path, notice: 'Profile updated successfully.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @user = current_user
    @user.destroy
    reset_session
    redirect_to root_path, notice: 'Account deleted successfully.'
  end

  private

  def require_signups_open
    return if SiteSetting.get('signups_enabled')

    redirect_to new_session_path, alert: 'New sign-ups are paused right now. If you already have an account, log in below.'
  end

  def set_user_and_identities
    @user = current_user
    @identities = @user.identities
  end

  def registration_params
    params.require(:user).permit(:email, :firstname, :lastname, :username, :password, :password_confirmation)
  end

  def update_params
    params.require(:user).permit(:email, :firstname, :lastname, :username, :show_stream_on_homepage)
  end
end
