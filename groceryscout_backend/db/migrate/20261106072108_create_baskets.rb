class CreateBaskets < ActiveRecord::Migration[8.1]
  def change
    create_table :baskets do |t|
      t.string :name, null: false, default: "My Basket"

      t.timestamps
    end
  end
end