
class Api::V1::BasketsController < ApplicationController
  before_action :authenticate_user!
before_action :set_basket, only: [:show, :compare]

  def create
    basket = current_user.baskets.new(basket_params)

    if basket.save
      render json: {
        message: "Basket created successfully",
        basket: {
          id: basket.id,
          name: basket.name,
          items: []
        }
      }, status: :created
    else
      render json: {
        errors: basket.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def show
    render json: {
      id: @basket.id,
      name: @basket.name,
      items: @basket.basket_items.includes(:product).map do |item|
        {
          id: item.id,
          product_id: item.product_id,
          product_name: item.product.name,
          quantity: item.quantity
        }
      end
    }
  end

    def compare
    items = @basket.basket_items.includes(:product)
    retailers = Retailer.where(active: true).order(:name)

    comparisons = retailers.map do |retailer|
      priced_items = []
      missing_items = []
      stale_items = []
      total_cents = 0

      items.each do |item|
        listing = RetailerProduct.find_by(
          retailer: retailer,
          product: item.product,
          active: true
        )

        latest_price = listing&.price_observations
                              &.where(currency: "ZAR")
                              &.order(observed_at: :desc, id: :desc)
                              &.first

        if latest_price.nil?
          missing_items << item.product.name

        elsif latest_price.fresh?
          line_total_cents = latest_price.price_cents * item.quantity
          total_cents += line_total_cents

          priced_items << {
  product_name: item.product.name,
  quantity: item.quantity,
  unit_price_cents: latest_price.price_cents,
  line_total_cents: line_total_cents,
  observed_at: latest_price.observed_at,
  fresh: true,
  status: "fresh",
  age_in_hours: latest_price.age_in_hours
}

        else
         stale_items << {
  product_name: item.product.name,
  quantity: item.quantity,
  last_price_cents: latest_price.price_cents,
  observed_at: latest_price.observed_at,
  fresh: false,
  status: "stale",
  age_in_hours: latest_price.age_in_hours
}
        end
      end

      complete = missing_items.empty? && stale_items.empty?

      {
        retailer: retailer.name,
        complete: complete,
        total_cents: complete ? total_cents : nil,
        items: priced_items,
        missing_items: missing_items,
        stale_items: stale_items
      }
    end

    complete_comparisons = comparisons.select do |comparison|
      comparison[:complete]
    end

    cheapest = if items.any?
                 complete_comparisons.min_by do |comparison|
                   comparison[:total_cents]
                 end
               end

    comparisons.sort_by! do |comparison|
      [
        comparison[:complete] ? 0 : 1,
        comparison[:total_cents] || 0
      ]
    end

    render json: {
      basket_id: @basket.id,
      basket_name: @basket.name,
      comparisons: comparisons,
      cheapest_retailer: cheapest && {
        name: cheapest[:retailer],
        total_cents: cheapest[:total_cents]
      }
    }
  end

  private

  def set_basket
  @basket = current_user.baskets.find(params[:id])
end

  def basket_params
  params.require(:basket).permit(:name)
end
end
