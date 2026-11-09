
require "test_helper"

class Pricing::Adapters::CheckersAdapterTest < ActiveSupport::TestCase
  setup do
  @retailer = Retailer.create!(
    name: "Checkers",
    slug: "checkers",
    website_url: "https://www.checkers.co.za",
    active: true
  )

  @adapter = Pricing::Adapters::CheckersAdapter.new
end

  test "imports a Checkers product and price" do
    record = {
      barcode: "6001234567893",
      name: "Test Checkers Milk",
      brand: "Clover",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy",
      retailer_sku: "CHK-TEST-003",
      listing_name: "Clover Full Cream Milk 2L",
      product_url: "https://example.com/checkers-milk",
      image_url: "https://example.com/checkers-milk.jpg",
      price_cents: 2999,
      currency: "ZAR"
    }

    listing = @adapter.import(record)

    assert_equal @retailer.id, listing.retailer_id
    assert_equal "6001234567893", listing.product.barcode
    assert_equal 2999, listing.price_observations.order(:created_at).last.price_cents
  end

  test "rejects imports when Checkers is inactive" do
    @retailer.update!(active: false)

    assert_raises(ArgumentError) do
      Pricing::Adapters::CheckersAdapter.new
    end
  end

  test "supports a custom import source" do
    adapter = Pricing::Adapters::CheckersAdapter.new(
      source: "checkers_test_feed"
    )

    record = {
      barcode: "6001234567894",
      name: "Another Test Checkers Milk",
      price_cents: 3199
    }

    listing = adapter.import(record)

    observation = listing.price_observations.order(:created_at).last

    assert_equal "checkers_test_feed", observation.source
  end
end
