require 'test_helper'

class RegistrationMailerTest < ActionMailer::TestCase
  test "account_registered email is sent to correct address" do
    alice = users(:alice)
    mail = RegistrationMailer.with(user: alice).account_registered
    assert_equal [alice.email], mail.to
  end

  # BUG DOCUMENTED: The registration confirmation email template uses
  # `edit_password_reset_url(token: params[:token])` where params[:token]
  # is undefined in this mailer context (RegistrationMailer has no :token param).
  # params[:token] is nil, producing a link with no token (a broken reset link).
  # The link also points to the wrong page — should be edit_registration_url,
  # not the password reset flow.
  test "account_registered email renders but contains a broken password-reset link instead of profile link" do
    alice = users(:alice)
    mail = RegistrationMailer.with(user: alice).account_registered
    body = mail.body.encoded
    # Template renders without error — params[:token] is nil, generating a broken URL
    assert_match(/Reset your password/, body, "Email still shows wrong link text ('Reset your password')")
    assert_match(/password_reset/, body, "Email links to password_reset path instead of edit profile")
  end
end
