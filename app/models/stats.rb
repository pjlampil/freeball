class Stats
  attr_reader :player

  def initialize(player, visits, player_visits: nil)
    @player = player
    @player_visits  = player_visits || visits.select { |v| v.player_id == player.id }
    opponent_visits = visits.reject { |v| @player_visits.include?(v) }

    player_shots   = @player_visits.flat_map(&:shots)
    opponent_shots = opponent_visits.flat_map(&:shots)

    @potted         = player_shots.select(&:potted?)
    @fouls          = player_shots.select(&:foul?)
    @received_fouls = opponent_shots.select(&:foul?)
    @break_scores   = @player_visits.map(&:break_score).select { |s| s > 0 }
  end

  # Scoring
  def points_from_pots       = @potted.sum(&:points)
  def points_from_fouls      = @received_fouls.sum { |s| s.foul_value.to_i }
  def total_score            = points_from_pots + points_from_fouls

  # Balls
  def balls_potted           = @potted.count
  def reds_potted            = @potted.count(&:red?)
  def colors_potted          = @potted.count { |s| !s.red? && !s.free_ball? }
  def free_balls_potted      = @potted.count(&:free_ball?)

  # Breaks
  def highest_break          = @break_scores.max || 0
  def number_of_breaks       = @break_scores.count
  def multi_pot_breaks       = @player_visits.count { |v| v.shots.count(&:potted?) > 1 }
  def average_break          = @break_scores.empty? ? nil : (@break_scores.sum.to_f / @break_scores.size).round(1)
  def breaks_over(threshold) = @break_scores.count { |s| s >= threshold }
  def breaks_10_plus         = breaks_over(10)
  def breaks_20_plus         = breaks_over(20)
  def breaks_30_plus         = breaks_over(30)
  def breaks_40_plus         = breaks_over(40)
  def breaks_50_plus         = breaks_over(50)
  def centuries              = breaks_over(100)

  # Fouls
  def fouls_committed        = @fouls.count
  def foul_points_conceded   = @fouls.sum { |s| s.foul_value.to_i }
end
