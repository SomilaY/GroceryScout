
require "test_helper"
require "rack/mock"

class Middleware::RequestBodySizeLimitTest < ActiveSupport::TestCase
  setup do
    @middleware = Middleware::RequestBodySizeLimit.new(
      ->(_env) { [200, {}, ["Request reached application"]] }
    )
  end

  test "rejects JSON requests larger than 5 MB" do
    body = "a" * (5.megabytes + 1)

    env = Rack::MockRequest.env_for(
      "/api/v1/retailer_feeds/import",
      method: "POST",
      input: body,
      "CONTENT_TYPE" => "application/json"
    )

    status, headers, response = @middleware.call(env)

    assert_equal 413, status
    assert_equal "application/json; charset=utf-8", headers["content-type"]
    assert_equal(
      "JSON request body cannot exceed 5 MB",
      JSON.parse(response.join)["error"]
    )
  end

  test "allows JSON requests within the 5 MB limit" do
    body = '{"records":[]}'

    env = Rack::MockRequest.env_for(
      "/api/v1/retailer_feeds/import",
      method: "POST",
      input: body,
      "CONTENT_TYPE" => "application/json"
    )

    status, _headers, response = @middleware.call(env)

    assert_equal 200, status
    assert_equal "Request reached application", response.join
  end

  test "does not apply the JSON limit to other paths" do
    body = "a" * (5.megabytes + 1)

    env = Rack::MockRequest.env_for(
      "/api/v1/products",
      method: "POST",
      input: body,
      "CONTENT_TYPE" => "application/json"
    )

    status, _headers, _response = @middleware.call(env)

    assert_equal 200, status
  end

  test "does not apply the JSON limit to non-JSON requests" do
    body = "a" * (5.megabytes + 1)

    env = Rack::MockRequest.env_for(
      "/api/v1/retailer_feeds/import",
      method: "POST",
      input: body,
      "CONTENT_TYPE" => "text/csv"
    )

    status, _headers, _response = @middleware.call(env)

    assert_equal 200, status
  end
end
