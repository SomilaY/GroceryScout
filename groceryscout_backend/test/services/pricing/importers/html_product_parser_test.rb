require "test_helper"

class Pricing::Importers::HtmlProductParserTest < ActiveSupport::TestCase
  test "extracts product name, price and size from product HTML" do
    html = <<~HTML
      <html>
        <head>
          <meta property="og:title" content="Clover Full Cream Milk 2L">
          <meta property="product:price:amount" content="29.99">
        </head>
        <body>
          <h1>Clover Full Cream Milk 2L</h1>
        </body>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal "Clover Full Cream Milk 2L", result[:name]
    assert_equal 2999, result[:price_cents]
    assert_equal 2.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end

  test "extracts price from itemprop when product price metadata is absent" do
    html = <<~HTML
      <html>
        <body>
          <h1>Albany White Bread 700g</h1>
          <span itemprop="price" content="18.99">R18.99</span>
        </body>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal "Albany White Bread 700g", result[:name]
    assert_equal 1899, result[:price_cents]
    assert_equal 0.7, result[:quantity_value]
assert_equal "kg", result[:quantity_unit]
  end

 test "converts millilitres into litres" do
  html = <<~HTML
    <html>
      <body>
        <h1>Sunlight Dishwashing Liquid 2000ml</h1>
      </body>
    </html>
  HTML

  result = Pricing::Importers::HtmlProductParser.new(
    html: html
  ).call

  assert_equal 2.0, result[:quantity_value]
  assert_equal "l", result[:quantity_unit]
end

test "converts grams into kilograms" do
  html = <<~HTML
    <html>
      <body>
        <h1>Flour 1000g</h1>
      </body>
    </html>
  HTML

  result = Pricing::Importers::HtmlProductParser.new(
    html: html
  ).call

  assert_equal 1.0, result[:quantity_value]
  assert_equal "kg", result[:quantity_unit]
end

  test "returns nil when product information is missing" do
    html = "<html><body><p>Welcome</p></body></html>"

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_nil result[:name]
    assert_nil result[:price_cents]
    assert_nil result[:quantity_value]
    assert_nil result[:quantity_unit]
  end

  test "returns nil for an invalid price" do
    html = <<~HTML
      <html>
        <head>
          <meta property="og:title" content="Test Product 500g">
          <meta property="product:price:amount" content="invalid">
        </head>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_nil result[:price_cents]
  end
end
class Pricing::Importers::HtmlProductParserJsonLdTest < ActiveSupport::TestCase
  test "extracts product name, price and size from JSON-LD" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@context": "https://schema.org",
              "@type": "Product",
              "name": "Clover Full Cream Milk 2L",
              "weight": "2 L",
              "offers": {
                "@type": "Offer",
                "price": "29.99",
                "priceCurrency": "ZAR"
              }
            }
          </script>
        </head>
        <body></body>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal "Clover Full Cream Milk 2L", result[:name]
    assert_equal 2999, result[:price_cents]
    assert_equal 2.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end

  test "extracts product data from JSON-LD when ordinary metadata is absent" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Product",
              "name": "Albany White Bread 700g",
              "weight": "700 g",
              "offers": {
                "price": "18.99"
              }
            }
          </script>
        </head>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal "Albany White Bread 700g", result[:name]
    assert_equal 1899, result[:price_cents]
    assert_equal 0.7, result[:quantity_value]
    assert_equal "kg", result[:quantity_unit]
  end
end

class Pricing::Importers::HtmlProductParserExtendedSizesTest < ActiveSupport::TestCase
  test "recognises litre written as a word" do
    result = parse_product("Fresh Milk 1 litre")

    assert_equal 1.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end

  test "recognises litres written as a plural word" do
    result = parse_product("Fresh Milk 2 litres")

    assert_equal 2.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end

  test "recognises grams written as a word" do
    result = parse_product("Cake Flour 500 grams")

    assert_equal 0.5, result[:quantity_value]
    assert_equal "kg", result[:quantity_unit]
  end

  test "recognises decimal kilogram quantities" do
    result = parse_product("Rice 1.5 kg")

    assert_equal 1.5, result[:quantity_value]
    assert_equal "kg", result[:quantity_unit]
  end

  test "calculates total quantity for multipacks" do
    result = parse_product("Yoghurt 6 x 500ml")

    assert_equal 3.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end

  private

  def parse_product(name)
    html = "<html><body><h1>#{name}</h1></body></html>"

    Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call
  end
end

class Pricing::Importers::HtmlProductParserStructuredWeightTest < ActiveSupport::TestCase
  test "extracts quantity from structured JSON-LD weight" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Product",
              "name": "Clover Full Cream Milk",
              "weight": {
                "@type": "QuantitativeValue",
                "value": 2,
                "unitCode": "LTR"
              },
              "offers": {
                "price": "29.99"
              }
            }
          </script>
        </head>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal 2.0, result[:quantity_value]
    assert_equal "l", result[:quantity_unit]
  end
end

class Pricing::Importers::HtmlProductParserSouthAfricanPriceTest < ActiveSupport::TestCase
  test "extracts price with rand symbol" do
    assert_price "R29.99", 2999
  end

  test "extracts price with decimal comma" do
    assert_price "29,99", 2999
  end

  test "extracts price with thousands separator and decimal comma" do
    assert_price "1 299,99", 129999
  end

  test "extracts price with thousands separator and decimal point" do
    assert_price "1,299.99", 129999
  end

  private

  def assert_price(price, expected_cents)
    html = <<~HTML
      <html>
        <head>
          <meta property="og:title" content="Test Grocery Product">
        </head>
        <body>
          <span itemprop="price">#{price}</span>
        </body>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal expected_cents, result[:price_cents]
  end
end

class Pricing::Importers::HtmlProductParserMultipleOffersTest < ActiveSupport::TestCase
  test "finds a valid price when the first JSON-LD offer has no price" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Product",
              "name": "Clover Full Cream Milk 2L",
              "offers": [
                {
                  "@type": "Offer",
                  "availability": "https://schema.org/OutOfStock"
                },
                {
                  "@type": "Offer",
                  "price": "29.99",
                  "priceCurrency": "ZAR"
                }
              ]
            }
          </script>
        </head>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal 2999, result[:price_cents]
  end
end

class Pricing::Importers::HtmlProductParserInvalidOffersTest < ActiveSupport::TestCase
  test "skips invalid prices and finds the next valid offer" do
    html = <<~HTML
      <html>
        <head>
          <script type="application/ld+json">
            {
              "@type": "Product",
              "name": "Clover Full Cream Milk 2L",
              "offers": [
                {
                  "@type": "Offer",
                  "price": "Special"
                },
                {
                  "@type": "Offer",
                  "price": "-"
                },
                {
                  "@type": "Offer",
                  "price": "29.99"
                }
              ]
            }
          </script>
        </head>
      </html>
    HTML

    result = Pricing::Importers::HtmlProductParser.new(
      html: html
    ).call

    assert_equal 2999, result[:price_cents]
  end
end
