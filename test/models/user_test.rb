require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Validations
  # ---------------------------------------------------------------------------

  test "valid user with all required fields" do
    user = User.new(
      email: 'newuser@example.com',
      firstname: 'Jane',
      lastname: 'Doe',
      username: 'janedoe',
      password: 'securepass',
      password_confirmation: 'securepass'
    )
    assert user.valid?, user.errors.full_messages.to_sentence
  end

  test "invalid without email" do
    user = User.new(firstname: 'Jane', lastname: 'Doe', username: 'janedoe', password: 'pass123', password_confirmation: 'pass123')
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with malformed email" do
    user = User.new(email: 'not-an-email', firstname: 'Jane', lastname: 'Doe', username: 'janedoe', password: 'pass123', password_confirmation: 'pass123')
    assert_not user.valid?
    assert user.errors[:email].present?
  end

  test "invalid without firstname" do
    user = User.new(email: 'a@example.com', lastname: 'Doe', username: 'janedoe', password: 'pass123', password_confirmation: 'pass123')
    assert_not user.valid?
    assert_includes user.errors[:firstname], "can't be blank"
  end

  test "invalid without lastname" do
    user = User.new(email: 'a@example.com', firstname: 'Jane', username: 'janedoe', password: 'pass123', password_confirmation: 'pass123')
    assert_not user.valid?
    assert_includes user.errors[:lastname], "can't be blank"
  end

  test "invalid without username" do
    user = User.new(email: 'a@example.com', firstname: 'Jane', lastname: 'Doe', password: 'pass123', password_confirmation: 'pass123')
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "invalid with duplicate email" do
    duplicate = User.new(
      email: users(:alice).email,
      firstname: 'Alice2', lastname: 'Smith2', username: 'alice2',
      password: 'pass123', password_confirmation: 'pass123'
    )
    assert_not duplicate.valid?
    assert user_error_on?(duplicate, :email)
  end

  test "email is normalized to lowercase" do
    user = User.create!(
      email: 'UPPER@EXAMPLE.COM',
      firstname: 'Upper', lastname: 'Case', username: 'uppercase_user',
      password: 'pass123', password_confirmation: 'pass123'
    )
    assert_equal 'upper@example.com', user.email
  end

  test "invalid with duplicate username" do
    duplicate = User.new(
      email: 'unique@example.com',
      firstname: 'Alice2', lastname: 'Smith2', username: users(:alice).username,
      password: 'pass123', password_confirmation: 'pass123'
    )
    assert_not duplicate.valid?
    assert user_error_on?(duplicate, :username)
  end

  test "password must be at least 6 characters on create" do
    user = User.new(email: 'a@example.com', firstname: 'J', lastname: 'D', username: 'jd_short', password: '123', password_confirmation: '123')
    assert_not user.valid?
    assert user.errors[:password].present?
  end

  test "password confirmation must match on create" do
    user = User.new(email: 'a@example.com', firstname: 'J', lastname: 'D', username: 'jd_mismatch', password: 'pass123', password_confirmation: 'different')
    assert_not user.valid?
  end

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  test "authenticate returns user with correct password" do
    user = users(:alice)
    assert user.authenticate('password123')
  end

  test "authenticate returns false with wrong password" do
    user = users(:alice)
    assert_equal false, user.authenticate('wrongpassword')
  end

  # ---------------------------------------------------------------------------
  # Password reset token
  # ---------------------------------------------------------------------------

  test "generates and finds password reset token" do
    user = users(:alice)
    token = user.generate_token_for(:password_reset)
    found = User.find_by_token_for(:password_reset, token)
    assert_equal user, found
  end

  # ---------------------------------------------------------------------------
  # OAuth: find_or_create_from_auth_hash
  # ---------------------------------------------------------------------------

  test "find_or_create_from_auth_hash returns existing user when identity matches" do
    alice = users(:alice)
    identity = identities(:alice_github)

    auth = mock_auth_hash(provider: identity.provider, uid: identity.uuid, email: alice.email)
    result = User.find_or_create_from_auth_hash(auth)
    assert_equal alice, result
  end

  test "find_or_create_from_auth_hash finds existing user by email when identity is new" do
    alice = users(:alice)
    auth = mock_auth_hash(provider: 'discord', uid: 'new_discord_uid', email: alice.email)
    result = User.find_or_create_from_auth_hash(auth)
    assert_equal alice, result
  end

  # BUG DOCUMENTED: OAuth user creation fails because firstname and lastname are
  # required by User validations but are never set in find_or_create_from_auth_hash.
  # New OAuth users with no existing account will raise ActiveRecord::RecordInvalid.
  test "find_or_create_from_auth_hash raises when creating brand-new user (missing firstname/lastname)" do
    auth = mock_auth_hash(
      provider: 'github',
      uid: 'brand_new_uid_999',
      email: 'brandnew@example.com',
      nickname: 'brandnewuser'
    )
    assert_raises(ActiveRecord::RecordInvalid) do
      User.find_or_create_from_auth_hash(auth)
    end
  end

  private

  def user_error_on?(user, field)
    user.valid?
    user.errors[field].present?
  end
end
