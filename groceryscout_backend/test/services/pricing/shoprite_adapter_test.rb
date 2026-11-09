
require "test_helper"

class Pricing::Adapters::ShopriteAdapterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Shoprite",
      slug: "shoprite",
      website_url: "https://www.shoprite.co.za",
      active: true
    )

    @adapter = Pricing::Adapters::ShopriteAdapter.new
  end

  test "imports a Shoprite product and records its price" do
    assert_difference [
      "Product.count",
      "RetailerProduct.count",
      "PriceObservation.count"
    ], 1 do
      @listing = @adapter.import(valid_record)
    end

    assert_equal "Test Shoprite Milk", @listing.product.name
    assert_equal "Shoprite", @listing.retailer.name
    assert_equal "SHO-TEST-002", @listing.retailer_sku
    assert_equal "https://example.com/shoprite-milk.jpg", @listing.image_url

    observation = @listing.price_observations.order(:observed_at).last

    assert_equal 2999, observation.price_cents
    assert_equal "shoprite_feed", observation.source
  end

  test "rejects imports when Shoprite is inactive" do
    @retailer.update!(active: false)

    assert_raises(ArgumentError) do
      Pricing::Adapters::ShopriteAdapter.new
    end
  end

  test "supports a custom import source" do
    adapter = Pricing::Adapters::ShopriteAdapter.new(
      source: "shoprite_test_feed"
    )

    listing = adapter.import(valid_record)

    observation = listing.price_observations.order(:observed_at).last

    assert_equal "shoprite_test_feed", observation.source
  end

  private

  def valid_record
    {
      barcode: "6001234567892",
      name: "Test Shoprite Milk",
      brand: "Clover",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy",
      retailer_sku: "SHO-TEST-002",
      listing_name: "Clover Full Cream Milk 2L",
      product_url: "https://example.com/shoprite-milk",
      image_url: "https://example.com/shoprite-milk.jpg",
      price_cents: 2999,
      currency: "ZAR"
    }
  end
end
