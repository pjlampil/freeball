class CreateSnookerTables < ActiveRecord::Migration[8.1]
  def change
    create_table :snooker_tables do |t|
      t.references :venue, null: false, foreign_key: true
      t.integer :number
      t.string :name

      t.timestamps
    end
  end
end
