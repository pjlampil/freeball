class AddPendingWinnerToFrames < ActiveRecord::Migration[8.1]
  def change
    add_reference :frames, :pending_winner, null: true, foreign_key: { to_table: :users }
  end
end
