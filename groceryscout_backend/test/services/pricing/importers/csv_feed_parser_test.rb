require "test_helper"
require "stringio"

class Pricing::Importers::CsvFeedParserTest < ActiveSupport::TestCase
  test "parses a valid CSV into records" do
    csv = <<~CSV
      barcode,name,brand,price_cents
      6001234567890,Full Cream Milk,Clover,2999
      6001234567891,White Bread,Albany,1899
    CSV

    result = Pricing::Importers::CsvFeedParser.new(
      file: StringIO.new(csv)
    ).call

    assert_equal 2, result.length
    assert_equal "6001234567890", result[0][:barcode]
    assert_equal "Full Cream Milk", result[0][:name]
    assert_equal "Clover", result[0][:brand]
    assert_equal "2999", result[0][:price_cents]
  end

  test "accepts products without barcodes when a retailer identifier is provided" do
    csv = <<~CSV
      name,quantity_value,quantity_unit,retailer_sku,price_cents
      Full Cream Milk,2,litre,CHK-MILK-001,2999
    CSV

    result = Pricing::Importers::CsvFeedParser.new(
      file: StringIO.new(csv)
    ).call

    assert_equal 1, result.length
    assert_equal "Full Cream Milk", result.first[:name]
    assert_equal "2", result.first[:quantity_value]
    assert_equal "litre", result.first[:quantity_unit]
    assert_equal "CHK-MILK-001", result.first[:retailer_sku]
  end

  test "accepts uppercase and whitespace around headers" do
    csv = <<~CSV
      Barcode, Name , PRICE_CENTS
      6001234567890,Full Cream Milk,2999
    CSV

    result = Pricing::Importers::CsvFeedParser.new(
      file: StringIO.new(csv)
    ).call

    assert_equal "6001234567890", result.first[:barcode]
    assert_equal "Full Cream Milk", result.first[:name]
    assert_equal "2999", result.first[:price_cents]
  end

  test "rejects CSV files missing required headers" do
    csv = <<~CSV
      barcode,name
      6001234567890,Full Cream Milk
    CSV

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_includes error.message, "price_cents"
  end

  test "rejects rows without a barcode, retailer SKU or product URL" do
    csv = <<~CSV
      name,price_cents
      Full Cream Milk,2999
    CSV

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_includes error.message, "Barcode, retailer_sku or product_url"
  end

  test "rejects rows without a product name" do
    csv = <<~CSV
      barcode,name,price_cents
      6001234567890,,2999
    CSV

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_includes error.message, "Product name is required"
  end

  test "rejects unsupported headers" do
    csv = <<~CSV
      barcode,name,price_cents,retailer_id
      6001234567890,Full Cream Milk,2999,1
    CSV

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_includes error.message, "retailer_id"
  end

  test "rejects duplicate headers after normalisation" do
    csv = <<~CSV
      barcode, Barcode ,name,price_cents
      6001234567890,6001234567890,Milk,2999
    CSV

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_includes error.message, "duplicate"
  end

  test "rejects malformed CSV files" do
    csv = "barcode,name,price_cents\n6001234567890,\"Milk,2999"

    error = assert_raises(ArgumentError) do
      Pricing::Importers::CsvFeedParser.new(
        file: StringIO.new(csv)
      ).call
    end

    assert_equal "Invalid CSV file", error.message
  end
end