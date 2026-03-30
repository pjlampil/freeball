class AddVisitModeToMatches < ActiveRecord::Migration[8.1]
  def change
    add_column :matches, :visit_mode, :integer, default: 0, null: false
  end
end
