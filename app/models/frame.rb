class Frame < ApplicationRecord
  belongs_to :match
  belongs_to :first_to_break, class_name: "User", optional: true
  belongs_to :winner, class_name: "User", optional: true

  has_many :visits, dependent: :destroy

  enum :status, { in_progress: 0, completed: 1 }

  # Points scored by each player from potted balls and fouls received
  def score_for(player)
    potted = visits.where(player: player).joins(:shots)
                   .where(shots: { result: :potted }).sum("shots.points")
    fouls_received = visits.where.not(player: player).joins(:shots)
                           .where(shots: { result: :foul }).sum("shots.foul_value")
    potted + fouls_received
  end

  def player1_score
    score_for(match.player1)
  end

  def player2_score
    score_for(match.player2)
  end

  def current_visit
    visits.order(:visit_number).last
  end

  def current_player
    current_visit&.player
  end

  # Total reds still on the table
  def reds_remaining
    reds_potted = visits.joins(:shots).where(shots: { ball: :red, result: :potted }).count
    [ 15 - reds_potted, 0 ].max
  end

  # Points still available (for snooker calculation)
  def remaining_points
    reds = reds_remaining
    colors_value = 2 + 3 + 4 + 5 + 6 + 7  # yellow..black = 27
    if reds > 0
      reds * (1 + 7) + colors_value
    else
      colors_on_table
    end
  end

  private

  # Sum of color values still to be potted in the colours phase
  def colors_on_table
    color_order = { yellow: 2, green: 3, brown: 4, blue: 5, pink: 6, black: 7 }
    potted_colors_in_sequence = visits.joins(:shots)
                                      .where(shots: { ball: color_order.keys.map(&:to_s), result: :potted })
                                      .pluck("shots.ball")
    total = color_order.values.sum
    potted_colors_in_sequence.uniq.each { |b| total -= color_order[b.to_sym] || 0 }
    total
  end
end
