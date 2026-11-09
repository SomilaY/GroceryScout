class CreatePriceObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :price_observations do |t|
      t.references :retailer_product, null: false, foreign_key: true

      t.integer :price_cents, null: false
      t.string :currency, null: false, default: "ZAR"
      t.datetime :observed_at, null: false
      t.string :source, null: false

      t.timestamps
    end

    add_index :price_observations,
              [:retailer_product_id, :observed_at]
  end
end