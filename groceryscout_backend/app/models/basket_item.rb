class BasketItem < ApplicationRecord
  belongs_to :basket
  belongs_to :product

  validates :quantity,
            numericality: {
              only_integer: true,
              greater_than: 0
            }

  validates :product_id,
            uniqueness: { scope: :basket_id }
end