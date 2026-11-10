class AddInStockToRetailerProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :retailer_products, :in_stock, :boolean
  end
end
