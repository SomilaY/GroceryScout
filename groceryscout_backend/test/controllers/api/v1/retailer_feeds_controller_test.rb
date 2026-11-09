
require "test_helper"

class Api::V1::RetailerFeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
  @retailer = Retailer.create!(
    name: "Checkers",
    slug: "checkers",
    website_url: "https://www.checkers.co.za",
    active: true
  )

    @credential, @raw_token =
      RetailerApiCredential.issue_for!(retailer: @retailer)
  end

  test "rejects requests without an API key" do
    post "/api/v1/retailer_feeds/import",
         params: { records: [] }

    assert_response :unauthorized
    assert_equal(
      "Invalid or missing retailer API key",
      response.parsed_body["error"]
    )
  end

  test "rejects requests with an invalid API key" do
    post "/api/v1/retailer_feeds/import",
         params: { records: [] },
         headers: {
           "X-Retailer-API-Key" => "invalid-token"
         }

    assert_response :unauthorized
  end

  test "rejects revoked API credentials" do
    @credential.revoke!

    post "/api/v1/retailer_feeds/import",
         params: { records: [] },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :unauthorized
  end

  test "rejects credentials belonging to inactive retailers" do
    @retailer.update!(active: false)

    post "/api/v1/retailer_feeds/import",
         params: { records: [] },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :unauthorized
  end

  test "accepts valid credentials and rejects a non-array records payload" do
    post "/api/v1/retailer_feeds/import",
         params: { records: "not-an-array" },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :unprocessable_entity
    assert_equal(
      "Records must be an array",
      response.parsed_body["error"]
    )

    assert_not_nil @credential.reload.last_used_at
  end


  test "imports a product, price and image using a valid retailer key" do
    post "/api/v1/retailer_feeds/import",
         params: {
           records: [
             {
               barcode: "6009876543210",
               name: "Fresh Full Cream Milk",
               brand: "Test Dairy",
               quantity_value: 2,
               quantity_unit: "litre",
               category: "Dairy",
               retailer_sku: "TEST-MILK-001",
               listing_name: "Fresh Full Cream Milk 2L",
               product_url: "https://example.com/milk",
               image_url: "https://example.com/milk.jpg",
               price_cents: 3299,
               currency: "ZAR",
               observed_at: Time.current.iso8601
             }
           ]
         },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :success

    body = response.parsed_body

    assert_equal 1, body["total"]
    assert_equal 1, body["imported_count"]
    assert_equal 0, body["failed_count"]

    product = Product.find_by!(barcode: "6009876543210")

    assert_equal "Fresh Full Cream Milk", product.name
    assert_equal "Test Dairy", product.brand

    listing = RetailerProduct.find_by!(
      retailer: @retailer,
      product: product
    )

    assert_equal "TEST-MILK-001", listing.retailer_sku
    assert_equal "https://example.com/milk.jpg", listing.image_url
    assert_equal "https://example.com/milk", listing.product_url

    observation = PriceObservation.find_by!(
      retailer_product: listing
    )

    assert_equal 3299, observation.price_cents
    assert_equal "ZAR", observation.currency
    assert_equal "partner_api:#{@credential.id}", observation.source
  end

  test "uses the authenticated retailer regardless of submitted retailer information" do
  post "/api/v1/retailer_feeds/import",
       params: {
         records: [
           {
             barcode: "6009876543211",
             name: "Test Milk",
             retailer_slug: "shoprite",
             retailer_id: 999,
             retailer_sku: "CHK-MILK-002",
             price_cents: 2999
           }
         ]
       },
       headers: {
         "X-Retailer-API-Key" => @raw_token
       }

  assert_response :success

  product = Product.find_by!(barcode: "6009876543211")

  listing = RetailerProduct.find_by!(product: product)

  assert_equal @retailer.id, listing.retailer_id
  assert_equal "checkers", listing.retailer.slug
end


  test "imports a CSV file using a valid retailer API key" do
    file = fixture_file_upload(
      "checkers_feed.csv",
      "text/csv"
    )

    post "/api/v1/retailer_feeds/import",
         params: { file: file },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :success

    body = response.parsed_body

    assert_equal 1, body["total"]
    assert_equal 1, body["imported_count"]
    assert_equal 0, body["failed_count"]

    product = Product.find_by!(
      barcode: "6009876543220"
    )

    assert_equal "Fresh Full Cream Milk", product.name

    listing = RetailerProduct.find_by!(
      retailer: @retailer,
      product: product
    )

    assert_equal "CHK-MILK-003", listing.retailer_sku
    assert_equal "https://example.com/milk.jpg", listing.image_url

    observation = PriceObservation.find_by!(
      retailer_product: listing
    )

    assert_equal 3299, observation.price_cents
    assert_equal "partner_csv:#{@credential.id}", observation.source
  end

  test "rejects CSV uploads without a retailer API key" do
    file = fixture_file_upload(
      "checkers_feed.csv",
      "text/csv"
    )

    post "/api/v1/retailer_feeds/import",
         params: { file: file }

    assert_response :unauthorized
  end

 test "rejects CSV uploads with an incorrect file extension" do
  file = fixture_file_upload(
    "checkers_feed.txt",
    "text/plain"
  )

  post "/api/v1/retailer_feeds/import",
       params: { file: file },
       headers: {
         "X-Retailer-API-Key" => @raw_token
       }

  assert_response :unprocessable_entity

  assert_equal(
    "Please upload a CSV file",
    response.parsed_body["error"]
  )
end



end
