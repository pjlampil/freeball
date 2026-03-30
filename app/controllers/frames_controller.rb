class FramesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :show, :stats ]
  before_action :set_frame

  def show
    @match = @frame.match
    @current_visit = @frame.current_visit
    @current_player = @frame.current_player
    if @match.granular?
      visits = @match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)
      @p1_stats = Stats.new(@match.player1, visits)
      @p2_stats = Stats.new(@match.player2, visits)
    end
  end

  def stats
    @match = @frame.match
    visits = @frame.visits.includes(:shots, :player).to_a
    @p1_stats = Stats.new(@match.player1, visits)
    @p2_stats = Stats.new(@match.player2, visits)
  end

  def end_visit
    visit = @frame.current_visit
    return redirect_to @frame if visit.nil? || !visit.active?

    ended_by = params[:ended_by].presence_in(%w[miss foul conceded]) || "miss"
    next_player = visit.player == @frame.match.player1 ? @frame.match.player2 : @frame.match.player1
    no_pots = visit.shots.where(result: :potted).empty?

    match = @frame.match

    if match.stop_after_reds? && @frame.reds_remaining == 0
      visit.update!(ended_by: ended_by)
      @frame.update!(pending_winner: @frame.score_winner)
      MatchChannel.broadcast_frame_update(@frame)
      respond_to do |format|
        format.json { render json: { ok: true } }
        format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
      end
      return
    end

    if match.breaks_only? && no_pots
      # Don't log the empty visit — drop it and hand straight over
      next_visit_number = visit.visit_number
      visit.destroy!
      @frame.visits.create!(player: next_player, visit_number: next_visit_number)
    else
      visit.update!(ended_by: ended_by)
      @frame.visits.create!(player: next_player, visit_number: visit.visit_number + 1)
    end

    MatchChannel.broadcast_frame_update(@frame)

    respond_to do |format|
      format.json { render json: { ok: true } }
      format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
    end
  end

  def undo
    current_visit = @frame.current_visit

    # If the active visit is empty, the last action was a manual miss/concede — undo that
    if current_visit&.active? && current_visit.shots.empty? && current_visit.visit_number > 1
      prev_visit = @frame.visits.find_by(visit_number: current_visit.visit_number - 1)
      if prev_visit&.ended_by_miss? || prev_visit&.ended_by_conceded?
        current_visit.destroy!
        prev_visit.update!(ended_by: nil)
        MatchChannel.broadcast_frame_update(@frame)
        respond_to do |format|
          format.json { render json: { ok: true } }
          format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
        end
        return
      end
    end

    # Otherwise undo the last shot (and reverse its side-effects)
    last_shot = @frame.shots.joins(:visit).order("visits.visit_number ASC, shots.sequence ASC").last
    unless last_shot
      respond_to do |format|
        format.any { render partial: "frames/frame", locals: { frame: @frame.reload } }
      end
      return
    end

    shot_visit          = last_shot.visit
    was_foul            = last_shot.foul?
    frame_was_completed = @frame.completed?
    frame_had_pending   = @frame.pending_winner_id.present?
    frame_had_respot    = @frame.respotted_black?

    last_shot.destroy!
    shot_visit.reload
    @frame.reload

    # Clear pending winner if the deleted shot was what set it
    @frame.update!(pending_winner: nil) if frame_had_pending

    # Un-complete the frame (and any auto-created next frame / match completion)
    if frame_was_completed
      match = @frame.match.reload
      if match.completed?
        match.update!(status: :in_progress, current_frame: @frame)
      elsif match.current_frame && match.current_frame != @frame
        next_frame = match.current_frame
        match.update!(current_frame: @frame, status: :in_progress)
        next_frame.destroy!
      end
      @frame.update!(status: :in_progress, winner: nil, completed_at: nil)
      @frame.reload
    end

    if @frame.reds_cleared_at.present? && @frame.reds_remaining > 0
      @frame.update!(reds_cleared_at: nil)
      @frame.reload
    end

    # Determine if the deleted shot caused the visit to end
    is_respot_visit   = frame_had_respot && shot_visit.visit_number == @frame.visits.maximum(:visit_number)
    should_reactivate = (was_foul && shot_visit.ended_by_foul?) ||
                        (shot_visit.ended_by_frame_end? && (frame_was_completed || frame_had_pending || frame_had_respot))

    if should_reactivate
      @frame.visits.where("visit_number > ?", shot_visit.visit_number).destroy_all
      @frame.update!(respotted_black: false) if frame_had_respot && !is_respot_visit
      shot_visit.update!(ended_by: nil)
    end

    MatchChannel.broadcast_frame_update(@frame)
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
    end
  end

  def remove_red
    return if @frame.reds_remaining <= 0
    @frame.increment!(:removed_reds)
    @frame.reload
    if @frame.reds_remaining == 0 && @frame.reds_cleared_at.nil?
      @frame.update!(reds_cleared_at: Time.current)
      @frame.reload
    end
    MatchChannel.broadcast_frame_update(@frame)
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
    end
  end

  def restore_red
    return if @frame.removed_reds <= 0
    @frame.decrement!(:removed_reds)
    @frame.reload
    if @frame.reds_cleared_at.present? && @frame.reds_remaining > 0
      @frame.update!(reds_cleared_at: nil)
      @frame.reload
    end
    MatchChannel.broadcast_frame_update(@frame)
    respond_to do |format|
      format.json { render json: { ok: true } }
      format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
    end
  end

  def confirm_result
    pending = @frame.pending_winner
    return redirect_to frame_path(@frame) unless pending

    @frame.update!(status: :completed, winner: pending, pending_winner: nil, completed_at: Time.current)
    check_match_complete(@frame.match)
    MatchChannel.broadcast_frame_update(@frame)

    respond_to do |format|
      format.json { render json: { ok: true } }
      format.any  { redirect_to after_frame_path }
    end
  end

  def complete
    winner_id = params[:winner_id]
    winner = @frame.match.player1_id.to_s == winner_id ? @frame.match.player1 : @frame.match.player2

    @frame.current_visit&.update!(ended_by: :frame_end)
    @frame.update!(status: :completed, winner: winner, completed_at: Time.current)

    match = @frame.match
    check_match_complete(match)

    MatchChannel.broadcast_frame_update(@frame)

    redirect_to match_path(match)
  end

  private

  def after_frame_path
    match = @frame.match.reload
    match.completed? ? match_path(match) : frame_path(match.current_frame)
  end

  def set_frame
    @frame = Frame.find(params[:id])
  end

  def check_match_complete(match)
    needed = match.frames_needed_to_win
    return unless needed

    if match.player1_frames >= needed || match.player2_frames >= needed
      match.update!(status: :completed, current_frame: nil)
    else
      next_frame_number = match.frames.count + 1
      next_breaker = @frame.first_to_break == match.player1 ? match.player2 : match.player1
      new_frame = match.frames.create!(
        frame_number: next_frame_number,
        first_to_break: next_breaker,
        status: :in_progress,
        started_at: Time.current
      )
      match.update!(current_frame: new_frame)
      new_frame.visits.create!(player: next_breaker, visit_number: 1)
    end
  end
end
