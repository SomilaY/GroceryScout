
module Pricing
  module Adapters
    class ShopriteFeedImporter
      def initialize(source: "shoprite_feed")
        @adapter = ShopriteAdapter.new(source: source)
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
                 ActiveRecord::RecordNotFound => error

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
end
