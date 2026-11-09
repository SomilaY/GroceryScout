require "test_helper"

class Api::V1::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @checkers = Retailer.create!(
      name: "Checkers",
      slug: "checkers"
    )

    @pick_n_pay = Retailer.create!(
      name: "Pick n Pay",
      slug: "pick-n-pay"
    )

    @woolworths = Retailer.create!(
      name: "Woolworths",
      slug: "woolworths"
    )

    @milk = Product.create!(
      name: "Full Cream Milk",
      brand: "Clover",
      barcode: "6001234567890",
      quantity_value: 2.0,
      quantity_unit: "litre",
      category: "Dairy"
    )

    @checkers_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: @milk,
      listing_name: "Clover Full Cream Milk 2L"
    )

    @pick_n_pay_listing = RetailerProduct.create!(
      retailer: @pick_n_pay,
      product: @milk,
      listing_name: "Clover Full Cream Milk 2L"
    )

    @woolworths_listing = RetailerProduct.create!(
      retailer: @woolworths,
      product: @milk,
      listing_name: "Clover Full Cream Milk 2L"
    )

    PriceObservation.create!(
      retailer_product: @checkers_listing,
      price_cents: 2999,
      observed_at: Time.current,
      source: "manual_test"
    )

    PriceObservation.create!(
      retailer_product: @pick_n_pay_listing,
      price_cents: 3199,
      observed_at: Time.current,
      source: "manual_test"
    )

    PriceObservation.create!(
      retailer_product: @woolworths_listing,
      price_cents: 3499,
      observed_at: Time.current,
      source: "manual_test"
    )
  end

  test "searches products by name" do
    get "/api/v1/products", params: { search: "milk" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Full Cream Milk", products.first["name"]
    assert_equal "Clover", products.first["brand"]
  end

  test "searches products by brand" do
    get "/api/v1/products", params: { search: "Clover" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Clover", products.first["brand"]
  end

  test "returns retailer prices from cheapest to most expensive" do
    get "/api/v1/products", params: { search: "milk" }

    assert_response :success

    products = JSON.parse(response.body)["products"]
    prices = products.first["prices"]

    assert_equal 3, prices.length

    assert_equal ["Checkers", "Pick n Pay", "Woolworths"],
                 prices.map { |price| price["retailer"] }

    assert_equal [29.99, 31.99, 34.99],
                 prices.map { |price| price["price"] }
  end

  test "does not include retailer listings without a price" do
    retailer = Retailer.create!(
      name: "Test Retailer",
      slug: "test-retailer"
    )

    RetailerProduct.create!(
  retailer: retailer,
  product: @milk,
  listing_name: "Clover Full Cream Milk 2L"
)

    get "/api/v1/products", params: { search: "milk" }

    assert_response :success

    products = JSON.parse(response.body)["products"]
    prices = products.first["prices"]

    retailer_names = prices.map { |price| price["retailer"] }

    assert_equal 3, prices.length
    assert_not_includes retailer_names, "Test Retailer"
  end

    test "returns the latest price observation for each retailer" do
    PriceObservation.create!(
      retailer_product: @checkers_listing,
      price_cents: 2799,
      observed_at: 1.hour.from_now,
      source: "manual_test"
    )

    get "/api/v1/products", params: { search: "milk" }

    assert_response :success

    products = JSON.parse(response.body)["products"]
    prices = products.first["prices"]

    checkers_price = prices.find do |price|
      price["retailer"] == "Checkers"
    end

    assert_equal 27.99, checkers_price["price"]
  end

    test "searches products by barcode" do
    get "/api/v1/products", params: { search: "6001234567890" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Full Cream Milk", products.first["name"]
  end

    test "searches products without being case sensitive" do
    get "/api/v1/products", params: { search: "MILK" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Full Cream Milk", products.first["name"]
  end

    test "identifies stale retailer prices" do
    @checkers_listing.price_observations.first.update!(
      observed_at: 26.hours.ago
    )

    get "/api/v1/products", params: { search: "milk" }

    assert_response :success

    products = JSON.parse(response.body)["products"]
    prices = products.first["prices"]

    checkers_price = prices.find do |price|
      price["retailer"] == "Checkers"
    end

    assert_equal false, checkers_price["fresh"]
    assert_equal "stale", checkers_price["status"]
    assert_equal 29.99, checkers_price["price"]
  end

    test "filters products by category" do
    Product.create!(
      name: "White Bread",
      brand: "Albany",
      category: "Bakery"
    )

    get "/api/v1/products", params: { category: "Dairy" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Full Cream Milk", products.first["name"]
  end

  test "filters products by category without being case sensitive" do
    get "/api/v1/products", params: { category: "dairy" }

    assert_response :success

    products = JSON.parse(response.body)["products"]

    assert_equal 1, products.length
    assert_equal "Dairy", products.first["category"]
  end

    test "returns pagination information" do
    get "/api/v1/products"

    assert_response :success

    response_data = JSON.parse(response.body)

    assert_equal 1, response_data["pagination"]["current_page"]
    assert_equal 20, response_data["pagination"]["per_page"]
    assert_equal 1, response_data["pagination"]["total_count"]
    assert_equal 1, response_data["pagination"]["total_pages"]
  end

  test "limits the number of products per page" do
    3.times do |i|
      Product.create!(
        name: "Test Product #{i}",
        category: "Test"
      )
    end

    get "/api/v1/products", params: { per_page: 2 }

    assert_response :success

    response_data = JSON.parse(response.body)

    assert_equal 2, response_data["products"].length
    assert_equal 2, response_data["pagination"]["per_page"]
    assert_equal 4, response_data["pagination"]["total_count"]
    assert_equal 2, response_data["pagination"]["total_pages"]
  end

  test "returns the correct products for the requested page" do
    Product.create!(
      name: "Apple",
      category: "Fruit"
    )

    Product.create!(
      name: "Banana",
      category: "Fruit"
    )

    get "/api/v1/products", params: { page: 2, per_page: 2 }

    assert_response :success

    response_data = JSON.parse(response.body)

        assert_equal 2, response_data["pagination"]["current_page"]
    assert_equal 1, response_data["products"].length
    assert_equal ["Full Cream Milk"],
                 response_data["products"].map { |product| product["name"] }
  end

    test "returns details for a specific product" do
    get "/api/v1/products/#{@milk.id}"

    assert_response :success

    response_data = JSON.parse(response.body)
    product = response_data["product"]

    assert_equal @milk.id, product["id"]
    assert_equal "Full Cream Milk", product["name"]
    assert_equal "Clover", product["brand"]
    assert_equal "2.0", product["quantity"]
    assert_equal "litre", product["unit"]
    assert_equal "Dairy", product["category"]

    assert_equal 3, product["prices"].length
    assert_equal ["Checkers", "Pick n Pay", "Woolworths"],
                 product["prices"].map { |price| price["retailer"] }
  end

  test "returns not found for a product that does not exist" do
    get "/api/v1/products/999999"

    assert_response :not_found

    response_data = JSON.parse(response.body)

    assert_equal "Product not found", response_data["error"]
  end

    test "returns price history grouped by retailer" do
    PriceObservation.create!(
      retailer_product: @checkers_listing,
      price_cents: 2899,
      observed_at: 7.days.ago,
      source: "manual_test"
    )

    get "/api/v1/products/#{@milk.id}/price_history"

    assert_response :success

    data = JSON.parse(response.body)

    assert_equal @milk.id, data["product"]["id"]
    assert_equal "Full Cream Milk", data["product"]["name"]
    assert_equal 30, data["period_days"]

    checkers = data["retailers"].find do |retailer|
      retailer["retailer"] == "Checkers"
    end

    assert_equal 2, checkers["prices"].length
    assert_equal [2899, 2999],
                 checkers["prices"].map { |price| price["price_cents"] }
  end

  test "filters price history by requested number of days" do
    PriceObservation.create!(
      retailer_product: @checkers_listing,
      price_cents: 2799,
      observed_at: 40.days.ago,
      source: "manual_test"
    )

    PriceObservation.create!(
      retailer_product: @checkers_listing,
      price_cents: 2899,
      observed_at: 7.days.ago,
      source: "manual_test"
    )

    get "/api/v1/products/#{@milk.id}/price_history",
        params: { days: 30 }

    assert_response :success

    data = JSON.parse(response.body)

    checkers = data["retailers"].find do |retailer|
      retailer["retailer"] == "Checkers"
    end

    prices = checkers["prices"].map do |price|
      price["price_cents"]
    end

    assert_equal [2899, 2999], prices
  end

  test "returns not found for price history of a missing product" do
    get "/api/v1/products/999999/price_history"

    assert_response :not_found

    data = JSON.parse(response.body)

    assert_equal "Product not found", data["error"]
  end
  
     test "sorts products by name ascending" do
    Product.create!(name: "Apple", category: "Fruit")
    Product.create!(name: "Banana", category: "Fruit")

    get "/api/v1/products", params: { sort: "name_asc" }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Apple", "Banana", "Full Cream Milk"], names
  end

  test "sorts products by name descending" do
    Product.create!(name: "Apple", category: "Fruit")
    Product.create!(name: "Banana", category: "Fruit")

    get "/api/v1/products", params: { sort: "name_desc" }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Full Cream Milk", "Banana", "Apple"], names
  end

  test "sorts products by cheapest fresh price" do
    apple = Product.create!(name: "Apple", category: "Fruit")
    bread = Product.create!(name: "Bread", category: "Bakery")

    apple_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: apple,
      listing_name: "Apple"
    )

    bread_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: bread,
      listing_name: "Bread"
    )

    PriceObservation.create!(
      retailer_product: apple_listing,
      price_cents: 1500,
      observed_at: Time.current,
      source: "manual_test"
    )

    PriceObservation.create!(
      retailer_product: bread_listing,
      price_cents: 1000,
      observed_at: Time.current,
      source: "manual_test"
    )

    get "/api/v1/products", params: { sort: "price_asc" }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Bread", "Apple", "Full Cream Milk"], names
  end

  test "sorts products by highest fresh price" do
    apple = Product.create!(name: "Apple", category: "Fruit")

    apple_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: apple,
      listing_name: "Apple"
    )

    PriceObservation.create!(
      retailer_product: apple_listing,
      price_cents: 5000,
      observed_at: Time.current,
      source: "manual_test"
    )

    get "/api/v1/products", params: { sort: "price_desc" }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Apple", "Full Cream Milk"], names
  end

    test "filters products by minimum price" do
    apple = Product.create!(
      name: "Apple",
      category: "Fruit"
    )

    listing = RetailerProduct.create!(
      retailer: @checkers,
      product: apple,
      listing_name: "Apple"
    )

    PriceObservation.create!(
      retailer_product: listing,
      price_cents: 1500,
      observed_at: Time.current,
      source: "manual_test"
    )

    get "/api/v1/products", params: { min_price: 20 }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Full Cream Milk"], names
  end

  test "filters products by maximum price" do
    apple = Product.create!(
      name: "Apple",
      category: "Fruit"
    )

    listing = RetailerProduct.create!(
      retailer: @checkers,
      product: apple,
      listing_name: "Apple"
    )

    PriceObservation.create!(
      retailer_product: listing,
      price_cents: 1500,
      observed_at: Time.current,
      source: "manual_test"
    )

    get "/api/v1/products", params: { max_price: 20 }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Apple"], names
  end

  test "filters products between minimum and maximum prices" do
    apple = Product.create!(
      name: "Apple",
      category: "Fruit"
    )

    bread = Product.create!(
      name: "Bread",
      category: "Bakery"
    )

    apple_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: apple,
      listing_name: "Apple"
    )

    bread_listing = RetailerProduct.create!(
      retailer: @checkers,
      product: bread,
      listing_name: "Bread"
    )

    PriceObservation.create!(
      retailer_product: apple_listing,
      price_cents: 1500,
      observed_at: Time.current,
      source: "manual_test"
    )

    PriceObservation.create!(
      retailer_product: bread_listing,
      price_cents: 2500,
      observed_at: Time.current,
      source: "manual_test"
    )

    get "/api/v1/products",
        params: { min_price: 20, max_price: 30 }

    assert_response :success

    names = JSON.parse(response.body)["products"].map do |product|
      product["name"]
    end

    assert_equal ["Bread", "Full Cream Milk"], names
  end

    test "rejects non-numeric minimum price" do
    get "/api/v1/products", params: { min_price: "abc" }

    assert_response :bad_request
    assert_equal "Invalid minimum price", JSON.parse(response.body)["error"]
  end

  test "rejects negative minimum price" do
    get "/api/v1/products", params: { min_price: -10 }

    assert_response :bad_request
    assert_equal "Invalid minimum price", JSON.parse(response.body)["error"]
  end

  test "rejects non-numeric maximum price" do
    get "/api/v1/products", params: { max_price: "abc" }

    assert_response :bad_request
    assert_equal "Invalid maximum price", JSON.parse(response.body)["error"]
  end

  test "rejects minimum price greater than maximum price" do
    get "/api/v1/products",
        params: { min_price: 50, max_price: 20 }

    assert_response :bad_request
    assert_equal(
      "Minimum price cannot exceed maximum price",
      JSON.parse(response.body)["error"]
    )
  end
end