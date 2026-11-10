
require "test_helper"
require "stringio"

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


  test "returns a controlled error for malformed JSON" do
    post "/api/v1/retailer_feeds/import",
         params: '{"records": [',
         headers: {
           "Content-Type" => "application/json",
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :bad_request
    assert_equal "application/json", response.media_type
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

  test "rejects JSON import request bodies larger than 5 MB" do
  oversized_value = "a" * (5 * 1024 * 1024)

  payload = {
    records: [],
    padding: oversized_value
  }.to_json

  post "/api/v1/retailer_feeds/import",
       params: payload,
       headers: {
         "Content-Type" => "application/json",
         "X-Retailer-API-Key" => @raw_token
       }

  assert_response :content_too_large

  assert_equal(
    "JSON request body cannot exceed 5 MB",
    response.parsed_body["error"]
  )
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


  test "rejects JSON imports containing more than 10,000 records" do
    records = Array.new(10_001) do |index|
      {
        barcode: "600987654#{index.to_s.rjust(4, '0')}",
        name: "Test Product #{index}",
        price_cents: 2999
      }
    end

    post "/api/v1/retailer_feeds/import",
     params: { records: records },
     headers: {
       "X-Retailer-API-Key" => @raw_token
     },
     as: :json

    assert_response :unprocessable_entity

    assert_equal(
      "JSON import cannot contain more than 10,000 records",
      response.parsed_body["error"]
    )

    assert_equal 0, Product.count
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
               observed_at: Time.current.iso8601,
               in_stock: true
             }
           ]
         },
                 headers: {
           "X-Retailer-API-Key" => @raw_token
         },
         as: :json

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
    assert_equal true, listing.in_stock

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
             price_cents: 2999,
              admin: true,
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


  test "imports an out-of-stock product through the JSON API" do
    post "/api/v1/retailer_feeds/import",
         params: {
           records: [
             {
               barcode: "6009876543220",
               name: "Out of Stock Milk",
               retailer_sku: "TEST-MILK-OUT-001",
               price_cents: 3299,
               in_stock: false
             }
           ]
         },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         },
         as: :json

    assert_response :success

    body = response.parsed_body

    assert_equal 1, body["imported_count"]
    assert_equal 0, body["failed_count"]

    product = Product.find_by!(barcode: "6009876543220")
    listing = RetailerProduct.find_by!(
      retailer: @retailer,
      product: product
    )

    assert_equal false, listing.in_stock
    assert_equal 3299, listing.price_observations.order(observed_at: :desc).first.price_cents
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


 
  test "rejects CSV files larger than 5 MB" do
    Tempfile.create(["oversized", ".csv"]) do |tempfile|
      tempfile.write("a" * (5.megabytes + 1))
      tempfile.rewind

      file = Rack::Test::UploadedFile.new(
        tempfile.path,
        "text/csv"
      )

      post "/api/v1/retailer_feeds/import",
           params: { file: file },
           headers: {
             "X-Retailer-API-Key" => @raw_token
           }

      assert_response :unprocessable_entity

      assert_equal(
        "CSV file cannot exceed 5 MB",
        response.parsed_body["error"]
      )

      assert_equal 0, Product.count
    end
  end


  
  test "rejects CSV files containing more than 10,000 data rows" do
    rows = Array.new(
      10_001,
      "6009876543210,Test Milk,2999"
    )

    csv = (["barcode,name,price_cents"] + rows).join("\n")

    Tempfile.create(["too_many_rows", ".csv"]) do |tempfile|
      tempfile.write(csv)
      tempfile.rewind

      file = Rack::Test::UploadedFile.new(
        tempfile.path,
        "text/csv"
      )

      post "/api/v1/retailer_feeds/import",
           params: { file: file },
           headers: {
             "X-Retailer-API-Key" => @raw_token
           }

      assert_response :unprocessable_entity

      assert_equal(
        "CSV cannot contain more than 10,000 data rows",
        response.parsed_body["error"]
      )

      assert_equal 0, Product.count
    end
  end

test "rate limits import requests per retailer credential" do
 Api::V1::RetailerFeedsController.cache_store.clear

  20.times do
    post "/api/v1/retailer_feeds/import",
         params: { records: "not-an-array" },
         headers: {
           "X-Retailer-API-Key" => @raw_token
         }

    assert_response :unprocessable_entity
  end

  post "/api/v1/retailer_feeds/import",
       params: { records: "not-an-array" },
       headers: {
         "X-Retailer-API-Key" => @raw_token
       }

  assert_response :too_many_requests
  assert_equal(
    "Too many import requests. Please try again later.",
    response.parsed_body["error"]
  )
ensure
  Api::V1::RetailerFeedsController.cache_store.clear
end

end
