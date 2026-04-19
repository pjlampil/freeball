class SnookerTable < ApplicationRecord
  belongs_to :venue
  has_many :matches, dependent: :nullify

  validates :venue, presence: true
  validate :number_or_name_present

  def display_name
    if number && name.present?
      "Table #{number} — #{name}"
    elsif number
      "Table #{number}"
    else
      name
    end
  end

  private

  def number_or_name_present
    errors.add(:base, "Table must have a number or a name") if number.blank? && name.blank?
  end
end
