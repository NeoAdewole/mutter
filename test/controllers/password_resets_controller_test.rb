require 'test_helper'

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Request reset email
  # ---------------------------------------------------------------------------

  test "GET /password_reset/new renders forgot-password form" do
    get new_password_reset_path
    assert_response :success
  end

  test "posting a known email sends reset email and redirects" do
    assert_emails 1 do
      post password_reset_path, params: { email: users(:alice).email }
    end
    assert_redirected_to root_path
    assert_equal 'Check your email to reset your password.', flash[:notice]
  end

  test "posting an unknown email still redirects without leaking info" do
    assert_emails 0 do
      post password_reset_path, params: { email: 'nobody@example.com' }
    end
    assert_redirected_to root_path
    assert_equal 'Check your email to reset your password.', flash[:notice]
  end

  # ---------------------------------------------------------------------------
  # Reset password form
  # ---------------------------------------------------------------------------

  test "GET /password_reset/edit with valid token renders reset form" do
    token = reset_token_for(users(:alice))
    get edit_password_reset_path(token: token)
    assert_response :success
  end

  test "GET /password_reset/edit with invalid token redirects to login with alert" do
    get edit_password_reset_path(token: 'bogus_token')
    assert_redirected_to new_session_path
    assert_equal 'Your token has expired. Please try again.', flash[:alert]
  end

  test "valid token with matching passwords resets password and redirects to login" do
    alice = users(:alice)
    token = reset_token_for(alice)

    patch password_reset_path, params: {
      token: token,
      user: { password: 'newpassword1', password_confirmation: 'newpassword1' }
    }
    assert_redirected_to new_session_path
    assert_equal 'Your password has been successfully reset, please log in.', flash[:notice]
    assert alice.reload.authenticate('newpassword1')
  end

  test "mismatched password_confirmation re-renders reset form" do
    alice = users(:alice)
    token = reset_token_for(alice)

    patch password_reset_path, params: {
      token: token,
      user: { password: 'newpassword1', password_confirmation: 'different' }
    }
    assert_response :unprocessable_entity
    assert alice.reload.authenticate('password123'), "Original password should be unchanged"
  end

  test "password too short is rejected on reset" do
    alice = users(:alice)
    token = reset_token_for(alice)

    patch password_reset_path, params: {
      token: token,
      user: { password: '123', password_confirmation: '123' }
    }
    assert_response :unprocessable_entity
    assert alice.reload.authenticate('password123'), "Original password should be unchanged"
  end

  test "session is cleared after successful password reset" do
    alice = users(:alice)
    post session_path, params: { user: { email: alice.email, password: 'password123' } }
    assert_equal alice.id, session[:user_id]

    token = reset_token_for(alice)
    patch password_reset_path, params: {
      token: token,
      user: { password: 'brandnewpass', password_confirmation: 'brandnewpass' }
    }

    assert_nil session[:user_id], "Session should be cleared after password reset"
  end

  private

  def reset_token_for(user)
    user.signed_id(purpose: 'password_reset', expires_in: 15.minutes)
  end
end
