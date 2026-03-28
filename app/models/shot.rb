class Shot < ApplicationRecord
  belongs_to :visit

  BALL_VALUES = {
    red: 1, yellow: 2, green: 3, brown: 4, blue: 5, pink: 6, black: 7, free_ball: 0
  }.freeze

  enum :ball, { red: 0, yellow: 1, green: 2, brown: 3, blue: 4, pink: 5, black: 6, free_ball: 7 }
  enum :result, { potted: 0, foul: 1 }

  validates :ball, :result, presence: true
  validates :foul_value, presence: true, inclusion: { in: [ 4, 5, 6, 7 ] }, if: :foul?
  validates :points, presence: true

  before_validation :set_points

  private

  def set_points
    if potted?
      self.points = BALL_VALUES[ball.to_sym] || 0
    elsif foul?
      self.points = 0  # points go to opponent; tracked via foul_value
    end
  end
end
