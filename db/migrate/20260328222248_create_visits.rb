class CreateVisits < ActiveRecord::Migration[8.1]
  def change
    create_table :visits do |t|
      t.references :frame, null: false, foreign_key: true
      t.references :player, null: false, foreign_key: { to_table: :users }
      t.integer :visit_number, null: false
      t.integer :ended_by

      t.timestamps
    end
  end
end
