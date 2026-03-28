class Api::V1::VisitsController < Api::V1::BaseController
  before_action :set_frame

  def index
    visits = @frame.visits.includes(:shots).order(:visit_number)
    render json: visits.map { |v| visit_json(v) }
  end

  def create
    visit = @frame.visits.build(visit_params)
    visit.visit_number = @frame.visits.count + 1
    visit.save!
    render json: visit_json(visit), status: :created
  end

  private

  def set_frame
    @frame = Frame.find(params[:frame_id])
  end

  def visit_params
    params.require(:visit).permit(:player_id)
  end

  def visit_json(visit)
    {
      id: visit.id,
      player_id: visit.player_id,
      visit_number: visit.visit_number,
      ended_by: visit.ended_by,
      break_score: visit.break_score,
      shots: visit.shots.map { |s|
        { id: s.id, ball: s.ball, result: s.result, points: s.points, foul_value: s.foul_value, sequence: s.sequence }
      }
    }
  end
end
