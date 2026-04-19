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

    match_ids = @user.matches.where(status: :completed, scoring_mode: :granular).ids

    # Lifetime stats: load all frames/visits (no date filter)
    completed_matches = Match.where(id: match_ids)
                             .includes(frames: { visits: [ :shots, :player ] })

    all_frames = completed_matches.flat_map(&:frames).select(&:completed?)
                                  .sort_by { |f| f.completed_at || Time.at(0) }
    all_visits = all_frames.flat_map(&:visits)

    # Trends: scope frames by date at the DB level before eager loading visits
    trend_frame_scope = Frame.where(match_id: match_ids, status: :completed)
    trend_frame_scope = trend_frame_scope.where("completed_at >= ?", trends_since) if trends_since
    trend_frames = trend_frame_scope.includes(visits: [ :shots, :player ])
                                    .order(:completed_at)

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

    # Per-frame dataset for trends tab (date-filtered at DB level)
    @frame_series = trend_frames.map do |frame|
      frame_visits   = frame.visits.select { |v| v.player_id == @user.id }
      frame_opp      = frame.visits.reject { |v| v.player_id == @user.id }
      s              = Stats.new(@user, frame.visits, player_visits: frame_visits)
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
