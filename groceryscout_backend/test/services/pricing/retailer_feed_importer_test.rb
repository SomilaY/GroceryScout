require "test_helper"

class Pricing::RetailerFeedImporterTest < ActiveSupport::TestCase
  setup do
    @retailers = [
      ["Shoprite", "shoprite", "https://www.shoprite.co.za"],
      ["Checkers", "checkers", "https://www.checkers.co.za"],
      ["Pick n Pay", "pick-n-pay", "https://www.pnp.co.za"],
      ["Woolworths", "woolworths", "https://www.woolworths.co.za"]
    ]

    @retailers.each do |name, slug, website_url|
      Retailer.create!(
        name: name,
        slug: slug,
        website_url: website_url,
        active: true
      )
    end
  end

  test "imports products using the selected retailer adapter" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "checkers"
    )

    result = importer.call(
      records: [
        {
          barcode: "6001234567801",
          name: "Unified Import Test Milk",
          price_cents: 2999
        }
      ]
    )

    assert_equal 1, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 0, result[:failed_count]
  end

  test "imports products without barcodes when retailer identifiers are provided" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "checkers"
    )

    result = importer.call(
      records: [
        {
          barcode: "",
          name: "Milk Without Barcode",
          quantity_value: 2,
          quantity_unit: "litre",
          retailer_sku: "CHK-NO-BARCODE-001",
          product_url: "https://example.com/checkers-milk",
          price_cents: 2999
        }
      ]
    )

    assert_equal 1, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 0, result[:failed_count]

    product = Product.find_by(name: "Milk Without Barcode")

    assert_not_nil product
    assert_nil product.barcode
    assert_equal 2, product.quantity_value
    assert_equal "litre", product.quantity_unit
  end

  test "continues importing when one record fails" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "shoprite"
    )

    result = importer.call(
      records: [
        {
          barcode: "6001234567802",
          name: "Valid Test Milk",
          price_cents: 2899
        },
        {
          barcode: "",
          name: "Invalid Test Milk",
          price_cents: 2999
        },
        {
          barcode: "6001234567803",
          name: "Another Valid Test Milk",
          price_cents: 3099
        }
      ]
    )

    assert_equal 3, result[:total]
    assert_equal 2, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 1, result[:failed].first[:index]
  end

    test "continues importing when a database uniqueness conflict occurs" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "shoprite"
    )

    adapter = importer.instance_variable_get(:@adapter)
    original_import = adapter.method(:import)
    calls = 0

    adapter.define_singleton_method(:import) do |record|
      calls += 1

      if calls == 1
        raise ActiveRecord::RecordNotUnique, "duplicate key"
      end

      original_import.call(record)
    end

    result = importer.call(
      records: [
        {
          barcode: "6001234567895",
          name: "Conflicting Milk",
          price_cents: 2999
        },
        {
          barcode: "6001234567896",
          name: "Successfully Imported Milk",
          price_cents: 3199
        }
      ]
    )

    assert_equal 2, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 1, result[:failed_count]
    assert_equal 0, result[:failed].first[:index]
    assert_equal "Successfully Imported Milk",
                 Product.find_by(barcode: "6001234567896").name
  end

  test "rejects unsupported retailers" do
    assert_raises(ArgumentError) do
      Pricing::RetailerFeedImporter.new(
        retailer_slug: "unknown-store"
      )
    end
  end

  test "rejects records that are not an array" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "checkers"
    )

    assert_raises(ArgumentError) do
      importer.call(records: "not an array")
    end
  end

    test "continues importing when records have unexpected formats" do
    importer = Pricing::RetailerFeedImporter.new(
      retailer_slug: "shoprite"
    )

    result = importer.call(
      records: [
        nil,
        "invalid record",
        123,
        {
          barcode: "6001234567894",
          name: "Valid Milk After Malformed Records",
          price_cents: 2999
        }
      ]
    )

    assert_equal 4, result[:total]
    assert_equal 1, result[:imported_count]
    assert_equal 3, result[:failed_count]

    assert_equal [0, 1, 2], result[:failed].map { |failure| failure[:index] }

    assert_equal "Valid Milk After Malformed Records",
                 Product.find_by(barcode: "6001234567894").name
  end
end