class FramesController < ApplicationController
  before_action :set_frame

  def show
    @match = @frame.match
    @current_visit = @frame.current_visit
    @current_player = @frame.current_player
  end

  def end_visit
    visit = @frame.current_visit
    return redirect_to @frame if visit.nil? || !visit.active?

    ended_by = params[:ended_by].presence_in(%w[miss foul conceded]) || "miss"
    visit.update!(ended_by: ended_by)

    next_player = visit.player == @frame.match.player1 ? @frame.match.player2 : @frame.match.player1
    next_visit = @frame.visits.create!(
      player: next_player,
      visit_number: visit.visit_number + 1
    )

    MatchChannel.broadcast_frame_update(@frame)

    respond_to do |format|
      format.html { redirect_to frame_path(@frame) }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("frame-#{@frame.id}", partial: "frames/frame", locals: { frame: @frame.reload }) }
    end
  end

  def complete
    winner_id = params[:winner_id]
    winner = @frame.match.player1_id.to_s == winner_id ? @frame.match.player1 : @frame.match.player2

    @frame.current_visit&.update!(ended_by: :frame_end)
    @frame.update!(status: :completed, winner: winner)

    match = @frame.match
    check_match_complete(match)

    MatchChannel.broadcast_frame_update(@frame)

    respond_to do |format|
      format.html { redirect_to match_path(match) }
      format.turbo_stream
    end
  end

  private

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
        status: :in_progress
      )
      match.update!(current_frame: new_frame)
      new_frame.visits.create!(player: next_breaker, visit_number: 1)
    end
  end
end
