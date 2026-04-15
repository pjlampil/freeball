class UsersController < ApplicationController
  before_action :require_superuser!, except: [ :stats ]
  before_action :authenticate_user!, only: [ :stats ]

  def stats
    @user = User.find(params[:id])
    redirect_to root_path, alert: "Not authorized." and return unless @user == current_user

    completed_matches = @user.matches
                             .where(status: :completed, scoring_mode: :granular)
                             .includes(frames: { visits: [ :shots, :player ] })

    all_frames = completed_matches.flat_map(&:frames).select(&:completed?)
    all_visits = all_frames.flat_map(&:visits)

    @matches_played = completed_matches.count
    @matches_won    = completed_matches.count { |m| m.winner == @user }
    @matches_lost   = @matches_played - @matches_won

    @frames_played  = all_frames.count
    @frames_won     = all_frames.count { |f| f.winner == @user }
    @frames_lost    = @frames_played - @frames_won

    my_visits       = all_visits.select { |v| v.player_id == @user.id }
    opponent_visits = all_visits.reject { |v| v.player_id == @user.id }

    @for_stats     = Stats.new(@user, all_visits, player_visits: my_visits)
    @against_stats = Stats.new(Struct.new(:id, :name).new(-1, "Opponents"), all_visits, player_visits: opponent_visits)
  end

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
