class ShotsController < ApplicationController
  before_action :set_visit

  def create
    @frame = @visit.frame
    shot_params_data = shot_params

    if shot_params_data[:result] == "foul"
      shot_params_data[:foul_value] ||= 4
    end

    @shot = @visit.shots.build(shot_params_data)
    @shot.sequence = @visit.shots.count + 1

    if @shot.save
      MatchChannel.broadcast_frame_update(@frame)
      respond_to do |format|
        format.html { redirect_to frame_path(@frame) }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("frame-#{@frame.id}", partial: "frames/frame", locals: { frame: @frame.reload }) }
        format.json { render json: @shot, status: :created }
      end
    else
      respond_to do |format|
        format.html { redirect_to frame_path(@frame), alert: @shot.errors.full_messages.join(", ") }
        format.json { render json: { errors: @shot.errors }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_visit
    @visit = Visit.find(params[:visit_id])
  end

  def shot_params
    params.require(:shot).permit(:ball, :result, :foul_value)
  end
end
