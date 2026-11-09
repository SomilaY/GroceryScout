class PriceObservation < ApplicationRecord
  FRESHNESS_WINDOW = 24.hours

  belongs_to :retailer_product

  validates :price_cents,
            numericality: { only_integer: true, greater_than: 0 }

  validates :currency, presence: true
  validates :observed_at, presence: true
  validates :source, presence: true

  def fresh?
    observed_at.present? && observed_at >= FRESHNESS_WINDOW.ago
  end

  def stale?
    observed_at.present? && !fresh?
  end

  def age_in_hours
    return nil unless observed_at.present?

    [(Time.current - observed_at) / 1.hour, 0].max.floor
  end
end