require 'test_helper'

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
  end

  test "GET /password/edit renders change-password form" do
    get edit_password_path
    assert_response :success
  end

  test "unauthenticated user is redirected to login" do
    delete session_path
    get edit_password_path
    assert_redirected_to new_session_path
  end

  test "valid current password and matching new password updates successfully" do
    patch password_path, params: {
      user: { password_challenge: 'password123', password: 'newpassword1', password_confirmation: 'newpassword1' }
    }
    assert_redirected_to edit_password_path
    assert_equal 'Your password has been updated successfully.', flash[:notice]
    assert users(:alice).reload.authenticate('newpassword1')
  end

  test "wrong current password is rejected" do
    patch password_path, params: {
      user: { password_challenge: 'wrongcurrentpassword', password: 'newpassword1', password_confirmation: 'newpassword1' }
    }
    assert_response :unprocessable_entity
    assert users(:alice).reload.authenticate('password123'), "Original password should be unchanged"
  end

  test "mismatched password_confirmation is rejected" do
    patch password_path, params: {
      user: { password_challenge: 'password123', password: 'newpassword1', password_confirmation: 'different' }
    }
    assert_response :unprocessable_entity
  end

  test "new password shorter than 6 characters is rejected" do
    patch password_path, params: {
      user: { password_challenge: 'password123', password: '123', password_confirmation: '123' }
    }
    assert_response :unprocessable_entity
    assert users(:alice).reload.authenticate('password123'), "Original password should be unchanged"
  end

  private

  def sign_in_as(user)
    post session_path, params: { user: { email: user.email, password: 'password123' } }
  end
end
