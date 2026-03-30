// MatchChannel is used by native/API clients only.
// Web live updates are handled by turbo_stream_from in frames/show.html.erb.
import consumer from "channels/consumer"

consumer.subscriptions.create("MatchChannel", {
  received(data) {
    // Native app hook: data = { type: "frame_update", frame_id: N }
  }
});
