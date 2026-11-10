require "test_helper"

class RetailerProductTest < ActiveSupport::TestCase
  setup do
    @retailer = Retailer.create!(
      name: "Shoprite",
      slug: "shoprite"
    )

    @product = Product.create!(
      name: "Full Cream Milk"
    )
  end

  test "rejects duplicate product URLs for the same retailer" do
    RetailerProduct.create!(
      retailer: @retailer,
      product: @product,
      listing_name: "Milk 2L",
      product_url: "https://shoprite.example/milk"
    )

    another_product = Product.create!(
      name: "Low Fat Milk"
    )

    duplicate = RetailerProduct.new(
      retailer: @retailer,
      product: another_product,
      listing_name: "Low Fat Milk 2L",
      product_url: "https://shoprite.example/milk"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:product_url], "has already been taken"
  end

  test "allows the same product URL for different retailers" do
    RetailerProduct.create!(
      retailer: @retailer,
      product: @product,
      listing_name: "Milk 2L",
      product_url: "https://example.com/milk"
    )

    another_retailer = Retailer.create!(
      name: "Checkers",
      slug: "checkers"
    )

    listing = RetailerProduct.new(
      retailer: another_retailer,
      product: @product,
      listing_name: "Milk 2L",
      product_url: "https://example.com/milk"
    )

    assert listing.valid?
  end

  test "allows multiple retailer listings without a product URL" do
    first_product = @product

    second_product = Product.create!(
      name: "Low Fat Milk"
    )

    first_listing = RetailerProduct.create!(
      retailer: @retailer,
      product: first_product,
      listing_name: "Full Cream Milk"
    )

    second_listing = RetailerProduct.create!(
      retailer: @retailer,
      product: second_product,
      listing_name: "Low Fat Milk"
    )

    assert_nil first_listing.product_url
    assert_nil second_listing.product_url
  end

  test "database rejects duplicate product URLs even when model validations are bypassed" do
  first_product = @product

  second_product = Product.create!(
    name: "Low Fat Milk"
  )

  RetailerProduct.create!(
    retailer: @retailer,
    product: first_product,
    listing_name: "Full Cream Milk",
    product_url: "https://shoprite.example/milk"
  )

  assert_raises(ActiveRecord::RecordNotUnique) do
    RetailerProduct.insert!({
  retailer_id: @retailer.id,
  product_id: second_product.id,
  listing_name: "Low Fat Milk",
  product_url: "https://shoprite.example/milk",
  created_at: Time.current,
  updated_at: Time.current
})
  end
end
end