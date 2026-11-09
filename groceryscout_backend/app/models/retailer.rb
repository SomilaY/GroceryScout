class Retailer < ApplicationRecord
  has_many :retailer_products, dependent: :restrict_with_error
  has_many :products, through: :retailer_products
  has_many :price_observations, through: :retailer_products
  has_many :retailer_api_credentials, dependent: :restrict_with_error

  validates :name, presence: true
  validates :slug, presence: true,
                   uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
end