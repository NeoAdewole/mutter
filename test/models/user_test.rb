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
    assert duplicate.errors[:email].present?
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
    assert duplicate.errors[:username].present?
  end

  test "password must be at least 6 characters on create" do
    user = User.new(email: 'a@example.com', firstname: 'J', lastname: 'D', username: 'jd_short', password: '123', password_confirmation: '123')
    assert_not user.valid?
    assert user.errors[:password].present?
  end

  test "password minimum length is enforced on update too" do
    alice = users(:alice)
    alice.password = '123'
    alice.password_confirmation = '123'
    assert_not alice.valid?
    assert alice.errors[:password].present?
  end

  test "password confirmation must match on create" do
    user = User.new(email: 'a@example.com', firstname: 'J', lastname: 'D', username: 'jd_mismatch', password: 'pass123', password_confirmation: 'different')
    assert_not user.valid?
  end

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  test "authenticate returns user with correct password" do
    assert users(:alice).authenticate('password123')
  end

  test "authenticate returns false with wrong password" do
    assert_equal false, users(:alice).authenticate('wrongpassword')
  end

  # ---------------------------------------------------------------------------
  # Password reset token
  # ---------------------------------------------------------------------------

  test "generates and finds password reset token" do
    alice = users(:alice)
    token = alice.generate_token_for(:password_reset)
    assert_equal alice, User.find_by_token_for(:password_reset, token)
  end

  # ---------------------------------------------------------------------------
  # OAuth: find_or_create_from_auth_hash
  # ---------------------------------------------------------------------------

  test "returns existing user when identity matches" do
    alice = users(:alice)
    identity = identities(:alice_github)
    auth = mock_auth_hash(provider: identity.provider, uid: identity.uuid, email: alice.email)
    assert_equal alice, User.find_or_create_from_auth_hash(auth)
  end

  test "finds existing user by email when identity is new" do
    alice = users(:alice)
    auth = mock_auth_hash(provider: 'discord', uid: 'new_discord_uid', email: alice.email)
    assert_equal alice, User.find_or_create_from_auth_hash(auth)
  end

  test "creates brand-new user with firstname and lastname from provider name" do
    auth = mock_auth_hash(
      provider: 'github',
      uid: 'brand_new_uid_999',
      email: 'brandnew@example.com',
      nickname: 'brandnewuser',
      name: 'Brand New'
    )
    assert_difference 'User.count', 1 do
      user = User.find_or_create_from_auth_hash(auth)
      assert_equal 'Brand', user.firstname
      assert_equal 'New', user.lastname
    end
  end
end
