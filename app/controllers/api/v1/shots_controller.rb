class Api::V1::ShotsController < Api::V1::BaseController
  before_action :set_visit

  def create
    params_data = shot_params
    params_data[:foul_value] ||= 4 if params_data[:result] == "foul"

    shot = @visit.shots.build(params_data)
    shot.sequence = @visit.shots.count + 1
    shot.save!

    MatchChannel.broadcast_frame_update(@visit.frame)

    render json: {
      id: shot.id,
      ball: shot.ball,
      result: shot.result,
      points: shot.points,
      foul_value: shot.foul_value,
      sequence: shot.sequence
    }, status: :created
  end

  private

  def set_visit
    @visit = Visit.find(params[:visit_id])
  end

  def shot_params
    params.require(:shot).permit(:ball, :result, :foul_value)
  end
end
