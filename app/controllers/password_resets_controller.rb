class PasswordResetsController < ApplicationController
  def new; end

  def create
    @user = User.find_by(email: params[:email])
    PasswordMailer.with(user: @user).password_reset.deliver_now if @user.present?

    redirect_to root_path, notice: 'Check your email to reset your password.'
  end

  def edit
    @user = User.find_signed!(params[:token], purpose: 'password_reset')
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: 'Your token has expired. Please try again.'
  end

  def update
    @user = User.find_signed!(params[:token], purpose: 'password_reset')
    if @user.update(password_params)
      reset_session
      redirect_to new_session_path, notice: 'Your password has been successfully reset, please log in.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    # Successfully resetting a password (proven by the signed emailed token)
    # counts as establishing a real password, same as registering with one or
    # adding one from the account page -- including for an OAuth-only account
    # that never had one.
    params.require(:user).permit(:password, :password_confirmation).with_defaults(password_set: true)
  end
end
