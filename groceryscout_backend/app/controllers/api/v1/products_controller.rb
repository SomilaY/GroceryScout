
class Api::V1::ProductsController < ApplicationController
  DEFAULT_PER_PAGE = 20
  MAX_PER_PAGE = 50

  def index
    products = Product.all

    if params[:search].present?
      search_term = "%#{Product.sanitize_sql_like(params[:search])}%"

      products = products.where(
        "name ILIKE :term OR brand ILIKE :term OR barcode ILIKE :term",
        term: search_term
      )
    end

    if params[:category].present?
      products = products.where(
        "category ILIKE ?",
        params[:category].strip
      )
    end

       min_price = price_filter_cents(:min_price)
    max_price = price_filter_cents(:max_price)

    if params[:min_price].present? && min_price.nil?
      return render json: {
        error: "Invalid minimum price"
      }, status: :bad_request
    end

    if params[:max_price].present? && max_price.nil?
      return render json: {
        error: "Invalid maximum price"
      }, status: :bad_request
    end

    if min_price && max_price && min_price > max_price
      return render json: {
        error: "Minimum price cannot exceed maximum price"
      }, status: :bad_request
    end

   if min_price || max_price
  products = products.to_a
  fresh_prices = cheapest_fresh_prices(products)

  products = products.select do |product|
    price = fresh_prices[product.id]

    price.present? &&
      (min_price.nil? || price >= min_price) &&
      (max_price.nil? || price <= max_price)
  end
end

    case params[:sort]
    when "name_desc"
      products = products.order(name: :desc) unless products.is_a?(Array)

      products.sort_by! { |product| product.name.downcase }.reverse! if products.is_a?(Array)
   when "price_asc", "price_desc"
  products = products.to_a unless products.is_a?(Array)
  fresh_prices = cheapest_fresh_prices(products)

  products.sort_by! do |product|
    price = fresh_prices[product.id]

    if params[:sort] == "price_desc"
      [
        price.nil? ? 1 : 0,
        -(price || 0),
        product.name.downcase
      ]
    else
      [
        price.nil? ? 1 : 0,
        price || 0,
        product.name.downcase
      ]
    end
  end
    else
      products = products.order(:name) unless products.is_a?(Array)
      products.sort_by! { |product| product.name.downcase } if products.is_a?(Array)
    end

    total_count = products.count

    page = [params[:page].to_i, 1].max
    per_page = if params[:per_page].present?
                 params[:per_page].to_i.clamp(1, MAX_PER_PAGE)
               else
                 DEFAULT_PER_PAGE
               end

    paginated_products = if products.is_a?(Array)
                       products.slice((page - 1) * per_page, per_page) || []
                     else
                       products.limit(per_page)
                               .offset((page - 1) * per_page)
                     end

    render json: {
      products: product_responses(paginated_products),
      pagination: {
        current_page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: (total_count.to_f / per_page).ceil
      }
    }
  end

  def show
    product = Product.find_by(id: params[:id])

    unless product
      return render json: {
        error: "Product not found"
      }, status: :not_found
    end

    render json: {
  product: product_responses([product]).first
}
  end

  def price_history
  product = Product.find_by(id: params[:id])

  unless product
    return render json: {
      error: "Product not found"
    }, status: :not_found
  end

  days = params[:days].present? ? params[:days].to_i : 30
  days = days.clamp(1, 365)

  start_date = days.days.ago

  history = product.retailer_products
                 .joins(:retailer)
                 .includes(:retailer, :price_observations)
                   .where(active: true)
                   .order("retailers.name")
                   .map do |listing|

    observations = listing.price_observations
                          .where(currency: "ZAR")
                          .where(observed_at: start_date..Time.current)
                          .order(observed_at: :asc, id: :asc)

    next if observations.empty?

    {
      retailer: listing.retailer.name,
      prices: observations.map do |observation|
        {
          price_cents: observation.price_cents,
          price: observation.price_cents / 100.0,
          currency: observation.currency,
          observed_at: observation.observed_at
        }
      end
    }
  end.compact

  render json: {
    product: {
      id: product.id,
      name: product.name,
      brand: product.brand
    },
    period_days: days,
    start_date: start_date,
    end_date: Time.current,
    retailers: history
  }
end

  private

      def price_filter_cents(parameter)
    return nil unless params[parameter].present?

    value = BigDecimal(params[parameter].to_s)

    return nil unless value.finite? && value >= 0

    (value * 100).round.to_i
  rescue ArgumentError
    nil
  end

 def cheapest_fresh_prices(products)
  product_ids = products.map(&:id)

  return {} if product_ids.empty?

  RetailerProduct
    .joins(:price_observations)
    .where(
      product_id: product_ids,
      active: true
    )
    .where(
      price_observations: {
        currency: "ZAR",
        observed_at: 24.hours.ago..Time.current
      }
    )
    .group(:product_id)
    .minimum("price_observations.price_cents")
end

  def product_responses(products)
    products = products.to_a
    return [] if products.empty?

    listings = RetailerProduct
                 .includes(:retailer)
                 .where(
                   product_id: products.map(&:id),
                   active: true
                 )

    listing_ids = listings.map(&:id)

   latest_prices = PriceObservation
                  .where(
                    retailer_product_id: listing_ids,
                    currency: "ZAR"
                  )
                  .where(observed_at: 7.days.ago..Time.current)
                      .select(
                        "DISTINCT ON (price_observations.retailer_product_id) price_observations.*"
                      )
                      .order(
                        "price_observations.retailer_product_id, " \
                        "price_observations.observed_at DESC, " \
                        "price_observations.id DESC"
                      )

    latest_prices_by_listing = latest_prices.index_by(&:retailer_product_id)
    listings_by_product = listings.group_by(&:product_id)

    products.map do |product|
      prices = (listings_by_product[product.id] || []).filter_map do |listing|
        latest_price = latest_prices_by_listing[listing.id]

        next unless latest_price

        {
          retailer: listing.retailer.name,
          image_url: listing.image_url,
           in_stock: listing.in_stock,
          product_url: listing.product_url,
          price: latest_price.price_cents / 100.0,
          currency: latest_price.currency,
          observed_at: latest_price.observed_at,
          fresh: latest_price.fresh?,
          status: latest_price.fresh? ? "fresh" : "stale",
          age_in_hours: latest_price.age_in_hours
        }
      end

      prices.sort_by! { |price| price[:price] }

      {
        id: product.id,
        name: product.name,
        brand: product.brand,
        quantity: product.quantity_value,
        unit: product.quantity_unit,
        category: product.category,
        prices: prices
      }
    end
  end
end
