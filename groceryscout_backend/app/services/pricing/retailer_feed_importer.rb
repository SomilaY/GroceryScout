
module Pricing
  class RetailerFeedImporter
    ADAPTERS = {
      "shoprite" => [Adapters::ShopriteAdapter, "shoprite_feed"],
      "checkers" => [Adapters::CheckersAdapter, "checkers_feed"],
      "pick-n-pay" => [Adapters::PickNPayAdapter, "pick_n_pay_feed"],
      "woolworths" => [Adapters::WoolworthsAdapter, "woolworths_feed"]
    }.freeze

    def initialize(retailer_slug:, source: nil)
      config = ADAPTERS[retailer_slug.to_s]

      raise ArgumentError, "Unsupported retailer" unless config

      adapter_class, default_source = config

      @adapter = adapter_class.new(
        source: source || default_source
      )
    end

    def call(records:)
      raise ArgumentError, "Records must be an array" unless records.is_a?(Array)

      imported = []
      failed = []

      records.each_with_index do |record, index|
        begin
          listing = @adapter.import(record)

          imported << {
            index: index,
            retailer_product_id: listing.id,
            product_name: listing.product.name
          }
        rescue ArgumentError,
       ActiveRecord::RecordInvalid,
       ActiveRecord::RecordNotFound,
       ActiveRecord::RecordNotUnique => error

          failed << {
            index: index,
            error: error.message
          }
        end
      end

      {
        total: records.length,
        imported_count: imported.length,
        failed_count: failed.length,
        imported: imported,
        failed: failed
      }
    end
  end
end
