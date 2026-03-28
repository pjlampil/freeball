class Api::V1::MatchesController < Api::V1::BaseController
  before_action :set_match, only: [ :show, :start ]

  def index
    matches = current_user.matches.includes(:player1, :player2, :frames).order(created_at: :desc)
    render json: matches.map { |m| match_json(m) }
  end

  def show
    render json: match_json(@match)
  end

  def create
    match = Match.new(match_params)
    match.save!
    render json: match_json(match), status: :created
  end

  def start
    return render json: match_json(@match) if @match.in_progress? || @match.completed?

    frame = @match.frames.create!(
      frame_number: 1,
      first_to_break: @match.player1,
      status: :in_progress
    )
    @match.update!(status: :in_progress, current_frame: frame)
    frame.visits.create!(player: @match.player1, visit_number: 1)

    render json: match_json(@match.reload)
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def match_params
    params.require(:match).permit(:player1_id, :player2_id, :best_of, :scoring_mode)
  end

  def match_json(match)
    {
      id: match.id,
      status: match.status,
      scoring_mode: match.scoring_mode,
      best_of: match.best_of,
      player1: { id: match.player1.id, name: match.player1.name },
      player2: { id: match.player2.id, name: match.player2.name },
      player1_frames: match.player1_frames,
      player2_frames: match.player2_frames,
      current_frame_id: match.current_frame_id,
      created_at: match.created_at
    }
  end
end
