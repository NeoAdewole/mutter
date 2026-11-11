import { Controller } from "@hotwired/stimulus"

// Behavior for shared/_carousel. All styling is Tailwind utilities in the
// markup; this only drives which slide is showing. The track is a native
// scroll-snap container, so touch swiping and (via motion-safe:scroll-smooth
// on the track) reduced-motion handling come from the browser and CSS.
export default class extends Controller {
  static targets = ["track", "slide", "indicator"]
  static values = { index: { type: Number, default: 0 } }

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
  }

  goTo(index) {
    this.trackTarget.scrollTo({ left: index * this.trackTarget.clientWidth })
  }
}
