import { Controller } from "@hotwired/stimulus"

// Radix's Avatar renders the image only once it has loaded and the fallback
// only until then. Mirrors that with the already-rendered elements.
export default class extends Controller {
  static targets = [ "image", "fallback" ]

  connect() {
    if (!this.hasImageTarget) return

    const image = this.imageTarget
    if (!image.getAttribute("src")) return this.showFallback()

    if (image.complete) {
      image.naturalWidth > 0 ? this.showImage() : this.showFallback()
    } else {
      this.showFallback()
      image.addEventListener("load", () => this.showImage(), { once: true })
      image.addEventListener("error", () => this.showFallback(), { once: true })
    }
  }

  showImage() {
    this.imageTarget.hidden = false
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = true
  }

  showFallback() {
    if (this.hasImageTarget) this.imageTarget.hidden = true
    if (this.hasFallbackTarget) this.fallbackTarget.hidden = false
  }
}
