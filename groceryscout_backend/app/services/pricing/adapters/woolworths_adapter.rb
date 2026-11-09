
module Pricing
  module Adapters
    class WoolworthsAdapter
      def initialize(source: "woolworths_feed")
        @retailer = Retailer.find_by!(slug: "woolworths")

        unless @retailer.active?
          raise ArgumentError, "Woolworths is inactive"
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
