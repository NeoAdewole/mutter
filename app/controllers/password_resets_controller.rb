class PasswordResetsController < ApplicationController
  # before_action :set_user_by_token, only: [:edit, :update]
  
  def new
  end

  def create
    @user = User.find_by(email: params[:email])
    # if (@user = User.find_by(email: params[:email]))
    if @user.present?
      PasswordMailer.with(user: @user).password_reset.deliver_now
      # PasswordMailer.with(
      #   user: @user,
      #   token: @user.generate_token_for(:password_reset)        
      # ).password_reset.deliver_later
      # binding.irb
    end

    redirect_to root_path, notice: "Check your email to reset your password."
  end

  def edit
    @user = User.find_signed!(params[:token], purpose: "password_reset")
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "Your token has expired. Please try again."
  end

  def update
    @user = User.find_signed!(params[:token], purpose: "password_reset")
    if @user.update(password_params)
      redirect_to new_session_path, notice: "Your password has been successfully reset, please log in."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # def set_user_by_token
  #   @user = User.find_by_token_for(:password_reset, params[:token])
  #   redirect_to new_password_reset_path alert: "Invalid token, please try again." unless @user.present?
  # end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

end