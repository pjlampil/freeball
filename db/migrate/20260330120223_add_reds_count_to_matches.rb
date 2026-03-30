class AddRedsCountToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :match_format, :integer, default: 0, null: false
  end
end
