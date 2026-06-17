require 'test_helper'

class RegistrationMailerTest < ActionMailer::TestCase
  test "account_registered email is sent to correct address" do
    alice = users(:alice)
    mail = RegistrationMailer.with(user: alice).account_registered
    assert_equal [alice.email], mail.to
  end

  test "account_registered email links to edit profile page" do
    alice = users(:alice)
    mail = RegistrationMailer.with(user: alice).account_registered
    body = mail.body.encoded
    assert_match(/registration\/edit/, body)
    assert_match(/Edit your profile/, body)
  end
end
