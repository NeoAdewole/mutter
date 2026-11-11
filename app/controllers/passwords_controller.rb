class PasswordsController < ApplicationController
  before_action :authenticate_user!

  def edit; end

  def update
    adding_password = !current_user.password_set?

    if current_user.update(password_params)
      notice = if adding_password
                 'Your password has been added. You can now log in with your email and this password too.'
               else
                 'Your password has been updated successfully.'
               end
      redirect_to edit_password_path, notice: notice
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # A user who has never set a real password (e.g. they signed up via an
  # OAuth provider and only have the random password OmniAuth generated for
  # them) doesn't know a "current password" to challenge -- so this is an
  # "add a password" action for them, not a "change password" one, and skips
  # the current-password check accordingly.
  def password_params
    permitted = params.require(:user).permit(:password, :password_confirmation, :password_challenge)

    if current_user.password_set?
      permitted.with_defaults(password_challenge: '')
    else
      permitted.except(:password_challenge).with_defaults(password_set: true)
    end
  end
end
