class AddTimingColumnsToFrames < ActiveRecord::Migration[8.1]
  def change
    add_column :frames, :started_at, :datetime
    add_column :frames, :completed_at, :datetime
    add_column :frames, :reds_cleared_at, :datetime
  end
end
