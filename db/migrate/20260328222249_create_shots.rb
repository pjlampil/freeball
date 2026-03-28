class CreateShots < ActiveRecord::Migration[8.1]
  def change
    create_table :shots do |t|
      t.references :visit, null: false, foreign_key: true
      t.integer :ball
      t.integer :result
      t.integer :foul_value
      t.integer :points
      t.integer :sequence

      t.timestamps
    end
  end
end
