
require "test_helper"

class Api::V1::TokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "John Smith",
      email: "john.refresh@example.com",
      password: "password123"
    )
  end

  test "successfully refreshes tokens and revokes the old refresh token" do
    old_record, old_refresh_token = RefreshToken.create_for(@user)

    post "/api/v1/refresh",
         params: { refresh_token: old_refresh_token },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)

    assert response_data["access_token"].present?
    assert response_data["refresh_token"].present?
    assert_equal TokenService::ACCESS_TOKEN_TTL.to_i,
                 response_data["expires_in"]

    old_record.reload
    assert old_record.revoked_at.present?

    new_record = @user.refresh_tokens.order(created_at: :desc).first

    assert new_record.active?
    assert_equal Digest::SHA256.hexdigest(response_data["refresh_token"]),
                 new_record.token_digest
    assert_not_equal old_refresh_token, response_data["refresh_token"]
  end

    test "rejects a refresh request without a token" do
    post "/api/v1/refresh",
         params: {},
         as: :json

    assert_response :unauthorized
    assert_equal "Refresh token is required",
                 JSON.parse(response.body)["error"]
  end

  test "rejects an unknown refresh token" do
    post "/api/v1/refresh",
         params: { refresh_token: "invalid-token" },
         as: :json

    assert_response :unauthorized
  end

  test "rejects reuse of a revoked refresh token" do
    refresh_record, refresh_token = RefreshToken.create_for(@user)
    refresh_record.revoke!

    post "/api/v1/refresh",
         params: { refresh_token: refresh_token },
         as: :json

    assert_response :unauthorized
  end
    test "rejects an expired refresh token" do
    refresh_record, refresh_token = RefreshToken.create_for(@user)
    refresh_record.update!(expires_at: 1.minute.ago)

    post "/api/v1/refresh",
         params: { refresh_token: refresh_token },
         as: :json

    assert_response :unauthorized
  end

  test "rejects refresh tokens belonging to inactive accounts" do
    _refresh_record, refresh_token = RefreshToken.create_for(@user)
    @user.update!(status: "inactive")

    post "/api/v1/refresh",
         params: { refresh_token: refresh_token },
         as: :json

    assert_response :unauthorized
  end

  test "rejects refresh tokens issued before a password change" do
    _refresh_record, refresh_token = RefreshToken.create_for(@user)
    @user.update!(password: "newpassword123")

    post "/api/v1/refresh",
         params: { refresh_token: refresh_token },
         as: :json

    assert_response :unauthorized
  end
end
