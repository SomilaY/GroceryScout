
module Pricing
  class PriceIngestionService
    SUPPORTED_CURRENCIES = %w[ZAR].freeze

    def initialize(
      retailer_product_id:,
      price_cents:,
      source:,
      observed_at: Time.current,
      currency: "ZAR"
    )
      @retailer_product_id = retailer_product_id
      @price_cents = price_cents
      @source = source
      @observed_at = observed_at
      @currency = currency
    end

    def call
      retailer_product = RetailerProduct.find(@retailer_product_id)

      unless retailer_product.active?
        raise ArgumentError, "Retailer product is inactive"
      end

      unless SUPPORTED_CURRENCIES.include?(@currency)
        raise ArgumentError, "Unsupported currency"
      end

      PriceObservation.create!(
        retailer_product: retailer_product,
        price_cents: @price_cents,
        currency: @currency,
        observed_at: @observed_at,
        source: @source
      )
    end
  end
end
