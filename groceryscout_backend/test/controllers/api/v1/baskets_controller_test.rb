
require "test_helper"

class Api::V1::BasketsControllerTest < ActionDispatch::IntegrationTest
 setup do
  @user = User.create!(
    name: "John Smith",
    email: "john.baskets@example.com",
    password: "password123"
  )

  @token = TokenService.encode(@user)

  @basket = @user.baskets.create!(
    name: "Test Basket"
  )

  @product = Product.create!(
    name: "Test Milk",
    brand: "Clover",
    category: "Dairy"
  )

  @basket.basket_items.create!(
    product: @product,
    quantity: 2
  )

  @checkers = Retailer.create!(
    name: "Checkers",
    slug: "checkers"
  )

  @pnp = Retailer.create!(
    name: "Pick n Pay",
    slug: "pick-n-pay"
  )

  @woolworths = Retailer.create!(
    name: "Woolworths",
    slug: "woolworths"
  )

  @checkers_listing = create_listing(@checkers, 2999)
  @pnp_listing = create_listing(@pnp, 3199)
  @woolworths_listing = create_listing(@woolworths, 3499)
end

  test "compares basket totals across retailers" do
    get_compare

    assert_response :success

    data = JSON.parse(response.body)

    totals = data["comparisons"].index_by { |comparison| comparison["retailer"] }

    assert_equal 5998, totals["Checkers"]["total_cents"]
    assert_equal 6398, totals["Pick n Pay"]["total_cents"]
    assert_equal 6998, totals["Woolworths"]["total_cents"]
  end

  test "identifies the cheapest retailer" do
    get_compare

    assert_response :success

    data = JSON.parse(response.body)

    assert_equal "Checkers", data["cheapest_retailer"]["name"]
    assert_equal 5998, data["cheapest_retailer"]["total_cents"]
  end

  test "marks a retailer incomplete when a product has no price" do
    @woolworths_listing.price_observations.destroy_all

   get_compare

    assert_response :success

    data = JSON.parse(response.body)

    woolworths = data["comparisons"].find do |comparison|
      comparison["retailer"] == "Woolworths"
    end

    assert_equal false, woolworths["complete"]
    assert_nil woolworths["total_cents"]
    assert_equal ["Test Milk"], woolworths["missing_items"]

    assert_equal "Checkers", data["cheapest_retailer"]["name"]
  end

    test "excludes stale prices from basket totals" do
    @checkers_listing.price_observations.first.update!(
      observed_at: 26.hours.ago
    )

    get_compare

    assert_response :success

    data = JSON.parse(response.body)

    checkers = data["comparisons"].find do |comparison|
      comparison["retailer"] == "Checkers"
    end

    assert_equal false, checkers["complete"]
    assert_nil checkers["total_cents"]
    assert_equal 1, checkers["stale_items"].length
    assert_equal "Test Milk", checkers["stale_items"][0]["product_name"]
    assert_equal 2999, checkers["stale_items"][0]["last_price_cents"]

    assert_equal "Pick n Pay", data["cheapest_retailer"]["name"]
    assert_equal 6398, data["cheapest_retailer"]["total_cents"]
  end

  test "does not identify a cheapest retailer for an empty basket" do
    @basket.basket_items.destroy_all

    get_compare

    assert_response :success

    data = JSON.parse(response.body)

    assert_nil data["cheapest_retailer"]
  end

  test "rejects requests without an authentication token" do
  get api_v1_basket_path(@basket)

  assert_response :unauthorized
end

test "rejects Basic authentication instead of Bearer" do
  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Basic #{@token}"
      }

  assert_response :unauthorized

  data = JSON.parse(response.body)
  assert_equal "Invalid authorization format", data["error"]
end

test "rejects malformed Bearer authorization headers" do
  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{@token} extra"
      }

  assert_response :unauthorized

  data = JSON.parse(response.body)
  assert_equal "Invalid authorization format", data["error"]
end

test "rejects Bearer authorization without a token" do
  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer "
      }

  assert_response :unauthorized
end

test "prevents another customer from viewing a basket" do
  another_user = User.create!(
    name: "Jane Smith",
    email: "jane.baskets@example.com",
    password: "password123"
  )

  another_token = TokenService.encode(another_user)

  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{another_token}"
      }

  assert_response :not_found
end

test "prevents another customer from comparing a basket" do
  another_user = User.create!(
    name: "Jane Smith",
    email: "jane.compare@example.com",
    password: "password123"
  )

  another_token = TokenService.encode(another_user)

  get compare_api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{another_token}"
      }

  assert_response :not_found
end

  test "creates a basket for the logged-in customer" do
    assert_difference("Basket.count", 1) do
      post api_v1_baskets_path,
           params: {
             basket: {
               name: "My New Basket"
             }
           },
           headers: {
             "Authorization" => "Bearer #{@token}"
           }
    end

    assert_response :created

    basket = Basket.order(:id).last

    assert_equal @user.id, basket.user_id
    assert_equal "My New Basket", basket.name
  end

  test "rejects basket creation without authentication" do
    assert_no_difference("Basket.count") do
      post api_v1_baskets_path,
           params: {
             basket: {
               name: "Unauthorized Basket"
             }
           }
    end

    assert_response :unauthorized
  end

  test "allows a customer to view their own basket" do
    get api_v1_basket_path(@basket),
        headers: {
          "Authorization" => "Bearer #{@token}"
        }

    assert_response :success
  end

  test "rejects an old token after password change" do
  @user.update!(password: "newpassword123")

  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{@token}"
      }

  assert_response :unauthorized

  data = JSON.parse(response.body)

  assert_equal "Your password has changed. Please log in again.", data["error"]
end

test "allows a new token after password change" do
  @user.update!(password: "newpassword123")

  new_token = TokenService.encode(@user)

  get api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{new_token}"
      }

  assert_response :success
end
  private

  def get_compare
  get compare_api_v1_basket_path(@basket),
      headers: {
        "Authorization" => "Bearer #{@token}"
      }
end

  def create_listing(retailer, price_cents)
    listing = RetailerProduct.create!(
      retailer: retailer,
      product: @product,
      listing_name: "Clover Full Cream Milk 2L"
    )

    listing.price_observations.create!(
      price_cents: price_cents,
      currency: "ZAR",
      observed_at: Time.current,
      source: "manual_test"
    )

    listing
  end
end
