class AddRespottedBlackToFrames < ActiveRecord::Migration[8.1]
  def change
    add_column :frames, :respotted_black, :boolean, default: false, null: false
  end
end
