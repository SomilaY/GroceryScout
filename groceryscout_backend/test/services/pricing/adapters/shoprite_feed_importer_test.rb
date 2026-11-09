
require "test_helper"

class Pricing::Adapters::ShopriteFeedImporterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Shoprite",
      slug: "shoprite",
      website_url: "https://www.shoprite.co.za",
      active: true
    )

    @importer = Pricing::Adapters::ShopriteFeedImporter.new
  end

  test "imports multiple valid records" do
    records = [
      {
        barcode: "6000000000101",
        name: "Shoprite Test Milk",
        brand: "Clover",
        quantity_value: 2,
        quantity_unit: "litre",
        category: "Dairy",
        retailer_sku: "SHO-BATCH-001",
        price_cents: 2999
      },
      {
        barcode: "6000000000102",
        name: "Shoprite Test Bread",
        brand: "Albany",
        quantity_value: 700,
        quantity_unit: "gram",
        category: "Bakery",
        retailer_sku: "SHO-BATCH-002",
        price_cents: 1899
      }
    ]

    result = @importer.call(records: records)

    assert_equal 2, result[:total]
    assert_equal 2, result[:imported_count]
    assert_equal 0, result[:failed_count]
    assert_equal 2, result[:imported].length
    assert_equal 0, result[:failed].length
  end

  test "continues importing after an invalid record" do
    records = [
      {
        barcode: "6000000000201",
        name: "Valid Milk",
        retailer_sku: "SHO-BATCH-003",
        price_cents: 2999
      },
      {
  barcode: "",
  name: "Invalid Product",
  retailer_sku: "",
  product_url: "",
  price_cents: 1999
},
      {
        barcode: "6000000000202",
        name: "Valid Bread",
        retailer_sku: "SHO-BATCH-005",
        price_cents: 1899
      }
    ]

    result = @importer.call(records: records)

    assert_equal 3, result[:total]
    assert_equal 2, result[:imported_count]
    assert_equal 1, result[:failed_count]

    assert_equal 2, result[:imported].length
    assert_equal 1, result[:failed].length

    assert_equal 1, result[:failed].first[:index]
    assert_equal "Barcode, product URL or retailer SKU is required", result[:failed].first[:error]
  end

  test "rejects records that are not an array" do
    error = assert_raises(ArgumentError) do
      @importer.call(records: "not an array")
    end

    assert_equal "Records must be an array", error.message
  end
end
