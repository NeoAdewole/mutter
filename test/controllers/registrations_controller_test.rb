require 'test_helper'

# Tests for user sign-up, profile editing, and account deletion.
class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  # ---------------------------------------------------------------------------
  # Sign-up (RegistrationsController#create)
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
        user: {
          email: '',
          firstname: '',
          lastname: '',
          username: '',
          password: 'pass123',
          password_confirmation: 'pass123'
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration with duplicate email re-renders form" do
    assert_no_difference 'User.count' do
      post registration_path, params: {
        user: {
          email: users(:alice).email,
          firstname: 'Dup',
          lastname: 'User',
          username: 'dup_user_unique',
          password: 'pass123',
          password_confirmation: 'pass123'
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration with password mismatch re-renders form" do
    assert_no_difference 'User.count' do
      post registration_path, params: {
        user: {
          email: 'mismatch@example.com',
          firstname: 'Mis',
          lastname: 'Match',
          username: 'mismatch_user',
          password: 'pass123',
          password_confirmation: 'different'
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "registration sends confirmation email" do
    assert_emails 1 do
      post registration_path, params: {
        user: {
          email: 'emailtest@example.com',
          firstname: 'Email',
          lastname: 'Test',
          username: 'emailtest_user',
          password: 'pass123',
          password_confirmation: 'pass123'
        }
      }
    end
  end

  # ---------------------------------------------------------------------------
  # Edit profile (RegistrationsController#edit / #update)
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
  # Account deletion (RegistrationsController#destroy)
  # ---------------------------------------------------------------------------

  # BUG DOCUMENTED: RegistrationsController#destroy has no `authenticate_user!`
  # guard. When called while unauthenticated, current_user is nil and calling
  # @user.destroy raises NoMethodError: undefined method 'destroy' for nil.
  test "unauthenticated delete crashes with NoMethodError (known bug — missing authenticate_user!)" do
    assert_raises(NoMethodError) do
      delete registration_path
    end
  end

  # BUG DOCUMENTED: User model's has_many :tweets is missing `dependent: :destroy`.
  # Deleting a user who owns tweets raises ActiveRecord::InvalidForeignKey.
  test "deleting a user with tweets raises FK violation (known bug — missing dependent: :destroy)" do
    sign_in_as(users(:alice))
    # alice has a tweet fixture — deletion fails due to FK constraint
    assert_raises(ActiveRecord::InvalidForeignKey) do
      delete registration_path
    end
  end

  test "authenticated user with no tweets can delete their account" do
    # Create a fresh user with no associated records
    user = User.create!(
      email: 'deleteme@example.com',
      firstname: 'Delete',
      lastname: 'Me',
      username: 'delete_me_user',
      password: 'pass123',
      password_confirmation: 'pass123'
    )
    sign_in_as(user)

    assert_difference 'User.count', -1 do
      delete registration_path
    end
    assert_redirected_to root_path
    assert_equal 'Account deleted successfully.', flash[:notice]
    assert_nil session[:user_id]
  end

  private

  def sign_in_as(user)
    pwd = user == users(:alice) ? 'password123' : (user == users(:bob) ? 'password456' : 'pass123')
    post session_path, params: { user: { email: user.email, password: pwd } }
  end
end
