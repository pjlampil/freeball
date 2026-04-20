class ShotsController < ApplicationController
  before_action :set_visit

  def create
    @frame = @visit.frame
    shot_params_data = shot_params

    if shot_params_data[:result] == "foul"
      shot_params_data[:foul_value] ||= 4
    end

    if shot_params_data[:result] == "potted"
      valid = @frame.valid_balls
      submitted = shot_params_data[:ball]&.to_sym
      unless valid.include?(submitted)
        MatchChannel.broadcast_frame_update(@frame)
        return respond_to do |format|
          format.json { render json: { error: "invalid ball" }, status: :unprocessable_entity }
          format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
        end
      end
    end

    @shot = @visit.shots.build(shot_params_data)
    @shot.sequence = @visit.shots.count + 1

    if @shot.save
      @frame.reload

      if @shot.potted? && @shot.red? && @frame.reds_remaining == 0 && @frame.reds_cleared_at.nil?
        @frame.update!(reds_cleared_at: Time.current)
        @frame.reload
      end

      if frame_over?
        if !@frame.respotted_black? && @frame.score_winner.nil?
          # Scores level after last black — re-spot
          @visit.update!(ended_by: @shot.foul? ? :foul : :frame_end)
          next_player = @visit.player == @frame.match.player1 ? @frame.match.player2 : @frame.match.player1
          @frame.update!(respotted_black: true)
          @frame.visits.create!(player: next_player, visit_number: @visit.visit_number + 1)
        else
          @visit.update!(ended_by: @shot.foul? ? :foul : :frame_end)
          @frame.update!(pending_winner: @frame.score_winner)
        end
      elsif @shot.foul?
        @visit.update!(ended_by: :foul)
        next_player = @visit.player == @frame.match.player1 ? @frame.match.player2 : @frame.match.player1
        if @frame.match.stop_after_reds? && @frame.reds_remaining == 0
          if @frame.score_winner
            @frame.update!(pending_winner: @frame.score_winner)
          else
            # Scores level — re-spot the black to decide the frame
            @frame.update!(respotted_black: true)
            @frame.visits.create!(player: next_player, visit_number: @visit.visit_number + 1)
          end
        else
          @frame.visits.create!(player: next_player, visit_number: @visit.visit_number + 1)
        end
      end

      MatchChannel.broadcast_frame_update(@frame)
      respond_to do |format|
        format.json { render json: @shot, status: :created }
        format.any  { render partial: "frames/frame", locals: { frame: @frame.reload } }
      end
    else
      respond_to do |format|
        format.json { render json: { errors: @shot.errors }, status: :unprocessable_entity }
        format.any { redirect_to frame_path(@frame), alert: @shot.errors.full_messages.join(", ") }
      end
    end
  end

  private

  def frame_over?
    return (@shot.potted? || @shot.foul?) if @frame.respotted_black?
    (@shot.potted? && @frame.valid_balls.empty?) ||
      (@shot.foul? && @frame.black_is_last_remaining?)
  end

  def check_match_complete(match)
    needed = match.frames_needed_to_win

    if needed && (match.player1_frames >= needed || match.player2_frames >= needed)
      match.update!(status: :completed, current_frame: nil)
      return
    end

    # Open-ended match or win threshold not yet reached — start the next frame
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

  def set_visit
    @visit = Visit.find(params[:visit_id])
  end

  def shot_params
    params.require(:shot).permit(:ball, :result, :foul_value)
  end
end
