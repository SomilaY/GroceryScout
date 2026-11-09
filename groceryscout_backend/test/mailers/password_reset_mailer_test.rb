require "test_helper"

class PasswordResetMailerTest < ActionMailer::TestCase
  test "sends password reset email to the correct customer" do
    user = User.create!(
      name: "John Smith",
      email: "john@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    email = PasswordResetMailer.reset(user, token)

    assert_equal ["john@example.com"], email.to
    assert_equal "Reset your GroceryScout password", email.subject
    assert_equal ["no-reply@groceryscout.co.za"], email.from
  end

  test "includes the reset link in the email" do
    user = User.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    email = PasswordResetMailer.reset(user, token)

    assert_includes email.body.encoded, token
    assert_includes email.body.encoded, "reset-password?token="
  end

  test "explains that the reset link expires after 30 minutes" do
    user = User.create!(
      name: "John Smith",
      email: "john2@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    email = PasswordResetMailer.reset(user, token)

    assert_includes email.body.encoded, "expires in 30 minutes"
  end
end