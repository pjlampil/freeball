class AddClockFieldsToFrames < ActiveRecord::Migration[8.0]
  def change
    add_column :frames, :paused_at, :datetime
    add_column :frames, :total_paused_seconds, :integer, default: 0, null: false
  end
end
