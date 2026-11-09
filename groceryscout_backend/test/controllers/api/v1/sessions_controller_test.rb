require "test_helper"

class Api::V1::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "John Smith",
      email: "john.login@example.com",
      password: "password123"
    )
  end

  test "successfully logs in a customer and returns both tokens" do
    post "/api/v1/login",
         params: {
           user: {
             email: "john.login@example.com",
             password: "password123"
           }
         },
         as: :json

    assert_response :success

    response_data = JSON.parse(response.body)

    assert_equal "Login successful", response_data["message"]
    assert_equal @user.id, response_data["user"]["id"]
    assert response_data["access_token"].present?
    assert response_data["refresh_token"].present?
    assert_equal "Bearer", response_data["token_type"]
    assert_equal 1, @user.refresh_tokens.count
  end

  test "returns a valid access token" do
    post "/api/v1/login",
         params: {
           user: {
             email: "john.login@example.com",
             password: "password123"
           }
         },
         as: :json

    response_data = JSON.parse(response.body)
    decoded_token = TokenService.decode(response_data["access_token"])

    assert_equal @user.id, decoded_token["sub"]
  end

  test "stores only the refresh token digest" do
    post "/api/v1/login",
         params: {
           user: {
             email: "john.login@example.com",
             password: "password123"
           }
         },
         as: :json

    response_data = JSON.parse(response.body)
    refresh_record = @user.refresh_tokens.last

    assert_not_equal response_data["refresh_token"], refresh_record.token_digest
    assert_equal Digest::SHA256.hexdigest(response_data["refresh_token"]),
                 refresh_record.token_digest
  end

  test "rejects an incorrect password" do
    post "/api/v1/login",
         params: {
           user: {
             email: "john.login@example.com",
             password: "wrongpassword"
           }
         },
         as: :json

    assert_response :unauthorized
  end

  test "rejects an email that does not exist" do
    post "/api/v1/login",
         params: {
           user: {
             email: "unknown@example.com",
             password: "password123"
           }
         },
         as: :json

    assert_response :unauthorized
  end

  test "rejects inactive customer accounts" do
    @user.update!(status: "inactive")

    post "/api/v1/login",
         params: {
           user: {
             email: "john.login@example.com",
             password: "password123"
           }
         },
         as: :json

    assert_response :unauthorized
  end

  test "accepts email addresses regardless of case" do
    post "/api/v1/login",
         params: {
           user: {
             email: "JOHN.LOGIN@EXAMPLE.COM",
             password: "password123"
           }
         },
         as: :json

    assert_response :success
  end
  test "successfully logs out and revokes refresh token" do
    _record, refresh_token = RefreshToken.create_for(@user)

    delete "/api/v1/logout",
           params: { refresh_token: refresh_token },
           as: :json

    assert_response :success
    assert_equal "Logout successful", JSON.parse(response.body)["message"]
    assert @user.refresh_tokens.last.revoked_at.present?
  end

  test "rejects logout without a refresh token" do
    delete "/api/v1/logout",
           params: {},
           as: :json

    assert_response :unauthorized
  end

  test "rejects reuse of a revoked refresh token" do
    _record, refresh_token = RefreshToken.create_for(@user)

    delete "/api/v1/logout",
           params: { refresh_token: refresh_token },
           as: :json

    assert_response :success

    delete "/api/v1/logout",
           params: { refresh_token: refresh_token },
           as: :json

    assert_response :unauthorized
  end
end