class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches do |t|
      t.references :player1, null: false, foreign_key: { to_table: :users }
      t.references :player2, null: false, foreign_key: { to_table: :users }
      t.integer :best_of
      t.integer :scoring_mode, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.bigint :current_frame_id, null: true

      t.timestamps
    end
  end
end
