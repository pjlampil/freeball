class StreamChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_#{params[:match_id]}"
  end

  # Relay any WebRTC signaling message to all subscribers.
  # Clients filter by the `to` field.
  def signal(data)
    ActionCable.server.broadcast("stream_#{params[:match_id]}", data)
  end
end
