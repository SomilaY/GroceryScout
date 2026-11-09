require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Product.create!(
      name: "Full Cream Milk",
      brand: "Clover",
      barcode: "6001234567890",
      quantity_value: 2,
      quantity_unit: "litre",
      category: "Dairy"
    )

    Product.create!(
      name: "White Bread",
      brand: "Albany",
      barcode: "6001234567891",
      quantity_value: 700,
      quantity_unit: "g",
      category: "Bakery"
    )

    Product.create!(
      name: "Brown Bread",
      brand: "Albany",
      barcode: "6001234567892",
      quantity_value: 700,
      quantity_unit: "g",
      category: "Bakery"
    )
  end

  test "returns unique categories in alphabetical order" do
    get "/api/v1/categories"

    assert_response :success

    categories = JSON.parse(response.body)["categories"]

    assert_equal ["Bakery", "Dairy"], categories
  end

  test "does not return blank or missing categories" do
    Product.create!(
      name: "Uncategorised Product",
      category: nil
    )

    Product.create!(
      name: "Product With Blank Category",
      category: ""
    )

    get "/api/v1/categories"

    assert_response :success

    categories = JSON.parse(response.body)["categories"]

    assert_equal ["Bakery", "Dairy"], categories
  end
end