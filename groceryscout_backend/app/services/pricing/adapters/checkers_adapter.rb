
module Pricing
  module Adapters
    class CheckersAdapter
      def initialize(source: "checkers_feed")
        @retailer = Retailer.find_by!(slug: "checkers")

        unless @retailer.active?
          raise ArgumentError, "Checkers is inactive"
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
