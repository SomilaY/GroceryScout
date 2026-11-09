
module Pricing
  module Adapters
    class ShopriteAdapter
      def initialize(source: "shoprite_feed")
        @retailer = Retailer.find_by!(slug: "shoprite")

        unless @retailer.active?
          raise ArgumentError, "Shoprite is inactive"
        end

        @feed_adapter = NormalizedFeedAdapter.new(
          retailer: @retailer,
          source: source
        )
      end

      def import(record)
        @feed_adapter.import(record)
      end
    end
  end
end
