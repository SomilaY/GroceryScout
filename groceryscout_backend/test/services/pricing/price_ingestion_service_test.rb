
require "test_helper"

class Pricing::PriceIngestionServiceTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Shoprite",
      slug: "shoprite"
    )

    @product = Product.create!(
      name: "Test Milk",
      brand: "Clover"
    )

    @listing = RetailerProduct.create!(
      retailer: @retailer,
      product: @product,
      listing_name: "Clover Full Cream Milk 2L",
      active: true
    )
  end

  test "successfully records a new price observation" do
    observation = build_service.call

    assert observation.persisted?
    assert_equal @listing.id, observation.retailer_product_id
    assert_equal 2949, observation.price_cents
    assert_equal "ZAR", observation.currency
    assert_equal "development_test_data", observation.source
  end

  test "preserves previous price observations" do
    @listing.price_observations.create!(
      price_cents: 2899,
      currency: "ZAR",
      observed_at: 1.hour.ago,
      source: "development_test_data"
    )

    assert_difference "PriceObservation.count", 1 do
      build_service.call
    end

    assert_equal [2899, 2949],
      @listing.price_observations.order(:price_cents).pluck(:price_cents)
  end

  test "rejects an invalid price" do
    assert_raises(ActiveRecord::RecordInvalid) do
      build_service(price_cents: 0).call
    end
  end

  test "rejects an unsupported currency" do
    assert_raises(ArgumentError) do
      build_service(currency: "USD").call
    end
  end

  test "rejects an inactive retailer product" do
    @listing.update!(active: false)

    assert_raises(ArgumentError) do
      build_service.call
    end
  end

    test "rejects a price observation dated too far in the future" do
    assert_raises(ArgumentError) do
      build_service(
        observed_at: 6.minutes.from_now
      ).call
    end
  end

  private

   def build_service(
    price_cents: 2949,
    currency: "ZAR",
    observed_at: Time.current
  )
    Pricing::PriceIngestionService.new(
      retailer_product_id: @listing.id,
      price_cents: price_cents,
      currency: currency,
      observed_at: observed_at,
      source: "development_test_data"
    )
  end
end
