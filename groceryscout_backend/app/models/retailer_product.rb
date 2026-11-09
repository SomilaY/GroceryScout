
class RetailerProduct < ApplicationRecord
  belongs_to :retailer
  belongs_to :product

 has_many :price_observations, dependent: :restrict_with_error

  validates :listing_name, presence: true

  validates :product_id,
            uniqueness: { scope: :retailer_id }

  validates :retailer_sku,
            uniqueness: { scope: :retailer_id },
            allow_blank: true
end
