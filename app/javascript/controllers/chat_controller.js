import { Controller } from "@hotwired/stimulus"
import { connect as connectTwitch } from "chat/twitch"

// One merged chat feed for every connected channel. Each provider module in
// app/javascript/chat/ speaks its own protocol and hands back normalized
// messages; this controller only renders them and tracks connection state.
// Messages are built with DOM nodes/textContent (never innerHTML), because
// chat text is untrusted input.
const PROVIDERS = { twitch: connectTwitch }

const MAX_MESSAGES = 300
const STICK_TO_BOTTOM_PX = 48
const STATE_LABELS = { connecting: "Connecting", connected: "Live", reconnecting: "Reconnecting", error: "Error" }

// Full class strings so Tailwind's scanner picks them up.
const PROVIDER_BADGE_CLASSES = {
  twitch: "rounded bg-purple-600/80 px-1.5 py-0.5 text-[0.65rem] font-medium uppercase tracking-wide text-white"
}
const DEFAULT_BADGE_CLASSES = "rounded bg-gray-600/80 px-1.5 py-0.5 text-[0.65rem] font-medium uppercase tracking-wide text-white"

export default class extends Controller {
  static targets = ["feed", "status", "placeholder", "jump"]
  static values = { channels: Array }

  connect() {
    this.pinned = true
    this.connections = this.channelsValue.map((channel) => this.open(channel))
  }

  disconnect() {
    this.connections.forEach((connection) => connection.close())
    this.connections = []
  }

  open({ provider, channel }) {
    const key = `${provider}:${channel}`
    const client = PROVIDERS[provider]

    if (!client) {
      this.setStatus(key, "error", `No chat client for ${provider}`)
      return { close() {} }
    }

    return client(channel, {
      onMessage: (message) => this.append(message),
      onStatus: (state, detail) => this.setStatus(key, state, detail)
    })
  }

  trackScroll() {
    const { scrollTop, clientHeight, scrollHeight } = this.feedTarget
    this.pinned = scrollHeight - scrollTop - clientHeight < STICK_TO_BOTTOM_PX
    this.jumpTarget.hidden = this.pinned
  }

  jumpToLatest() {
    this.pinned = true
    this.jumpTarget.hidden = true
    this.feedTarget.scrollTop = this.feedTarget.scrollHeight
  }

  setStatus(key, state, detail) {
    const chip = this.statusTargets.find((element) => element.dataset.key === key)
    if (!chip) return

    chip.dataset.state = state
    chip.title = detail || ""
    const label = chip.querySelector("[data-chat-label]")
    if (label) label.textContent = STATE_LABELS[state] || state
  }

  append(message) {
    if (this.hasPlaceholderTarget) this.placeholderTarget.remove()

    this.feedTarget.append(this.render(message))
    while (this.feedTarget.childElementCount > MAX_MESSAGES) this.feedTarget.firstElementChild.remove()

    if (this.pinned) this.feedTarget.scrollTop = this.feedTarget.scrollHeight
  }

  render({ provider, channel, author, color, action, parts }) {
    const row = document.createElement("div")
    row.className = "flex flex-wrap items-baseline gap-x-2 py-0.5 [overflow-wrap:anywhere]"

    const source = document.createElement("span")
    source.className = PROVIDER_BADGE_CLASSES[provider] || DEFAULT_BADGE_CLASSES
    source.textContent = channel
    source.title = `${provider}: ${channel}`

    const name = document.createElement("span")
    name.className = "font-semibold"
    if (color) name.style.color = color
    name.textContent = action ? author : `${author}:`

    const body = document.createElement("span")
    body.className = action ? "italic text-gray-100" : "text-gray-100"
    if (action && color) body.style.color = color
    parts.forEach((part) => body.append(this.renderPart(part)))

    row.append(source, name, body)
    return row
  }

  renderPart(part) {
    if (part.type !== "emote") return document.createTextNode(part.value)

    const image = document.createElement("img")
    image.className = "inline-block h-5 align-middle"
    image.src = `https://static-cdn.jtvnw.net/emoticons/v2/${part.id}/default/dark/1.0`
    image.alt = part.name
    image.title = part.name
    image.loading = "lazy"
    return image
  }
}
