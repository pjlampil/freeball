class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :authenticate_user!

  def after_sign_in_path_for(resource)
    matches_path
  end
end
