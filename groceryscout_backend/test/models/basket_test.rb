require "test_helper"

class BasketTest < ActiveSupport::TestCase
  test "customer can create and retrieve their basket" do
    user = User.create!(
      name: "John Smith",
      email: "john.basket@example.com",
      password: "password123"
    )

    basket = user.baskets.create!(
      name: "Weekly Shopping"
    )

    assert basket.persisted?
    assert_equal user.id, basket.user_id
    assert_includes user.baskets, basket
  end
end