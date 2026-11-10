
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

    test "retries once after a database uniqueness conflict" do
    original_import = @adapter.method(:import_once)
    attempts = 0

    @adapter.define_singleton_method(:import_once) do |record|
      attempts += 1

      if attempts == 1
        raise ActiveRecord::RecordNotUnique, "Simulated duplicate key"
      end

      original_import.call(record)
    end

    listing = @adapter.import(valid_record)

    assert_equal 2, attempts
    assert listing.persisted?
    assert_equal "6001234567891", listing.product.barcode
    assert_equal 1, RetailerProduct.count
    assert_equal 1, PriceObservation.count
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

test "rolls back existing listing updates when price saving fails" do
  listing = @adapter.import(valid_record)

  original_name = listing.listing_name
  original_price_count = PriceObservation.count

  assert_raises(ActiveRecord::RecordInvalid) do
    @adapter.import(
      valid_record.merge(
        listing_name: "Incorrect Updated Listing",
        price_cents: 0
      )
    )
  end

  listing.reload

  assert_equal original_name, listing.listing_name
  assert_equal original_price_count, PriceObservation.count
  assert_equal 1, Product.where(barcode: "6001234567891").count
end


  test "reuses the same product across different retailers when barcode matches" do
    existing_listing = @adapter.import(valid_record)

    checkers = Retailer.create!(
      name: "Checkers",
      slug: "checkers"
    )

    checkers_adapter = Pricing::Adapters::NormalizedFeedAdapter.new(
      retailer: checkers,
      source: "loyalty_hub"
    )

    assert_difference "Product.count", 0 do
      assert_difference "RetailerProduct.count", 1 do
        @second_listing = checkers_adapter.import(
          valid_record.merge(
            retailer_sku: "CHK-TEST-001",
            price_cents: 3299
          )
        )
      end
    end

    assert_equal existing_listing.product_id, @second_listing.product_id
    assert_equal 2, PriceObservation.count
  end

  test "updates an existing retailer listing with a newly available barcode" do
    record_without_barcode = valid_record.merge(
      barcode: "",
      retailer_sku: "SHO-TEST-002",
      product_url: "https://example.com/another-milk"
    )

    existing_listing = @adapter.import(record_without_barcode)

    updated_record = record_without_barcode.merge(
      barcode: "6001234567892",
      price_cents: 3199
    )

    assert_no_difference "RetailerProduct.count" do
      @updated_listing = @adapter.import(updated_record)
    end

    assert_equal existing_listing.id, @updated_listing.id
    assert_equal "6001234567892", @updated_listing.product.reload.barcode
  end

    test "rejects identifiers that point to different products without modifying either" do
    first_listing = @adapter.import(valid_record)

    second_listing = @adapter.import(
      valid_record.merge(
        barcode: "6001234567893",
        retailer_sku: "SHO-TEST-003",
        product_url: "https://example.com/second-milk",
        name: "Second Test Milk"
      )
    )

    original_product_count = Product.count
    original_listing_count = RetailerProduct.count
    original_price_count = PriceObservation.count

    error = assert_raises(ArgumentError) do
      @adapter.import(
        valid_record.merge(
          barcode: "6001234567891",
          retailer_sku: second_listing.retailer_sku,
          product_url: second_listing.product_url,
          price_cents: 3999
        )
      )
    end

    assert_equal(
      "Retailer listing identifier belongs to a different product",
      error.message
    )

    assert_equal original_product_count, Product.count
    assert_equal original_listing_count, RetailerProduct.count
    assert_equal original_price_count, PriceObservation.count

    assert_equal "Test Full Cream Milk", first_listing.product.reload.name
    assert_equal "Second Test Milk", second_listing.product.reload.name
  end

    test "saves an in-stock retailer listing" do
    listing = @adapter.import(
      valid_record.merge(in_stock: true)
    )

    assert_equal true, listing.in_stock
  end

  test "saves an out-of-stock retailer listing" do
    listing = @adapter.import(
      valid_record.merge(in_stock: false)
    )

    assert_equal false, listing.in_stock
  end

  test "leaves availability unknown when stock information is missing" do
    listing = @adapter.import(valid_record)

    assert_nil listing.in_stock
  end

    test "preserves existing retailer listing details when an update omits them" do
    listing = @adapter.import(
      valid_record.merge(
        listing_name: "Shoprite Clover Milk 2L",
        retailer_sku: "SHO-PRESERVE-001",
        product_url: "https://example.com/original-milk",
        image_url: "https://example.com/original-milk.jpg"
      )
    )

    updated_listing = @adapter.import(
      valid_record.merge(
        retailer_sku: nil,
        product_url: nil,
        image_url: nil,
        listing_name: nil,
        price_cents: 3199
      )
    )

    updated_listing.reload

    assert_equal listing.id, updated_listing.id
    assert_equal "SHO-PRESERVE-001", updated_listing.retailer_sku
    assert_equal "https://example.com/original-milk", updated_listing.product_url
    assert_equal "https://example.com/original-milk.jpg", updated_listing.image_url
    assert_equal "Shoprite Clover Milk 2L", updated_listing.listing_name
  end

    test "preserves existing stock availability when an update omits it" do
    listing = @adapter.import(
      valid_record.merge(in_stock: true)
    )

    updated_listing = @adapter.import(
      valid_record.merge(
        price_cents: 3199,
        in_stock: nil
      )
    )

    assert_equal true, updated_listing.reload.in_stock
  end

      test "does not reactivate an existing inactive retailer listing" do
    listing = @adapter.import(valid_record)
    listing.update!(active: false)

    assert_no_difference "PriceObservation.count" do
      error = assert_raises(ArgumentError) do
        @adapter.import(
          valid_record.merge(price_cents: 3199)
        )
      end

      assert_equal "Retailer product is inactive", error.message
    end

    assert_equal false, listing.reload.active
  end

  test "creates new retailer listings as active" do
    listing = @adapter.import(valid_record)

    assert_equal true, listing.active
  end

  test "rejects records that are not hashes" do
    [nil, "invalid record", 123, []].each do |record|
      error = assert_raises(ArgumentError) do
        @adapter.import(record)
      end

      assert_equal "Record must be a hash", error.message
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
