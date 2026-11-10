
require "test_helper"

class Pricing::LoyaltyHubImporterTest < ActiveSupport::TestCase
  setup do
    [
      ["Shoprite", "shoprite"],
      ["Checkers", "checkers"],
      ["Pick n Pay", "pick-n-pay"],
      ["Woolworths", "woolworths"]
    ].each do |name, slug|
      Retailer.create!(
        name: name,
        slug: slug,
        active: true
      )
    end

    @importer = Pricing::LoyaltyHubImporter.new

    @sample_record = {
      retailer: "pnp",
      barcode: "6001342201500",
      retailer_sku: "000000000001028333_EA",
      name: "Goldi Chicken Breast Strips 400g",
      brand: nil,
      price: 42.99,
      currency: "ZAR",
      size: {
        quantity: 0.4,
        unit: "kg"
      },
      category: "food",
      last_seen_at: "2026-11-09T09:00:00Z"
    }
  end

  test "imports a Loyalty Hub product using its retailer mapping" do
    result = @importer.call(records: [@sample_record])

    assert_equal 1, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 0, result[:failed_count]

    retailer = Retailer.find_by!(slug: "pick-n-pay")
    listing = retailer.retailer_products.first

    assert_equal "6001342201500", listing.product.barcode
    assert_equal "000000000001028333_EA", listing.retailer_sku
    assert_equal 0.4, listing.product.quantity_value.to_f
    assert_equal "kg", listing.product.quantity_unit
  end

  test "converts decimal rand prices into cents" do
    @importer.call(records: [@sample_record])

    observation = PriceObservation.last

    assert_equal 4299, observation.price_cents
    assert_equal "ZAR", observation.currency
    assert_equal "loyalty_hub", observation.source
  end

  test "uses GTIN when barcode is missing" do
    record = @sample_record.except(:barcode).merge(
      gtin: "6001342201501",
      retailer_sku: "PNP-GTIN-001"
    )

    result = @importer.call(records: [record])

    assert_equal 1, result[:imported_count]
    assert Product.exists?(barcode: "6001342201501")
  end

  test "preserves the last seen timestamp" do
    timestamp = "2026-11-08T10:30:00Z"

    @importer.call(
      records: [@sample_record.merge(last_seen_at: timestamp)]
    )

    assert_equal timestamp.to_time, PriceObservation.last.observed_at
  end

  test "continues importing when a record has an invalid price" do
    valid_record = @sample_record.merge(
      barcode: "6001342201502",
      retailer_sku: "PNP-VALID-002"
    )

    invalid_record = @sample_record.merge(
      barcode: "6001342201503",
      retailer_sku: "PNP-INVALID-003",
      price: nil
    )

    result = @importer.call(
      records: [invalid_record, valid_record]
    )

    assert_equal 2, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 0, result[:failed].first[:index]
  end

    test "rejects records without a last seen timestamp" do
    record = @sample_record.except(:last_seen_at)

    result = @importer.call(records: [record])

    assert_equal 0, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 0, PriceObservation.count
  end

  test "rejects records with an invalid last seen timestamp" do
    record = @sample_record.merge(
      last_seen_at: "not-a-valid-timestamp"
    )

    result = @importer.call(records: [record])

    assert_equal 0, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 0, PriceObservation.count
  end

  test "rejects records with a timestamp too far in the future" do
    record = @sample_record.merge(
      last_seen_at: 6.minutes.from_now.iso8601
    )

    result = @importer.call(records: [record])

    assert_equal 0, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 0, PriceObservation.count
  end

  test "rejects unknown retailers without importing them" do
    record = @sample_record.merge(retailer: "unknown_store")

    result = @importer.call(records: [record])

    assert_equal 0, result[:imported_count]
    assert_equal 1, result[:failed_count]
  end

  test "imports records from a Loyalty Hub API response envelope" do
    response_data = {
      data: [@sample_record],
      meta: {
        count: 1,
        total: 1,
        limit: 10,
        offset: 0,
        has_more: false,
        next_offset: nil
      }
    }

    result = @importer.call(records: response_data)

    assert_equal 1, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 0, result[:failed_count]
    assert Product.exists?(barcode: "6001342201500")
  end

  test "preserves provider metadata from the API response envelope" do
    metadata = {
      count: 1,
      total: 25,
      limit: 10,
      offset: 0,
      has_more: true,
      next_offset: 10
    }

    result = @importer.call(
      records: {
        data: [@sample_record],
        meta: metadata
      }
    )

    assert_equal metadata, result[:provider_meta]
  end

  test "rejects an API response envelope without data" do
    assert_raises(ArgumentError) do
      @importer.call(records: { meta: { total: 10 } })
    end
  end

  test "rejects records that are not an array" do
    assert_raises(ArgumentError) do
      @importer.call(records: "not an array")
    end
  end

    test "prefers department over category when department is available" do
    record = @sample_record.merge(
      department: "dairy-eggs",
      category: "New In"
    )

    @importer.call(records: [record])

    assert_equal "dairy-eggs", Product.last.category
  end

  test "falls back to category when department is missing" do
    record = @sample_record.merge(
      category: "food"
    )

    @importer.call(records: [record])

    assert_equal "food", Product.last.category
  end

    test "imports an in-stock status from Loyalty Hub" do
    record = @sample_record.merge(in_stock: true)

    @importer.call(records: [record])

    assert_equal true, RetailerProduct.last.in_stock
  end

  test "imports the product image URL from Loyalty Hub" do
  image_url = "https://example.com/product-image.jpg"
  record = @sample_record.merge(image_url: image_url)

  @importer.call(records: [record])

  assert_equal image_url, RetailerProduct.last.image_url
end

  test "imports an out-of-stock status from Loyalty Hub" do
    record = @sample_record.merge(in_stock: false)

    @importer.call(records: [record])

    assert_equal false, RetailerProduct.last.in_stock
  end

  test "leaves stock availability unknown when Loyalty Hub omits it" do
    @importer.call(records: [@sample_record])

    assert_nil RetailerProduct.last.in_stock
  end
end
