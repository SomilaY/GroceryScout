require "test_helper"

class Pricing::LoyaltyHubSyncTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :last_arguments

    def initialize(response:)
      @response = response
    end

    def search(**arguments)
      @last_arguments = arguments
      @response
    end
  end

  class FakeImporter
    attr_reader :last_records

    def call(records:)
      @last_records = records

      {
        total: records.fetch("data").length,
        imported_count: 1,
        failed_count: 0
      }
    end
  end

  setup do
    @response = {
      "data" => [
        { "name" => "Test Milk", "price" => 29.99 }
      ],
      "meta" => {
        "count" => 1
      }
    }

    @client = FakeClient.new(response: @response)
    @importer = FakeImporter.new

    @sync = Pricing::LoyaltyHubSync.new(
      client: @client,
      importer: @importer
    )
  end

  test "fetches records and passes the complete response to the importer" do
    result = @sync.call(search: "full cream milk", limit: 10, offset: 0)

    assert_equal(
      { search: "full cream milk", limit: 10, offset: 0 },
      @client.last_arguments
    )

    assert_equal @response, @importer.last_records
    assert_equal 1, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 0, result[:failed_count]
  end

  test "uses default limit and offset when they are omitted" do
    @sync.call(search: "milk")

    assert_equal(
      {
        search: "milk",
        limit: Pricing::LoyaltyHubClient::DEFAULT_LIMIT,
        offset: 0
      },
      @client.last_arguments
    )
  end

  test "propagates client errors" do
    failing_client = Object.new

    def failing_client.search(**)
      raise Pricing::LoyaltyHubClient::ConnectionError, "Connection failed"
    end

    sync = Pricing::LoyaltyHubSync.new(
      client: failing_client,
      importer: @importer
    )

    assert_raises(Pricing::LoyaltyHubClient::ConnectionError) do
      sync.call(search: "milk")
    end
  end
end