require 'test_helper'

# Tests for email/password login, username login, logout, and OAuth sign-in.
class SessionsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Email / Password login (SessionsController#create — password path)
  # ---------------------------------------------------------------------------

  test "GET /session/new renders login form" do
    get new_session_path
    assert_response :success
  end

  test "login with valid email and password redirects and sets session" do
    alice = users(:alice)
    post session_path, params: { user: { email: alice.email, password: 'password123' } }
    assert_redirected_to about_path
    assert_equal alice.id, session[:user_id]
  end

  test "login with valid username redirects and sets session" do
    alice = users(:alice)
    # The sessions controller accepts username in the :email param field
    post session_path, params: { user: { email: alice.username, password: 'password123' } }
    assert_redirected_to about_path
    assert_equal alice.id, session[:user_id]
  end

  test "login with wrong password redirects back with alert and does not set session" do
    alice = users(:alice)
    post session_path, params: { user: { email: alice.email, password: 'wrongpassword' } }
    assert_redirected_to new_session_path
    assert_nil session[:user_id]
    assert_equal 'Invalid email/username or password.', flash[:alert]
  end

  test "login with unknown email redirects back with alert" do
    post session_path, params: { user: { email: 'nobody@example.com', password: 'password123' } }
    assert_redirected_to new_session_path
    assert_nil session[:user_id]
    assert_equal 'Invalid email/username or password.', flash[:alert]
  end

  test "login with unknown username redirects back with alert" do
    post session_path, params: { user: { email: 'nonexistent_username', password: 'password123' } }
    assert_redirected_to new_session_path
    assert_nil session[:user_id]
  end

  # ---------------------------------------------------------------------------
  # Logout (SessionsController#destroy)
  # ---------------------------------------------------------------------------

  test "logout clears session and redirects to root" do
    alice = users(:alice)
    post session_path, params: { user: { email: alice.email, password: 'password123' } }
    assert_equal alice.id, session[:user_id]

    delete session_path
    assert_redirected_to root_path
    assert_nil session[:user_id]
    assert_equal 'You have been logged out.', flash[:notice]
  end

  # ---------------------------------------------------------------------------
  # OAuth login (SessionsController#create — OmniAuth path)
  #
  # BUG DOCUMENTED: SessionsController#create handles both email/password and
  # OAuth in the same action. The first line of the action calls `user_params`,
  # which calls `params.require(:user)`. OAuth callbacks carry no :user params,
  # so this raises ActionController::ParameterMissing (Rails returns 400) before
  # the OAuth code path is ever reached.
  # ---------------------------------------------------------------------------

  test "oauth callback returns 400 because user_params crashes before oauth code runs" do
    alice = users(:alice)
    identity = identities(:alice_github)

    OmniAuth.config.mock_auth[:github] = mock_auth_hash(
      provider: identity.provider,
      uid: identity.uuid,
      email: alice.email
    )

    post '/auth/github'
    follow_redirect! # follows 302 from OmniAuth to /auth/github/callback → sessions#create

    # params.require(:user) raises ParameterMissing → Rails returns 400
    # OAuth sign-in never executes; user is not logged in
    assert_nil session[:user_id], "OAuth login should have signed in the user but crashes before the OAuth code path"
  end

  # BUG DOCUMENTED: Even if the ParameterMissing issue were fixed, new OAuth users
  # would fail because find_or_create_from_auth_hash does not set firstname or
  # lastname, which are required validations — raising ActiveRecord::RecordInvalid.
  test "find_or_create_from_auth_hash raises for brand-new oauth user (missing firstname/lastname)" do
    auth = mock_auth_hash(
      provider: 'github',
      uid: 'brand_new_uid_oauth',
      email: 'brandnewoauth@example.com',
      nickname: 'brandnewperson'
    )
    assert_raises(ActiveRecord::RecordInvalid) do
      User.find_or_create_from_auth_hash(auth)
    end
  end
end
