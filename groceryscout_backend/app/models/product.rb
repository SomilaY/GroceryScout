
class Product < ApplicationRecord
  has_many :retailer_products, dependent: :restrict_with_error
  has_many :retailers, through: :retailer_products

  validates :name, presence: true
  validates :barcode, uniqueness: true, allow_blank: true

  validates :quantity_value,
            numericality: { greater_than: 0 },
            allow_nil: true
end
