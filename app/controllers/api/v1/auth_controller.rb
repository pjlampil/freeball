class Api::V1::AuthController < ActionController::API
  before_action :authenticate_user!, only: [ :logout, :register ]

  def register
    return render json: { error: "Not authorized." }, status: :forbidden unless current_user&.superuser?

    user = User.new(register_params)
    if user.save
      token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      render json: {
        user: user_json(user),
        token: token
      }, status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end

  def login
    user = User.find_by(email: params[:email])
    if user&.valid_password?(params[:password])
      token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
      render json: {
        user: user_json(user),
        token: token
      }
    else
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end

  def logout
    current_user.update!(jti: SecureRandom.uuid)
    head :no_content
  end

  private

  def register_params
    params.permit(:name, :email, :password, :password_confirmation)
  end

  def user_json(user)
    { id: user.id, name: user.name, email: user.email }
  end
end
