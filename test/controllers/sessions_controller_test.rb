require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Email / Password login
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
  # Logout
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
  # OAuth login
  # ---------------------------------------------------------------------------

  test "oauth callback with existing identity signs in user" do
    alice = users(:alice)
    identity = identities(:alice_github)

    OmniAuth.config.mock_auth[:github] = mock_auth_hash(
      provider: identity.provider,
      uid: identity.uuid,
      email: alice.email
    )

    post '/auth/github'
    follow_redirect!

    assert_equal alice.id, session[:user_id]
    assert_redirected_to about_path
  end

  test "oauth creates a new user with firstname and lastname from provider name" do
    OmniAuth.config.mock_auth[:github] = mock_auth_hash(
      provider: 'github',
      uid: 'brand_new_uid_oauth',
      email: 'brandnewoauth@example.com',
      nickname: 'brandnewperson',
      name: 'Brand New'
    )

    assert_difference 'User.count', 1 do
      post '/auth/github'
      follow_redirect!
    end

    new_user = User.find_by(email: 'brandnewoauth@example.com')
    assert_not_nil new_user
    assert_equal 'Brand', new_user.firstname
    assert_equal 'New', new_user.lastname
    assert_equal session[:user_id], new_user.id
  end
end
