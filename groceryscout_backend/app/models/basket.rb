class Basket < ApplicationRecord
  belongs_to :user

  has_many :basket_items, dependent: :destroy
  has_many :products, through: :basket_items

  validates :name, presence: true
end