# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_07_082306) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "basket_items", force: :cascade do |t|
    t.bigint "basket_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["basket_id", "product_id"], name: "index_basket_items_on_basket_id_and_product_id", unique: true
    t.index ["basket_id"], name: "index_basket_items_on_basket_id"
    t.index ["product_id"], name: "index_basket_items_on_product_id"
  end

  create_table "baskets", force: :cascade do |t|
    t.string "name", default: "My Basket", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_baskets_on_user_id"
  end

  create_table "price_observations", force: :cascade do |t|
    t.bigint "retailer_product_id", null: false
    t.integer "price_cents", null: false
    t.string "currency", default: "ZAR", null: false
    t.datetime "observed_at", null: false
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["retailer_product_id", "observed_at"], name: "idx_on_retailer_product_id_observed_at_8d6a86292d"
    t.index ["retailer_product_id"], name: "index_price_observations_on_retailer_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name", null: false
    t.string "brand"
    t.string "barcode"
    t.decimal "quantity_value", precision: 12, scale: 3
    t.string "quantity_unit"
    t.string "category"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_products_on_barcode", unique: true
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_refresh_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "retailer_api_credentials", force: :cascade do |t|
    t.bigint "retailer_id", null: false
    t.string "token_digest", null: false
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["retailer_id"], name: "index_retailer_api_credentials_on_retailer_id"
    t.index ["token_digest"], name: "index_retailer_api_credentials_on_token_digest", unique: true
  end

  create_table "retailer_products", force: :cascade do |t|
    t.bigint "retailer_id", null: false
    t.bigint "product_id", null: false
    t.string "retailer_sku"
    t.string "listing_name", null: false
    t.string "product_url"
    t.string "image_url"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_retailer_products_on_product_id"
    t.index ["retailer_id", "product_id"], name: "index_retailer_products_on_retailer_id_and_product_id", unique: true
    t.index ["retailer_id", "retailer_sku"], name: "index_retailer_products_on_retailer_id_and_retailer_sku", unique: true, where: "(retailer_sku IS NOT NULL)"
    t.index ["retailer_id"], name: "index_retailer_products_on_retailer_id"
  end

  create_table "retailers", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "website_url"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_retailers_on_slug", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_reset_token_digest"
    t.datetime "password_reset_expires_at"
    t.datetime "password_changed_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["password_reset_token_digest"], name: "index_users_on_password_reset_token_digest", unique: true
  end

  add_foreign_key "basket_items", "baskets"
  add_foreign_key "basket_items", "products"
  add_foreign_key "baskets", "users"
  add_foreign_key "price_observations", "retailer_products"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "retailer_api_credentials", "retailers"
  add_foreign_key "retailer_products", "products"
  add_foreign_key "retailer_products", "retailers"
end
