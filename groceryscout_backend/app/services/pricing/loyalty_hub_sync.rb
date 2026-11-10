module Pricing
  class LoyaltyHubSync
    def initialize(client: LoyaltyHubClient.new, importer: LoyaltyHubImporter.new)
      @client = client
      @importer = importer
    end

    def call(search:, limit: LoyaltyHubClient::DEFAULT_LIMIT, offset: 0)
      response = @client.search(
        search: search,
        limit: limit,
        offset: offset
      )

      @importer.call(records: response)
    end
  end
end