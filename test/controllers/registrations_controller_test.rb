require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Sign-up
  # ---------------------------------------------------------------------------

  test "GET /registration/new renders registration form" do
    get new_registration_path
    assert_response :success
  end

  test "valid registration creates user, signs in, and redirects" do
    assert_difference 'User.count', 1 do
      post registration_path, params: {
        user: {
          email: 'newuser@example.com',
          firstname: 'New',
          lastname: 'User',
          username: 'newuser_reg',
          password: 'securepass',
          password_confirmation: 'securepass'
        }
      }
    end
    assert_redirected_to root_path
    assert_not_nil session[:user_id]
    assert_equal 'Account created successfully.', flash[:notice]
  end

  test "registration with missing required fields re-renders form" do
    assert_no_difference 'User.count' do
      post registration_path, params: {
        user: { email: '', firstname: '', lastname: '', username: '', password: 'pass123', password_confirmation: 'pass123' }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration with duplicate email re-renders form" do
    assert_no_difference 'User.count' do
      post registration_path, params: {
        user: { email: users(:alice).email, firstname: 'Dup', lastname: 'User', username: 'dup_user_unique', password: 'pass123', password_confirmation: 'pass123' }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration with password mismatch re-renders form" do
    assert_no_difference 'User.count' do
      post registration_path, params: {
        user: { email: 'mismatch@example.com', firstname: 'Mis', lastname: 'Match', username: 'mismatch_user', password: 'pass123', password_confirmation: 'different' }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration sends confirmation email" do
    assert_emails 1 do
      post registration_path, params: {
        user: { email: 'emailtest@example.com', firstname: 'Email', lastname: 'Test', username: 'emailtest_user', password: 'pass123', password_confirmation: 'pass123' }
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Edit profile
  # ---------------------------------------------------------------------------

  test "GET /registration/edit redirects unauthenticated user to login" do
    get edit_registration_path
    assert_redirected_to new_session_path
  end

  test "authenticated user can view edit profile form" do
    sign_in_as(users(:alice))
    get edit_registration_path
    assert_response :success
  end

  test "authenticated user can update profile fields" do
    alice = users(:alice)
    sign_in_as(alice)
    patch registration_path, params: {
      user: { firstname: 'Alicia', lastname: 'Smithson', email: alice.email, username: alice.username }
    }
    assert_redirected_to root_path
    assert_equal 'Profile updated successfully.', flash[:notice]
    assert_equal 'Alicia', alice.reload.firstname
  end

  test "profile update with duplicate email re-renders form" do
    sign_in_as(users(:alice))
    patch registration_path, params: {
      user: { firstname: 'Alice', lastname: 'Smith', email: users(:bob).email, username: 'alice_smith' }
    }
    assert_response :unprocessable_entity
  end

  # ---------------------------------------------------------------------------
  # Account deletion
  # ---------------------------------------------------------------------------

  test "unauthenticated DELETE redirects to login" do
    assert_no_difference 'User.count' do
      delete registration_path
    end
    assert_redirected_to new_session_path
  end

  test "authenticated user can delete their account including associated records" do
    alice = users(:alice)
    sign_in_as(alice)

    assert_difference 'User.count', -1 do
      delete registration_path
    end
    assert_redirected_to root_path
    assert_equal 'Account deleted successfully.', flash[:notice]
    assert_nil session[:user_id]
    assert_nil User.find_by(id: alice.id)
  end

  test "deleting account also removes associated tweets and twitter accounts" do
    alice = users(:alice)
    sign_in_as(alice)

    tweet_id = tweets(:alice_scheduled_tweet).id
    account_id = twitter_accounts(:alice_twitter).id

    delete registration_path

    assert_nil Tweet.find_by(id: tweet_id)
    assert_nil TwitterAccount.find_by(id: account_id)
  end

  private

  def sign_in_as(user)
    pwd = { users(:alice) => 'password123', users(:bob) => 'password456' }.fetch(user, 'password123')
    post session_path, params: { user: { email: user.email, password: pwd } }
  end
end
