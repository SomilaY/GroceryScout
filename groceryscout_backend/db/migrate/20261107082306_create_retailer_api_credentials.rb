class CreateRetailerApiCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :retailer_api_credentials do |t|
      t.references :retailer, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :retailer_api_credentials, :token_digest, unique: true
  end
end