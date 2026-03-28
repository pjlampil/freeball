class MatchesController < ApplicationController
  before_action :set_match, only: [ :show, :start ]

  def index
    @matches = current_user.matches.includes(:player1, :player2, :frames).order(created_at: :desc)
  end

  def show
  end

  def new
    @match = Match.new
    @users = User.order(:name)
  end

  def create
    @match = Match.new(match_params)
    if @match.save
      redirect_to @match, notice: "Match created."
    else
      @users = User.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def start
    return redirect_to @match if @match.in_progress? || @match.completed?

    frame = @match.frames.create!(
      frame_number: 1,
      first_to_break: @match.player1,
      status: :in_progress
    )
    @match.update!(status: :in_progress, current_frame: frame)

    first_visit = frame.visits.create!(
      player: @match.player1,
      visit_number: 1
    )

    respond_to do |format|
      format.html { redirect_to frame_path(frame) }
      format.turbo_stream
    end
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def match_params
    params.require(:match).permit(:player1_id, :player2_id, :best_of, :scoring_mode)
  end
end
