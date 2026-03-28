class Api::V1::FramesController < Api::V1::BaseController
  before_action :set_frame, only: [ :show, :end_visit, :complete ]
  before_action :set_match, only: [ :index ]

  def index
    frames = @match.frames.includes(:visits => :shots).order(:frame_number)
    render json: frames.map { |f| frame_json(f) }
  end

  def show
    render json: frame_json(@frame)
  end

  def end_visit
    visit = @frame.current_visit
    return render json: { error: "No active visit" }, status: :unprocessable_entity if visit.nil?

    ended_by = params[:ended_by].presence_in(%w[miss foul conceded]) || "miss"
    visit.update!(ended_by: ended_by)

    next_player = visit.player == @frame.match.player1 ? @frame.match.player2 : @frame.match.player1
    @frame.visits.create!(player: next_player, visit_number: visit.visit_number + 1)

    MatchChannel.broadcast_frame_update(@frame)
    render json: frame_json(@frame.reload)
  end

  def complete
    winner_id = params[:winner_id].to_i
    winner = [ @frame.match.player1, @frame.match.player2 ].find { |p| p.id == winner_id }
    return render json: { error: "Invalid winner" }, status: :unprocessable_entity unless winner

    @frame.current_visit&.update!(ended_by: :frame_end)
    @frame.update!(status: :completed, winner: winner)

    MatchChannel.broadcast_frame_update(@frame)
    render json: frame_json(@frame)
  end

  private

  def set_frame
    @frame = Frame.find(params[:id])
  end

  def set_match
    @match = Match.find(params[:match_id])
  end

  def frame_json(frame)
    {
      id: frame.id,
      match_id: frame.match_id,
      frame_number: frame.frame_number,
      status: frame.status,
      player1_score: frame.player1_score,
      player2_score: frame.player2_score,
      reds_remaining: frame.reds_remaining,
      winner_id: frame.winner_id,
      current_player_id: frame.current_player&.id,
      visits: frame.visits.order(:visit_number).map { |v| visit_json(v) }
    }
  end

  def visit_json(visit)
    {
      id: visit.id,
      player_id: visit.player_id,
      visit_number: visit.visit_number,
      ended_by: visit.ended_by,
      break_score: visit.break_score,
      shots: visit.shots.map { |s| shot_json(s) }
    }
  end

  def shot_json(shot)
    {
      id: shot.id,
      ball: shot.ball,
      result: shot.result,
      points: shot.points,
      foul_value: shot.foul_value,
      sequence: shot.sequence
    }
  end
end
