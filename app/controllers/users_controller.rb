class UsersController < ApplicationController
  before_action :require_superuser!

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to users_path, notice: "User #{@user.name} created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :superuser)
  end

  def require_superuser!
    redirect_to root_path, alert: "Not authorized." unless current_user&.superuser?
  end
end
