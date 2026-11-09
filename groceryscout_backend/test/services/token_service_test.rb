require "test_helper"

class TokenServiceTest < ActiveSupport::TestCase
  test "generates a valid token for a customer" do
    user = User.create!(
      name: "John Smith",
      email: "john.token@example.com",
      password: "password123"
    )

    token = TokenService.encode(user)

    decoded = TokenService.decode(token)

    assert_equal user.id, decoded["sub"]
    assert decoded["exp"].present?
    assert decoded["iat"].present?
  end

  test "rejects an invalid token" do
    assert_raises(JWT::DecodeError) do
      TokenService.decode("invalid.token.value")
    end
  end

  test "rejects an expired token" do
    payload = {
      sub: 1,
      exp: 1.hour.ago.to_i,
      iat: 2.hours.ago.to_i
    }

    expired_token = JWT.encode(
      payload,
      Rails.application.secret_key_base,
      "HS256"
    )

    assert_raises(JWT::ExpiredSignature) do
      TokenService.decode(expired_token)
    end
  end
end