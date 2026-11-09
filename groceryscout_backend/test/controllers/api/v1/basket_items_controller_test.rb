
require "test_helper"

class Api::V1::BasketItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "John Smith",
      email: "john.items@example.com",
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
  end

  test "adds a product to a basket" do
    assert_difference("BasketItem.count", 1) do
      authenticated_post api_v1_basket_items_path(@basket),
                         params: {
                           product_id: @product.id,
                           quantity: 2
                         }
    end

    assert_response :created
  end

  test "increases quantity when the product already exists in the basket" do
    @basket.basket_items.create!(
      product: @product,
      quantity: 2
    )

    assert_no_difference("BasketItem.count") do
      authenticated_post api_v1_basket_items_path(@basket),
                         params: {
                           product_id: @product.id,
                           quantity: 1
                         }
    end

    assert_response :created
    assert_equal 3, @basket.basket_items.find_by!(product: @product).quantity
  end

  test "rejects a quantity of zero" do
    authenticated_post api_v1_basket_items_path(@basket),
                       params: {
                         product_id: @product.id,
                         quantity: 0
                       }

    assert_response :unprocessable_entity
  end

  test "rejects a missing product ID" do
  authenticated_post api_v1_basket_items_path(@basket),
                     params: { quantity: 1 }

  assert_response :bad_request
  assert_equal "A valid product ID is required",
               JSON.parse(response.body)["error"]
end

test "returns not found for an unknown product ID" do
  authenticated_post api_v1_basket_items_path(@basket),
                     params: {
                       product_id: 999999,
                       quantity: 1
                     }

  assert_response :not_found
  assert_equal "Product not found",
               JSON.parse(response.body)["error"]
end

test "rejects a non-numeric quantity" do
  authenticated_post api_v1_basket_items_path(@basket),
                     params: {
                       product_id: @product.id,
                       quantity: "abc"
                     }

  assert_response :bad_request
end

test "rejects a decimal quantity" do
  authenticated_post api_v1_basket_items_path(@basket),
                     params: {
                       product_id: @product.id,
                       quantity: "2.5"
                     }

  assert_response :bad_request
end

  test "updates the quantity of a basket item" do
    item = @basket.basket_items.create!(
      product: @product,
      quantity: 3
    )

    authenticated_patch api_v1_basket_item_path(@basket, item),
                        params: { quantity: 2 }

    assert_response :success
    assert_equal 2, item.reload.quantity
  end

  test "rejects updating a basket item to quantity zero" do
    item = @basket.basket_items.create!(
      product: @product,
      quantity: 3
    )

    authenticated_patch api_v1_basket_item_path(@basket, item),
                        params: { quantity: 0 }

    assert_response :unprocessable_entity
    assert_equal 3, item.reload.quantity
  end

  test "removes a product from a basket" do
    item = @basket.basket_items.create!(
      product: @product,
      quantity: 2
    )

    assert_difference("BasketItem.count", -1) do
      authenticated_delete api_v1_basket_item_path(@basket, item)
    end

    assert_response :success
  end

  test "cannot remove an item belonging to another basket" do
    another_basket = @user.baskets.create!(name: "Another Basket")

    item = another_basket.basket_items.create!(
      product: @product,
      quantity: 2
    )

    assert_no_difference("BasketItem.count") do
      authenticated_delete api_v1_basket_item_path(@basket, item)
    end

    assert_response :not_found
  end

  test "rejects adding items without authentication" do
  assert_no_difference("BasketItem.count") do
    post api_v1_basket_items_path(@basket),
         params: {
           product_id: @product.id,
           quantity: 1
         },
         as: :json
  end

  assert_response :unauthorized
end

test "prevents another customer from adding items to a basket" do
  another_user = User.create!(
    name: "Jane Smith",
    email: "jane.items@example.com",
    password: "password123"
  )

  another_token = TokenService.encode(another_user)

  assert_no_difference("BasketItem.count") do
    post api_v1_basket_items_path(@basket),
         params: {
           product_id: @product.id,
           quantity: 1
         },
         headers: {
           "Authorization" => "Bearer #{another_token}"
         },
         as: :json
  end

  assert_response :not_found
end

test "prevents another customer from updating a basket item" do
  another_user = User.create!(
    name: "Jane Smith",
    email: "jane.update@example.com",
    password: "password123"
  )

  another_token = TokenService.encode(another_user)

  item = @basket.basket_items.create!(
    product: @product,
    quantity: 2
  )

  patch api_v1_basket_item_path(@basket, item),
        params: { quantity: 10 },
        headers: {
          "Authorization" => "Bearer #{another_token}"
        },
        as: :json

  assert_response :not_found
  assert_equal 2, item.reload.quantity
end

test "prevents another customer from deleting a basket item" do
  another_user = User.create!(
    name: "Jane Smith",
    email: "jane.delete@example.com",
    password: "password123"
  )

  another_token = TokenService.encode(another_user)

  item = @basket.basket_items.create!(
    product: @product,
    quantity: 2
  )

  assert_no_difference("BasketItem.count") do
    delete api_v1_basket_item_path(@basket, item),
           headers: {
             "Authorization" => "Bearer #{another_token}"
           }
  end

  assert_response :not_found
  assert_equal 2, item.reload.quantity
end

  private

  def authenticated_post(path, params:)
    post path,
         params: params,
         headers: { "Authorization" => "Bearer #{@token}" },
         as: :json
  end

  def authenticated_patch(path, params:)
    patch path,
          params: params,
          headers: { "Authorization" => "Bearer #{@token}" },
          as: :json
  end

  def authenticated_delete(path)
    delete path,
           headers: { "Authorization" => "Bearer #{@token}" }
  end
end
