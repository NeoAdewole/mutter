class SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def new
    @user = User.new
  end

  def create
    if params[:user].present?
      handle_password_login
    elsif request.env['omniauth.auth']
      connecting_provider? ? handle_provider_connection : handle_omniauth_login
    end
  end

  def destroy
    logout current_user
    redirect_to root_path, notice: 'You have been logged out.'
  end

  private

  def handle_password_login
    email_or_username = params[:user][:email]
    @user = User.find_by(email: email_or_username) || User.find_by(username: email_or_username)

    if @user&.authenticate(params[:user][:password])
      login(@user)
      redirect_to about_path, notice: 'Signed in!'
    else
      redirect_to new_session_path, alert: 'Invalid email/username or password.'
    end
  end

  def handle_omniauth_login
    auth = request.env['omniauth.auth']
    user = User.find_or_create_from_auth_hash(auth)

    unless user.persisted?
      redirect_to root_path, alert: 'Failed to sign in!'
      return
    end

    newly_created = user.previously_new_record?
    login(user)
    provider_name = auth.provider.to_s.titleize

    if auth.info.email.blank?
      redirect_to edit_registration_path,
                  notice: "Signed in with #{provider_name}. Please add an email address to finish setting up your account."
    elsif newly_created
      redirect_to about_path,
                  notice: "Welcome! Your account was created using #{provider_name}. " \
                          'You can add a password any time from your account page to also sign in with email and password.'
    else
      redirect_to about_path, notice: "Welcome back! Signed in with #{provider_name}."
    end
  end

  # A signed-in user clicking "Connect" for another provider from their
  # profile page (see registrations/edit) -- links that identity to their
  # CURRENT account rather than the usual find-or-create-and-log-in behavior,
  # and never touches who's logged in.
  def handle_provider_connection
    unless user_signed_in?
      redirect_to new_session_path, alert: 'You must be logged in to connect an identity provider.'
      return
    end

    auth = request.env['omniauth.auth']
    provider_name = auth.provider.to_s.titleize

    case current_user.connect_identity_from_auth_hash(auth)
    when :connected
      redirect_to connection_return_path, notice: "Connected your #{provider_name} account. You can sign in with it too now."
    when :already_connected
      redirect_to connection_return_path, notice: "Your #{provider_name} account is already connected."
    when :conflict
      redirect_to connection_return_path,
                  alert: "That #{provider_name} account is already connected to a different Mutter account."
    end
  end

  def connecting_provider?
    request.env['omniauth.params'].to_h['connect'] == 'true'
  end

  # Pages that offer a Connect button can ask to be returned to (?return=streaming).
  # Only these known destinations are honored, so the param can't be an open redirect.
  def connection_return_path
    { 'streaming' => live_chat_path }.fetch(request.env['omniauth.params'].to_h['return'], edit_registration_path)
  end
end
