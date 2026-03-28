class Api::V1::BaseController < ActionController::API
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable

  private

  def not_found(e)
    render json: { error: e.message }, status: :not_found
  end

  def unprocessable(e)
    render json: { errors: e.record.errors }, status: :unprocessable_entity
  end
end
