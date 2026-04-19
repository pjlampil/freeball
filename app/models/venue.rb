class Venue < ApplicationRecord
  has_many :snooker_tables, dependent: :destroy
  has_many :matches, dependent: :nullify

  validates :name, presence: true

  def tables_for_select
    snooker_tables.order(:number, :name).map do |t|
      [ t.display_name, t.id ]
    end
  end
end
