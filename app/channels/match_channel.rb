class MatchChannel < ApplicationCable::Channel
  def subscribed
    stream_from "match_#{params[:match_id]}"
  end

  def unsubscribed
  end

  def self.broadcast_frame_update(frame)
    ActionCable.server.broadcast("match_#{frame.match_id}", {
      frame_id: frame.id
    })
  end
end
