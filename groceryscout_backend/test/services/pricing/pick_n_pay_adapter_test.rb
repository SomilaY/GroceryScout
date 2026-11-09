
require "test_helper"

class Pricing::Adapters::PickNPayAdapterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Pick n Pay",
      slug: "pick-n-pay",
      website_url: "https://www.pnp.co.za",
      active: true
    )

    @adapter = Pricing::Adapters::PickNPayAdapter.new
  end

  test "imports a Pick n Pay product and price" do
    record = {
      barcode: "6001234567895",
      name: "Test Pick n Pay Milk",
      brand: "Clover",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy",
      retailer_sku: "PNP-TEST-005",
      listing_name: "Clover Full Cream Milk 2L",
      product_url: "https://example.com/pnp-milk",
      image_url: "https://example.com/pnp-milk.jpg",
      price_cents: 3199,
      currency: "ZAR"
    }

    listing = @adapter.import(record)

    assert_equal @retailer.id, listing.retailer_id
    assert_equal "6001234567895", listing.product.barcode
    assert_equal 3199, listing.price_observations.order(:created_at).last.price_cents
  end

  test "rejects imports when Pick n Pay is inactive" do
    @retailer.update!(active: false)

    assert_raises(ArgumentError) do
      Pricing::Adapters::PickNPayAdapter.new
    end
  end

  test "supports a custom import source" do
    adapter = Pricing::Adapters::PickNPayAdapter.new(
      source: "pick_n_pay_test_feed"
    )

    record = {
      barcode: "6001234567896",
      name: "Another Test Pick n Pay Milk",
      price_cents: 3299
    }

    listing = adapter.import(record)

    observation = listing.price_observations.order(:created_at).last

    assert_equal "pick_n_pay_test_feed", observation.source
  end
end
