class Match < ApplicationRecord
  belongs_to :player1, class_name: "User"
  belongs_to :player2, class_name: "User"
  belongs_to :current_frame, class_name: "Frame", optional: true

  has_many :frames, dependent: :destroy

  enum :scoring_mode,  { granular: 0, frame_score: 1 }
  enum :status,        { upcoming: 0, in_progress: 1, completed: 2 }
  enum :visit_mode,    { breaks_only: 0, all_turns: 1 }
  enum :match_format,  { standard: 0, ten_reds: 1, six_reds: 2, stop_at_last_red: 3 }

  def reds_count
    case match_format
    when "six_reds"  then 6
    when "ten_reds"  then 10
    else                  15
    end
  end

  def stop_after_reds?
    stop_at_last_red?
  end

  validates :player1, :player2, presence: true
  validate :players_must_be_different

  def frames_won_by(player)
    frames.completed.where(winner: player).count
  end

  def player1_frames
    frames_won_by(player1)
  end

  def player2_frames
    frames_won_by(player2)
  end

  def frames_needed_to_win
    return nil unless best_of
    (best_of / 2) + 1
  end

  def winner
    return nil unless completed?
    if player1_frames > player2_frames
      player1
    else
      player2
    end
  end

  private

  def players_must_be_different
    errors.add(:player2, "must be different from player 1") if player1_id == player2_id
  end
end
