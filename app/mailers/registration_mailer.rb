class RegistrationMailer < ApplicationMailer
  def account_registered
    mail to: params[:user].email
  end
end
