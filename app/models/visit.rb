class Visit < ApplicationRecord
  belongs_to :frame
  belongs_to :player, class_name: "User"

  has_many :shots, -> { order(:sequence) }, dependent: :destroy

  enum :ended_by, { miss: 0, foul: 1, frame_end: 2, conceded: 3 }, prefix: true

  def break_score
    shots.where(result: :potted).sum(:points)
  end

  def active?
    ended_by.nil?
  end
end
