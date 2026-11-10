class AddUniqueProductUrlToRetailerProducts < ActiveRecord::Migration[8.1]
  def change
    add_index :retailer_products,
              [:retailer_id, :product_url],
              unique: true,
              where: "product_url IS NOT NULL AND product_url != ''",
              name: "index_retailer_products_on_retailer_id_and_product_url"
  end
end