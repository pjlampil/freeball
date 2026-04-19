# Like Stats but backed by SQL aggregates — no visits/shots loaded into memory.
# Accepts two ActiveRecord Visit relations: one for the player, one for opponents.
class SqlStats
  attr_reader :player

  def initialize(player, player_visits, opponent_visits)
    @player = player
    @pv     = player_visits    # Visit relation scoped to this player
    @ov     = opponent_visits  # Visit relation scoped to opponents
  end

  # Scoring
  def points_from_pots
    player_shots.where(result: :potted).sum(:points)
  end

  def points_from_fouls
    opponent_shots.where(result: :foul).sum(:foul_value)
  end

  def total_score
    points_from_pots + points_from_fouls
  end

  # Balls
  def balls_potted
    player_shots.where(result: :potted).count
  end

  def reds_potted
    player_shots.where(result: :potted, ball: :red).count
  end

  def colors_potted
    player_shots.where(result: :potted).where.not(ball: [ :red, :free_ball ]).count
  end

  def free_balls_potted
    player_shots.where(result: :potted, ball: :free_ball).count
  end

  # Breaks
  def highest_break
    break_scores.max || 0
  end

  def number_of_breaks
    break_scores.count
  end

  def average_break
    scores = break_scores
    scores.empty? ? nil : (scores.sum.to_f / scores.size).round(1)
  end

  def multi_pot_breaks
    multi_pot_break_scores.size
  end

  def avg_multi_pot_break
    scores = multi_pot_break_scores
    scores.empty? ? nil : (scores.sum.to_f / scores.size).round(1)
  end

  def breaks_over(threshold)
    break_scores.count { |s| s >= threshold }
  end

  def breaks_10_plus  = breaks_over(10)
  def breaks_20_plus  = breaks_over(20)
  def breaks_30_plus  = breaks_over(30)
  def breaks_40_plus  = breaks_over(40)
  def breaks_50_plus  = breaks_over(50)
  def centuries       = breaks_over(100)

  # Fouls
  def fouls_committed
    player_shots.where(result: :foul).count
  end

  def foul_points_conceded
    player_shots.where(result: :foul).sum(:foul_value)
  end

  private

  def player_shots
    Shot.joins(:visit).merge(@pv)
  end

  def opponent_shots
    Shot.joins(:visit).merge(@ov)
  end

  # Per-visit pot totals (> 0), memoized — one DB query
  def break_scores
    @break_scores ||= player_shots.where(result: :potted)
                                  .group("visits.id")
                                  .sum(:points)
                                  .values
                                  .select { |s| s > 0 }
  end

  # Per-visit pot totals where more than one ball was potted, memoized
  def multi_pot_break_scores
    @multi_pot_break_scores ||= player_shots.where(result: :potted)
                                            .group("visits.id")
                                            .having("COUNT(*) > 1")
                                            .sum(:points)
                                            .values
  end
end
