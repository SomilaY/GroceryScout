
class CreateProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.string :brand
      t.string :barcode
      t.decimal :quantity_value, precision: 12, scale: 3
      t.string :quantity_unit
      t.string :category

      t.timestamps
    end

    add_index :products, :barcode, unique: true
  end
end
