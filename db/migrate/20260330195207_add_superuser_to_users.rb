class AddSuperuserToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :superuser, :boolean, default: false, null: false
  end
end
