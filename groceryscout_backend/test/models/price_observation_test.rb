
require "test_helper"

class PriceObservationTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Checkers",
      slug: "checkers"
    )

    @product = Product.create!(
      name: "Test Milk",
      brand: "Clover"
    )

    @listing = RetailerProduct.create!(
      retailer: @retailer,
      product: @product,
      listing_name: "Clover Full Cream Milk 2L"
    )
  end

  test "identifies a price recorded recently as fresh" do
    price = create_price(observed_at: 2.hours.ago)

    assert_equal true, price.fresh?
    assert_equal false, price.stale?
  end

  test "identifies a price older than 24 hours as stale" do
    price = create_price(observed_at: 26.hours.ago)

    assert_equal false, price.fresh?
    assert_equal true, price.stale?
  end

  test "identifies a price recorded exactly 24 hours ago as fresh" do
  travel_to Time.current do
    price = create_price(observed_at: 24.hours.ago)

    assert_equal true, price.fresh?
  end
end

  test "does not identify a future-dated price as fresh" do
    price = create_price(observed_at: 1.minute.from_now)

    assert_equal false, price.fresh?
    assert_equal false, price.stale?
  end

  private

  def create_price(observed_at:)
    @listing.price_observations.create!(
      price_cents: 2999,
      currency: "ZAR",
      observed_at: observed_at,
      source: "manual_test"
    )
  end
end
