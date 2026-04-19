class UsersController < ApplicationController
  before_action :require_superuser!, except: [ :stats ]
  before_action :authenticate_user!, only: [ :stats ]

  def stats
    @user = User.find(params[:id])
    redirect_to root_path, alert: "Not authorized." and return unless @user == current_user

    trends_since = case params[:range]
    when "30d"  then 30.days.ago
    when "90d"  then 90.days.ago
    when "180d" then 180.days.ago
    when "365d" then 365.days.ago
    end

    completed_match_ids = @user.matches
                               .where(status: :completed, scoring_mode: :granular)
                               .ids
    completed_frame_ids = Frame.where(match_id: completed_match_ids, status: :completed).ids

    # Record counts — pure SQL, no rows loaded into memory
    @matches_played = completed_match_ids.size
    frames_won_per_match  = Frame.where(match_id: completed_match_ids, status: :completed, winner_id: @user.id)
                                 .group(:match_id).count
    frames_lost_per_match = Frame.where(match_id: completed_match_ids, status: :completed)
                                 .where.not(winner_id: [ @user.id, nil ])
                                 .group(:match_id).count
    @matches_won  = frames_won_per_match.count { |match_id, won| won > frames_lost_per_match[match_id].to_i }
    @matches_lost = @matches_played - @matches_won

    @frames_played = completed_frame_ids.size
    @frames_won    = Frame.where(id: completed_frame_ids, winner_id: @user.id).count
    @frames_lost   = @frames_played - @frames_won

    # Lifetime stats via SQL aggregates — no visits/shots loaded into memory
    my_visits  = Visit.where(frame_id: completed_frame_ids, player_id: @user.id)
    opp_visits = Visit.where(frame_id: completed_frame_ids).where.not(player_id: @user.id)

    @for_stats     = SqlStats.new(@user, my_visits, opp_visits)
    @against_stats = SqlStats.new(Struct.new(:id, :name).new(-1, "Opponents"), opp_visits, my_visits)

    # Trends: load only the date-filtered frames with visits/shots
    trend_frame_scope = Frame.where(id: completed_frame_ids)
    trend_frame_scope = trend_frame_scope.where("completed_at >= ?", trends_since) if trends_since
    trend_frames = trend_frame_scope.includes(visits: [ :shots, :player ]).order(:completed_at)

    # Per-frame dataset for trends tab (in-memory Stats fine — one frame at a time)
    @frame_series = trend_frames.map do |frame|
      frame_visits = frame.visits.select { |v| v.player_id == @user.id }
      s = Stats.new(@user, frame.visits, player_visits: frame_visits)
      {
        date:             frame.completed_at&.strftime("%Y-%m-%d"),
        points:           s.total_score,
        highest_break:    s.highest_break,
        breaks:           s.number_of_breaks,
        multi_pot_breaks: s.multi_pot_breaks,
        fouls:            s.fouls_committed
      }
    end
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
