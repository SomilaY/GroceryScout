class RequireUserForBaskets < ActiveRecord::Migration[8.1]
  def up
    change_column_null :baskets, :user_id, false
  end

  def down
    change_column_null :baskets, :user_id, true
  end
end