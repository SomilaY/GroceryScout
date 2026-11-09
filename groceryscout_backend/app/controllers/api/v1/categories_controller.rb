class Api::V1::CategoriesController < ApplicationController
  def index
    categories = Product
                   .where.not(category: [nil, ""])
                   .distinct
                   .order(:category)
                   .pluck(:category)

    render json: {
      categories: categories
    }
  end
end