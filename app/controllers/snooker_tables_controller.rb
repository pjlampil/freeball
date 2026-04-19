class SnookerTablesController < ApplicationController
  before_action :require_superuser!
  before_action :set_venue

  def new
    @snooker_table = @venue.snooker_tables.build
  end

  def create
    @snooker_table = @venue.snooker_tables.build(table_params)
    if @snooker_table.save
      redirect_to venues_path, notice: "Table added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @venue.snooker_tables.find(params[:id]).destroy!
    redirect_to venues_path, notice: "Table removed."
  end

  private

  def set_venue
    @venue = Venue.find(params[:venue_id])
  end

  def table_params
    params.require(:snooker_table).permit(:number, :name)
  end

  def require_superuser!
    redirect_to root_path, alert: "Not authorized." unless current_user&.superuser?
  end
end
