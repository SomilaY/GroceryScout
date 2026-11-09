
class Api::V1::BasketItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_basket
  before_action :set_basket_item, only: [:update, :destroy]

  def create
    unless valid_product_id?
      return render json: {
        error: "A valid product ID is required"
      }, status: :bad_request
    end

    product = Product.find_by(id: params[:product_id])

    unless product
      return render json: {
        error: "Product not found"
      }, status: :not_found
    end

    quantity = parsed_quantity

    unless quantity
  return render json: {
    error: "Quantity must be a whole number"
  }, status: :bad_request
end

    item = @basket.basket_items.find_or_initialize_by(
      product: product
    )

    item.quantity = item.persisted? ? item.quantity + quantity : quantity

    if item.save
      render json: {
        message: "Product added to basket successfully",
        item: {
          id: item.id,
          product_id: product.id,
          product_name: product.name,
          quantity: item.quantity
        }
      }, status: :created
    else
      render json: {
        errors: item.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  def update
  quantity = parsed_quantity

  unless quantity
    return render json: {
      error: "Quantity must be a whole number"
    }, status: :bad_request
  end

  if @basket_item.update(quantity: quantity)
    render json: {
      message: "Basket item updated successfully",
      item: {
        id: @basket_item.id,
        product_id: @basket_item.product_id,
        product_name: @basket_item.product.name,
        quantity: @basket_item.quantity
      }
    }
  else
    render json: {
      errors: @basket_item.errors.full_messages
    }, status: :unprocessable_entity
  end
end

  def destroy
    @basket_item.destroy

    render json: {
      message: "Product removed from basket successfully"
    }
  end

  private

  def set_basket
    @basket = current_user.baskets.find(params[:basket_id])
  end

  def set_basket_item
    @basket_item = @basket.basket_items.find(params[:id])
  end

  def valid_product_id?
    params[:product_id].to_s.match?(/\A[1-9]\d*\z/)
  end

  def parsed_quantity
    value = params[:quantity]

    return nil if value.nil? || value.to_s.blank?

    Integer(value.to_s, 10)
  rescue ArgumentError, TypeError
    nil
  end
end
