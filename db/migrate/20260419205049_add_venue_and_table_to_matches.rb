class AddVenueAndTableToMatches < ActiveRecord::Migration[8.1]
  def change
    add_reference :matches, :venue, null: true, foreign_key: true
    add_reference :matches, :snooker_table, null: true, foreign_key: true
  end
end
