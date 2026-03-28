class CreateFrames < ActiveRecord::Migration[8.1]
  def change
    create_table :frames do |t|
      t.references :match, null: false, foreign_key: true
      t.integer :frame_number, null: false
      t.references :first_to_break, null: true, foreign_key: { to_table: :users }
      t.references :winner, null: true, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
