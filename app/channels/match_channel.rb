class MatchChannel < ApplicationCable::Channel
  def subscribed
    stream_from "match_#{params[:match_id]}"
  end

  def unsubscribed
  end

  def self.broadcast_frame_update(frame)
    frame = Frame.includes(match: [ :player1, :player2 ]).find(frame.id)
    match = frame.match
    visits = match.frames.includes(visits: [ :shots, :player ]).flat_map(&:visits)

    player1 = match.player1
    player2 = match.player2

    scoreboard_html = ApplicationController.render(
      partial: "frames/scoreboard",
      locals: { frame: frame }
    )
    stats_html = ApplicationController.render(
      partial: "shared/stats_table",
      locals: {
        p1_stats: Stats.new(player1, visits),
        p2_stats: Stats.new(player2, visits)
      }
    )
    recent_visits_html = ApplicationController.render(
      partial: "frames/recent_visits",
      locals: { frame: frame }
    )

    ActionCable.server.broadcast("match_#{frame.match_id}", {
      type: "frame_update",
      frame_id: frame.id,
      frame_paused_at: frame.paused_at&.to_i,
      scoreboard_html: scoreboard_html,
      stats_html: stats_html,
      recent_visits_html: recent_visits_html
    })
  end
end
