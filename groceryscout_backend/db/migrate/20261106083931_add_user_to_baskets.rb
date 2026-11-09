class AddUserToBaskets < ActiveRecord::Migration[8.1]
  def change
    add_reference :baskets, :user, null: true, foreign_key: true
  end
end