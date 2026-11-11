import { Controller } from "@hotwired/stimulus"

// Behavior for shared/_carousel. All styling is Tailwind utilities in the
// markup; this only drives which slide is showing. The track is a native
// scroll-snap container, so touch swiping and (via motion-safe:scroll-smooth
// on the track) reduced-motion handling come from the browser and CSS.
//
// Slides can hold an embedded player (an iframe target with a data-src). Only
// the slide on screen has its player loaded, and only once the carousel has
// stopped moving, so streams don't all autoplay at once and swiping away
// stops one.
const SETTLE_MS = 300

export default class extends Controller {
  static targets = ["track", "slide", "indicator", "frame"]
  static values = { index: { type: Number, default: 0 } }

  disconnect() {
    clearTimeout(this.settleTimer)
    this.frameTargets.forEach((frame) => frame.removeAttribute("src"))
  }

  next() {
    this.goTo((this.indexValue + 1) % this.slideTargets.length)
  }

  previous() {
    this.goTo((this.indexValue - 1 + this.slideTargets.length) % this.slideTargets.length)
  }

  select({ params: { index } }) {
    this.goTo(index)
  }

  keydown(event) {
    if (event.key === "ArrowRight") this.next()
    else if (event.key === "ArrowLeft") this.previous()
    else return

    event.preventDefault()
  }

  // Fired as the track scrolls (button, indicator, key or swipe); keeps the
  // indicators in step with whichever slide is actually in view.
  sync() {
    const { scrollLeft, clientWidth } = this.trackTarget
    if (clientWidth === 0) return

    this.indexValue = Math.round(scrollLeft / clientWidth)
  }

  indexValueChanged() {
    this.indicatorTargets.forEach((indicator, i) => {
      if (i === this.indexValue) indicator.setAttribute("aria-current", "true")
      else indicator.removeAttribute("aria-current")
    })

    // Debounced: a smooth scroll across several slides passes through every
    // index on the way, and we don't want to load the players it passes over.
    clearTimeout(this.settleTimer)
    this.settleTimer = setTimeout(() => this.loadActivePlayerOnly(), SETTLE_MS)
  }

  loadActivePlayerOnly() {
    const active = this.slideTargets[this.indexValue]

    this.frameTargets.forEach((frame) => {
      if (active?.contains(frame)) {
        if (!frame.getAttribute("src")) frame.setAttribute("src", frame.dataset.src)
      } else {
        frame.removeAttribute("src")
      }
    })
  }

  goTo(index) {
    this.trackTarget.scrollTo({ left: index * this.trackTarget.clientWidth })
  }
}
