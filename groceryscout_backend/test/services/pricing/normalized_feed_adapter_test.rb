
require "test_helper"

class Pricing::Adapters::NormalizedFeedAdapterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Shoprite",
      slug: "shoprite"
    )

    @adapter = Pricing::Adapters::NormalizedFeedAdapter.new(
      retailer: @retailer,
      source: "development_test_data"
    )
  end

  test "imports a new product, retailer listing, image and price" do
    assert_difference [
      "Product.count",
      "RetailerProduct.count",
      "PriceObservation.count"
    ], 1 do
      @listing = @adapter.import(valid_record)
    end

    assert_equal "Test Full Cream Milk", @listing.product.name
    assert_equal "Clover", @listing.product.brand
    assert_equal "6001234567891", @listing.product.barcode
    assert_equal "Shoprite", @listing.retailer.name
    assert_equal "SHO-TEST-001", @listing.retailer_sku
    assert_equal "https://example.com/milk.jpg", @listing.image_url

    observation = @listing.price_observations.order(:observed_at).last

    assert_equal 3049, observation.price_cents
    assert_equal "ZAR", observation.currency
    assert_equal "development_test_data", observation.source
  end

  
test "preserves existing shared product information while updating retailer listing" do
  @adapter.import(valid_record)

  updated_record = valid_record.merge(
    name: "Different Milk Name",
    brand: "Different Brand",
    price_cents: 3199,
    image_url: "https://example.com/new-milk.jpg",
    listing_name: "Shoprite's Updated Milk Listing"
  )

  assert_no_difference [
    "Product.count",
    "RetailerProduct.count"
  ] do
    assert_difference "PriceObservation.count", 1 do
      @listing = @adapter.import(updated_record)
    end
  end

  assert_equal 1, Product.where(barcode: "6001234567891").count

  assert_equal "Test Full Cream Milk", @listing.product.reload.name
  assert_equal "Clover", @listing.product.brand

  assert_equal "Shoprite's Updated Milk Listing", @listing.reload.listing_name
  assert_equal "https://example.com/new-milk.jpg", @listing.image_url
  assert_equal 3199, @listing.price_observations.order(observed_at: :desc).first.price_cents
end


 test "rejects a record without a barcode, product URL or retailer SKU" do
  assert_raises(ArgumentError) do
    @adapter.import(
      valid_record.merge(
        barcode: "",
        product_url: "",
        retailer_sku: ""
      )
    )
  end
end

  test "rejects a record without a product name" do
    assert_raises(ArgumentError) do
      @adapter.import(valid_record.merge(name: ""))
    end
  end

  test "rejects a record without a price" do
    assert_raises(ArgumentError) do
      @adapter.import(valid_record.merge(price_cents: nil))
    end
  end


test "rolls back product and retailer listing when price saving fails" do
  assert_no_difference [
    "Product.count",
    "RetailerProduct.count",
    "PriceObservation.count"
  ] do
    assert_raises(ActiveRecord::RecordInvalid) do
      @adapter.import(valid_record.merge(price_cents: 0))
    end
  end
end


  private

  def valid_record
    {
      barcode: "6001234567891",
      name: "Test Full Cream Milk",
      brand: "Clover",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy",
      retailer_sku: "SHO-TEST-001",
      listing_name: "Clover Full Cream Milk 2L",
      product_url: "https://example.com/milk",
      image_url: "https://example.com/milk.jpg",
      price_cents: 3049,
      currency: "ZAR"
    }
  end
end
