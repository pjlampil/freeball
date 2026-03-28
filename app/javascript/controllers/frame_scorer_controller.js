import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static values = { matchId: Number, frameId: Number }

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create(
      { channel: "MatchChannel", match_id: this.matchIdValue },
      {
        received: (data) => {
          if (data.type === "frame_update" && data.frame_id === this.frameIdValue) {
            this.reloadFrame()
          }
        }
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  reloadFrame() {
    // Turbo will handle the stream update; this is a fallback for non-turbo-stream
    // responses from other devices
    fetch(window.location.href, {
      headers: { "Accept": "text/vnd.turbo-stream.html" }
    })
      .then(r => r.text())
      .then(html => {
        const parser = new DOMParser()
        const doc = parser.parseFromString(html, "text/html")
        const frameEl = doc.getElementById(`frame-${this.frameIdValue}`)
        if (frameEl) {
          document.getElementById(`frame-${this.frameIdValue}`).innerHTML = frameEl.innerHTML
        }
      })
  }
}
