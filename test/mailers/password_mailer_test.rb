require 'test_helper'

class PasswordMailerTest < ActionMailer::TestCase
  test "password_reset email is sent to correct address" do
    alice = users(:alice)
    mail = PasswordMailer.with(user: alice).password_reset
    assert_equal [alice.email], mail.to
  end

  test "password_reset email body contains a reset link" do
    alice = users(:alice)
    mail = PasswordMailer.with(user: alice).password_reset
    assert_match(/password_reset/, mail.body.encoded)
  end

  test "password_reset email body contains expiry notice" do
    alice = users(:alice)
    mail = PasswordMailer.with(user: alice).password_reset
    assert_match(/15 minutes/, mail.body.encoded)
  end
end
