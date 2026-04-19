class VenuesController < ApplicationController
  before_action :require_superuser!
  before_action :set_venue, only: [ :edit, :update, :destroy ]

  def index
    @venues = Venue.includes(:snooker_tables).order(:name)
  end

  def new
    @venue = Venue.new
  end

  def create
    @venue = Venue.new(venue_params)
    if @venue.save
      redirect_to venues_path, notice: "Venue created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @venue.update(venue_params)
      redirect_to venues_path, notice: "Venue updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @venue.destroy!
    redirect_to venues_path, notice: "Venue deleted."
  end

  private

  def set_venue
    @venue = Venue.find(params[:id])
  end

  def venue_params
    params.require(:venue).permit(:name)
  end

  def require_superuser!
    redirect_to root_path, alert: "Not authorized." unless current_user&.superuser?
  end
end
