require "test_helper"

class Api::V1::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "successfully registers a customer" do
    assert_difference("User.count", 1) do
      post "/api/v1/register",
           params: {
             user: {
               name: "John Smith",
               email: "john.register@example.com",
               password: "password123"
             }
           },
           as: :json
    end

    assert_response :created

    response_data = JSON.parse(response.body)

    assert_equal "Registration successful", response_data["message"]
    assert_equal "John Smith", response_data["user"]["name"]
    assert_equal "john.register@example.com", response_data["user"]["email"]
    assert response_data["access_token"].present?
    assert response_data["refresh_token"].present?
    assert_equal 1, User.find_by(email: "john.register@example.com").refresh_tokens.count
    assert_equal "Bearer", response_data["token_type"]
  end

  test "returns a valid authentication token" do
    post "/api/v1/register",
         params: {
           user: {
             name: "Jane Smith",
             email: "jane.register@example.com",
             password: "password123"
           }
         },
         as: :json

    response_data = JSON.parse(response.body)
    decoded_token = TokenService.decode(response_data["access_token"])

    assert_equal response_data["user"]["id"], decoded_token["sub"]
  end

  test "rejects duplicate email addresses" do
    User.create!(
      name: "Existing Customer",
      email: "existing@example.com",
      password: "password123"
    )

    assert_no_difference("User.count") do
      post "/api/v1/register",
           params: {
             user: {
               name: "Another Customer",
               email: "EXISTING@example.com",
               password: "password123"
             }
           },
           as: :json
    end

    assert_response :unprocessable_entity
  end

  test "rejects passwords shorter than eight characters" do
    post "/api/v1/register",
         params: {
           user: {
             name: "John Smith",
             email: "short.password@example.com",
             password: "short"
           }
         },
         as: :json

    assert_response :unprocessable_entity
  end

  test "rejects registration without a name" do
    post "/api/v1/register",
         params: {
           user: {
             email: "no.name@example.com",
             password: "password123"
           }
         },
         as: :json

    assert_response :unprocessable_entity
  end
end