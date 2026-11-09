
class CreateRetailerProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :retailer_products do |t|
      t.references :retailer, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true

      t.string :retailer_sku
      t.string :listing_name, null: false
      t.string :product_url
      t.string :image_url
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :retailer_products,
              [:retailer_id, :retailer_sku],
              unique: true,
              where: "retailer_sku IS NOT NULL"

    add_index :retailer_products,
              [:retailer_id, :product_id],
              unique: true
  end
end
