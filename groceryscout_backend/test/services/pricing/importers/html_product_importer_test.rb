require "test_helper"

class Pricing::Importers::HtmlProductImporterTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Checkers",
      slug: "checkers",
      website_url: "https://www.checkers.co.za",
      active: true
    )

    @html = <<~HTML
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
  end

  test "imports product information extracted from HTML" do
    importer = Pricing::Importers::HtmlProductImporter.new(
      retailer_slug: "checkers"
    )

    listing = importer.call(
      html: @html,
      product_url: "https://www.checkers.co.za/product/clover-milk"
    )

    assert_equal "Clover Full Cream Milk 2L", listing.product.name
    assert_equal 2.0, listing.product.quantity_value
    assert_equal "l", listing.product.quantity_unit
    assert_equal(
      "https://www.checkers.co.za/product/clover-milk",
      listing.product_url
    )

    assert_equal 2999, listing.price_observations.order(:created_at).last.price_cents
  end

  test "rejects HTML without a product name" do
    importer = Pricing::Importers::HtmlProductImporter.new(
      retailer_slug: "checkers"
    )

    error = assert_raises(ArgumentError) do
      importer.call(
        html: "<html><body>No product information</body></html>",
        product_url: "https://www.checkers.co.za/product/example"
      )
    end

    assert_equal "Product name could not be extracted", error.message
  end

  test "rejects HTML without a product price" do
    importer = Pricing::Importers::HtmlProductImporter.new(
      retailer_slug: "checkers"
    )

    html = <<~HTML
      <html>
        <body>
          <h1>Test Product 500g</h1>
        </body>
      </html>
    HTML

    error = assert_raises(ArgumentError) do
      importer.call(
        html: html,
        product_url: "https://www.checkers.co.za/product/example"
      )
    end

    assert_equal "Product price could not be extracted", error.message
  end

  test "rejects missing product URL" do
    importer = Pricing::Importers::HtmlProductImporter.new(
      retailer_slug: "checkers"
    )

    error = assert_raises(ArgumentError) do
      importer.call(html: @html, product_url: "")
    end

    assert_equal "Product URL is required", error.message
  end

  test "rejects unsupported retailers" do
    error = assert_raises(ArgumentError) do
      Pricing::Importers::HtmlProductImporter.new(
        retailer_slug: "unknown-retailer"
      )
    end

    assert_equal "Unsupported retailer", error.message
  end
end
class Pricing::Importers::CheckersHtmlFixtureTest < ActiveSupport::TestCase
  test "imports a Checkers product from the saved HTML fixture" do
    Retailer.create!(
      name: "Checkers",
      slug: "checkers",
      website_url: "https://www.checkers.co.za",
      active: true
    )

    html = Rails.root.join(
      "test/fixtures/pricing/checkers/product_page.html"
    ).read

    importer = Pricing::Importers::HtmlProductImporter.new(
      retailer_slug: "checkers"
    )

    listing = importer.call(
      html: html,
      product_url: "https://www.checkers.co.za/product/clover-milk"
    )

    assert_equal "Clover Full Cream Milk 2L", listing.product.name
    assert_equal 2.0, listing.product.quantity_value
    assert_equal "l", listing.product.quantity_unit
    assert_equal 2999, listing.price_observations.last.price_cents
  end
end
