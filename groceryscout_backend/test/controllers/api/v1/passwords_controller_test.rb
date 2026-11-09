require "test_helper"

class Api::V1::PasswordsControllerTest < ActionDispatch::IntegrationTest
  test "requests a password reset for an existing customer" do
  user = create_user("john@example.com")

  assert_enqueued_emails 1 do
    post api_v1_password_forgot_url,
         params: { user: { email: user.email } }
  end

  assert_response :ok

  user.reload

  assert user.password_reset_token_digest.present?
  assert user.password_reset_expires_at.present?
end

  test "returns the same response for an unknown email" do
    post api_v1_password_forgot_url,
         params: { user: { email: "unknown@example.com" } }

    assert_response :ok

    response_message = JSON.parse(response.body)["message"]

    assert_equal(
      "If an account exists with that email, password reset instructions will be sent.",
      response_message
    )
  end

  test "successfully resets a customer's password" do
    user = create_user("jane@example.com")
    token = user.generate_password_reset_token!

    patch api_v1_password_reset_url,
          params: {
            token: token,
            user: { password: "newpassword123" }
          }

    assert_response :ok

    user.reload

    assert user.authenticate("newpassword123")
    assert_nil user.password_reset_token_digest
    assert_nil user.password_reset_expires_at
  end

  test "rejects an incorrect reset token" do
    user = create_user("wrong@example.com")
    user.generate_password_reset_token!

    patch api_v1_password_reset_url,
          params: {
            token: "incorrect-token",
            user: { password: "newpassword123" }
          }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("password123")
  end

  test "rejects an expired reset token" do
    user = create_user("expired@example.com")
    token = user.generate_password_reset_token!

    user.update_column(
      :password_reset_expires_at,
      1.minute.ago
    )

    patch api_v1_password_reset_url,
          params: {
            token: token,
            user: { password: "newpassword123" }
          }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("password123")
  end

  test "rejects passwords shorter than eight characters" do
    user = create_user("short@example.com")
    token = user.generate_password_reset_token!

    patch api_v1_password_reset_url,
          params: {
            token: token,
            user: { password: "short" }
          }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("password123")
  end

  test "does not allow a reset token to be reused" do
    user = create_user("reuse@example.com")
    token = user.generate_password_reset_token!

    patch api_v1_password_reset_url,
          params: {
            token: token,
            user: { password: "newpassword123" }
          }

    assert_response :ok

    patch api_v1_password_reset_url,
          params: {
            token: token,
            user: { password: "anotherpassword123" }
          }

    assert_response :unprocessable_entity
    assert user.reload.authenticate("newpassword123")
  end

  private

  def create_user(email)
    User.create!(
      name: "Test Customer",
      email: email,
      password: "password123"
    )
  end
end