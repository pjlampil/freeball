class Frame < ApplicationRecord
  belongs_to :match
  belongs_to :first_to_break, class_name: "User", optional: true
  belongs_to :winner, class_name: "User", optional: true
  belongs_to :pending_winner, class_name: "User", optional: true

  has_many :visits, dependent: :destroy
  has_many :shots, through: :visits

  enum :status, { in_progress: 0, completed: 1 }

  def duration
    return nil unless started_at && completed_at
    (completed_at - started_at).to_i
  end

  def reds_phase_duration
    return nil unless started_at && reds_cleared_at
    (reds_cleared_at - started_at).to_i
  end

  def colors_phase_duration
    return nil unless reds_cleared_at && completed_at
    (completed_at - reds_cleared_at).to_i
  end

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

  def reds_remaining
    reds_potted = visits.joins(:shots).where(shots: { ball: :red, result: :potted }).count
    [ match.reds_count - reds_potted - removed_reds, 0 ].max
  end

  # Which balls are valid to pot right now
  def valid_balls
    return [] unless in_progress?
    visit = current_visit
    return [] unless visit&.active?

    return [ :black ] if respotted_black?

    last_potted = visit.shots.where(result: :potted).order(:sequence).last

    if last_potted&.red? || last_potted&.free_ball?
      # Just potted a red (or free ball as red) — any colour can be nominated
      [ :yellow, :green, :brown, :blue, :pink, :black ]
    elsif reds_remaining > 0
      [ :red ]
    elsif match.stop_after_reds?
      # No colours phase in this format — visit must end
      []
    else
      next_c = next_color_in_sequence
      next_c ? [ next_c ] : []
    end
  end

  # Free ball is available when the visit starts immediately after a foul
  def free_ball_available?
    return false unless in_progress?
    return false if respotted_black?
    visit = current_visit
    return false unless visit&.active? && visit.shots.empty?

    prev = visits.find_by(visit_number: visit.visit_number - 1)
    prev&.ended_by_foul?
  end

  # Points remaining on the table (maximum possible)
  def remaining_points
    reds = reds_remaining
    colors_value = 2 + 3 + 4 + 5 + 6 + 7  # 27

    if reds > 0
      visit = current_visit
      last_potted = visit&.shots&.where(result: :potted)&.order(:sequence)&.last
      color_on_bonus = last_potted&.red? ? 7 : 0  # assume black if color is on
      if match.stop_after_reds?
        color_on_bonus + reds * 8  # no colours phase
      else
        color_on_bonus + reds * 8 + colors_value
      end
    else
      return 0 if match.stop_after_reds?
      colors_on_table
    end
  end

  def point_difference
    (player1_score - player2_score).abs
  end

  def leading_player
    p1 = player1_score
    p2 = player2_score
    return nil if p1 == p2
    p1 > p2 ? match.player1 : match.player2
  end

  def trailing_player
    leading = leading_player
    return nil unless leading
    leading == match.player1 ? match.player2 : match.player1
  end

  # Can the trailing player still win on points alone?
  def comeback_possible?
    trail = point_difference
    trail == 0 || remaining_points >= trail
  end

  # Minimum points awarded per foul given what's currently on the table
  def minimum_foul_value
    return 4 if reds_remaining > 0
    next_c = next_color_in_sequence
    next_c ? [ Shot::BALL_VALUES[next_c], 4 ].max : 7
  end

  # How many fouls (snookers) the trailing player needs to have a chance
  def snookers_needed
    return 0 if comeback_possible?
    gap = point_difference - remaining_points
    (gap.to_f / minimum_foul_value).ceil
  end

  # True when the black was just fouled and is the only ball left
  def black_is_last_remaining?
    reds_remaining == 0 && next_color_in_sequence == :black
  end

  # True when all balls have been potted (black was just potted in colours phase)
  def all_balls_potted?
    reds_remaining == 0 && next_color_in_sequence.nil?
  end

  # Player with higher score; nil if tied
  def score_winner
    p1 = player1_score
    p2 = player2_score
    return nil if p1 == p2
    p1 > p2 ? match.player1 : match.player2
  end

  def free_ball_value
    if reds_remaining > 0
      1
    else
      Shot::BALL_VALUES[next_color_in_sequence] || 1
    end
  end

  private

  # In the colours phase (no reds left), find which colour is next in sequence.
  # After the 15th red, one nominated colour is potted and re-spotted — that doesn't
  # count as a colours-phase pot. Colours phase begins at ordered_pots[last_red_index + 2].
  def next_color_in_sequence
    colors_in_order = %w[yellow green brown blue pink black]

    ordered_pots = visits.joins(:shots)
                         .where(shots: { result: "potted" })
                         .order("visits.visit_number ASC, shots.sequence ASC")
                         .pluck("shots.ball")

    last_red_pos = ordered_pots.rindex("red")
    return :yellow unless last_red_pos

    phase_pots = (ordered_pots[(last_red_pos + 2)..] || []).reject { |b| b == "red" }
    colors_in_order[phase_pots.length]&.to_sym
  end

  def colors_on_table
    colors_in_order = %w[yellow green brown blue pink black]
    values = { "yellow" => 2, "green" => 3, "brown" => 4, "blue" => 5, "pink" => 6, "black" => 7 }

    ordered_pots = visits.joins(:shots)
                         .where(shots: { result: "potted" })
                         .order("visits.visit_number ASC, shots.sequence ASC")
                         .pluck("shots.ball")

    last_red_pos = ordered_pots.rindex("red")
    phase_pots = last_red_pos ? (ordered_pots[(last_red_pos + 2)..] || []).reject { |b| b == "red" } : []

    (colors_in_order[phase_pots.length..] || []).sum { |c| values[c] }
  end
end
