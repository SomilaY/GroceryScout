
require "test_helper"

class Pricing::Adapters::WoolworthsAdapterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Woolworths",
      slug: "woolworths",
      website_url: "https://www.woolworths.co.za",
      active: true
    )

    @adapter = Pricing::Adapters::WoolworthsAdapter.new
  end

  test "imports a Woolworths product and price" do
    record = {
      barcode: "6001234567897",
      name: "Test Woolworths Milk",
      brand: "Clover",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy",
      retailer_sku: "WW-TEST-007",
      listing_name: "Clover Full Cream Milk 2L",
      product_url: "https://example.com/woolworths-milk",
      image_url: "https://example.com/woolworths-milk.jpg",
      price_cents: 3499,
      currency: "ZAR"
    }

    listing = @adapter.import(record)

    assert_equal @retailer.id, listing.retailer_id
    assert_equal "6001234567897", listing.product.barcode
    assert_equal 3499, listing.price_observations.order(:created_at).last.price_cents
  end

  test "rejects imports when Woolworths is inactive" do
    @retailer.update!(active: false)

    assert_raises(ArgumentError) do
      Pricing::Adapters::WoolworthsAdapter.new
    end
  end

  test "supports a custom import source" do
    adapter = Pricing::Adapters::WoolworthsAdapter.new(
      source: "woolworths_test_feed"
    )

    record = {
      barcode: "6001234567898",
      name: "Another Test Woolworths Milk",
      price_cents: 3599
    }

    listing = adapter.import(record)

    observation = listing.price_observations.order(:created_at).last

    assert_equal "woolworths_test_feed", observation.source
  end
end
