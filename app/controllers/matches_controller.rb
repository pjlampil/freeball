class MatchesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :index, :show, :stats, :watch ]
  before_action :set_match, only: [ :show, :edit, :update, :destroy, :start, :finish, :stats, :watch ]
  before_action :require_participant!, only: [ :edit, :update, :destroy, :finish ]

  def index
    @matches = if user_signed_in?
      current_user.matches.includes(:player1, :player2, :frames).order(created_at: :desc)
    else
      Match.includes(:player1, :player2, :frames).order(created_at: :desc)
    end
  end

  def show
    if @match.granular? && !@match.upcoming?
      visits = @match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)
      @p1_stats = Stats.new(@match.player1, visits)
      @p2_stats = Stats.new(@match.player2, visits)
    end
  end

  def watch
    @current_frame = @match.current_frame
    @match_started_at = @match.frames.minimum(:started_at)
    if @match.granular?
      visits = @match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)
      @p1_stats = Stats.new(@match.player1, visits)
      @p2_stats = Stats.new(@match.player2, visits)
    end
  end

  def stats
    visits = @match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)
    @p1_stats = Stats.new(@match.player1, visits)
    @p2_stats = Stats.new(@match.player2, visits)
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

  def edit
    @users = User.order(:name)
  end

  def update
    permitted = @match.frames.any? ? match_params.except(:player1_id, :player2_id, :scoring_mode, :visit_mode, :match_format) : match_params
    if @match.update(permitted)
      redirect_to @match, notice: "Match updated."
    else
      @users = User.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @match.destroy!
    redirect_to matches_path, notice: "Match deleted."
  end

  def finish
    return redirect_to @match unless @match.in_progress? && @match.best_of.nil?

    # Discard the empty in-progress frame that was auto-created after the last completed frame
    current = @match.current_frame
    if current&.in_progress? && current.shots.empty?
      current.destroy!
    end

    @match.update!(status: :completed, current_frame: nil)
    redirect_to @match
  end

  def start
    return redirect_to @match if @match.in_progress? || @match.completed?

    first_breaker = [ @match.player1, @match.player2 ].sample
    frame = @match.frames.create!(
      frame_number: 1,
      first_to_break: first_breaker,
      status: :in_progress
    )
    @match.update!(status: :in_progress, current_frame: frame)

    frame.visits.create!(player: first_breaker, visit_number: 1)

    respond_to do |format|
      format.html { redirect_to frame_path(frame) }
      format.turbo_stream
    end
  end

  private

  def set_match
    @match = Match.find(params[:id])
  end

  def require_participant!
    unless @match.player1 == current_user || @match.player2 == current_user
      redirect_to @match, alert: "Not authorized."
    end
  end

  def match_params
    params.require(:match).permit(:player1_id, :player2_id, :best_of, :scoring_mode, :visit_mode, :match_format)
  end
end
