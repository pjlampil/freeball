class AddRemovedRedsToFrames < ActiveRecord::Migration[8.1]
  def change
    add_column :frames, :removed_reds, :integer, default: 0, null: false
  end
end
