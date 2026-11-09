require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "creates a customer with valid details" do
    user = User.create!(
      name: "John Smith",
      email: "John@Example.com",
      password: "password123"
    )

    assert_equal "john@example.com", user.email
    assert_equal "active", user.status
    assert user.persisted?
  end

  test "stores a hashed password instead of plain text" do
    user = User.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      password: "password123"
    )

    assert_not_equal "password123", user.password_digest
    assert user.authenticate("password123")
  end

  test "rejects duplicate email addresses regardless of case" do
    User.create!(
      name: "John Smith",
      email: "john@example.com",
      password: "password123"
    )

    duplicate = User.new(
      name: "Another Customer",
      email: "JOHN@example.com",
      password: "password123"
    )

    assert_not duplicate.valid?
  end

  test "rejects passwords shorter than eight characters" do
    user = User.new(
      name: "John Smith",
      email: "john@example.com",
      password: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

    test "generates a password reset token" do
    user = User.create!(
      name: "John Smith",
      email: "john@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    assert token.present?
    assert user.password_reset_token_digest.present?
    assert user.password_reset_expires_at.present?
  end

  test "stores a digest instead of the original reset token" do
    user = User.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    assert_not_equal token, user.password_reset_token_digest
  end

  test "accepts a valid password reset token" do
    user = User.create!(
      name: "John Smith",
      email: "john2@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    assert user.valid_password_reset_token?(token)
  end

  test "rejects an incorrect password reset token" do
    user = User.create!(
      name: "Jane Smith",
      email: "jane2@example.com",
      password: "password123"
    )

    user.generate_password_reset_token!

    assert_not user.valid_password_reset_token?("wrong-token")
  end

  test "rejects an expired password reset token" do
    user = User.create!(
      name: "John Smith",
      email: "john3@example.com",
      password: "password123"
    )

    token = user.generate_password_reset_token!

    user.update_column(
      :password_reset_expires_at,
      1.minute.ago
    )

    assert_not user.valid_password_reset_token?(token)
  end
end