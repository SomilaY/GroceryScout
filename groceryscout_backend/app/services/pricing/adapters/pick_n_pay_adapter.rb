
module Pricing
  module Adapters
    class PickNPayAdapter
      def initialize(source: "pick_n_pay_feed")
        @retailer = Retailer.find_by!(slug: "pick-n-pay")

        unless @retailer.active?
          raise ArgumentError, "Pick n Pay is inactive"
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
