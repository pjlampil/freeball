module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # Anonymous connections are allowed so spectators can watch live matches
    # without signing in. Scoring actions are protected at the controller level.
  end
end
