class MatchChannel < ApplicationCable::Channel
  def subscribed
    stream_from "match_#{params[:match_id]}"
  end

  def unsubscribed
  end

  def self.broadcast_frame_update(frame)
    match = frame.match
    visits = match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)

    scoreboard_html = ApplicationController.render(
      partial: "frames/scoreboard",
      locals: { frame: frame }
    )
    stats_html = ApplicationController.render(
      partial: "shared/stats_table",
      locals: {
        p1_stats: Stats.new(match.player1, visits),
        p2_stats: Stats.new(match.player2, visits)
      }
    )

    ActionCable.server.broadcast("match_#{frame.match_id}", {
      type: "frame_update",
      frame_id: frame.id,
      scoreboard_html: scoreboard_html,
      stats_html: stats_html
    })
  end
end
