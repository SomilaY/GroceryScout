
class CreateRetailers < ActiveRecord::Migration[8.1]
  def change
    create_table :retailers do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :website_url
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :retailers, :slug, unique: true
  end
end
