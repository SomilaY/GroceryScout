require "test_helper"

class Pricing::LoyaltyHubClientTest < ActiveSupport::TestCase
  class FakeHttp
    class << self
      attr_accessor :last_request, :response

      def start(*args, **kwargs)
        yield self
      end

      def request(request)
        self.last_request = request
        self.response
      end
    end
  end

  setup do
    @api_key = "test-loyalty-hub-key"

    @client = Pricing::LoyaltyHubClient.new(
      api_key: @api_key,
      http_class: FakeHttp
    )

    FakeHttp.response = Struct.new(:code, :body).new(
      "200",
      { data: [{ name: "Test Milk" }] }.to_json
    )
  end

  test "sends an authenticated product search request" do
    result = @client.search(search: "full cream milk", limit: 10, offset: 0)

    assert_equal [{ "name" => "Test Milk" }], result["data"]

    request = FakeHttp.last_request

    assert_equal "GET", request.method
    assert_equal "Bearer #{@api_key}", request["Authorization"]
    assert_equal "application/json", request["Accept"]
    assert_includes request.path, "search=full+cream+milk"
    assert_includes request.path, "limit=10"
    assert_includes request.path, "offset=0"
  end

  test "rejects a missing API key" do
    assert_raises(Pricing::LoyaltyHubClient::AuthenticationError) do
      Pricing::LoyaltyHubClient.new(api_key: nil)
    end
  end

  test "rejects a blank search term" do
    assert_raises(ArgumentError) do
      @client.search(search: " ")
    end
  end

  test "rejects an invalid limit" do
    assert_raises(ArgumentError) do
      @client.search(search: "milk", limit: 0)
    end
  end

  test "rejects a negative offset" do
    assert_raises(ArgumentError) do
      @client.search(search: "milk", offset: -1)
    end
  end

  test "raises an authentication error when the API rejects the key" do
    FakeHttp.response.code = "401"

    assert_raises(Pricing::LoyaltyHubClient::AuthenticationError) do
      @client.search(search: "milk")
    end
  end

  test "raises a rate limit error when the API returns 429" do
    FakeHttp.response.code = "429"

    assert_raises(Pricing::LoyaltyHubClient::RateLimitError) do
      @client.search(search: "milk")
    end
  end

  test "raises an API error for unsuccessful server responses" do
    FakeHttp.response.code = "500"

    assert_raises(Pricing::LoyaltyHubClient::ApiError) do
      @client.search(search: "milk")
    end
  end

  test "rejects invalid JSON responses" do
    FakeHttp.response.body = "not valid json"

    assert_raises(Pricing::LoyaltyHubClient::ApiError) do
      @client.search(search: "milk")
    end
  end
end