// Read-only Twitch chat over Twitch's public IRC-over-WebSocket gateway, using
// an anonymous "justinfan" login. Reading a public channel needs no OAuth
// token, so nothing secret is stored or sent from the browser.
//
// Every provider module in this folder exports the same
//   connect(channel, { onMessage, onStatus }) -> { close() }
// where onStatus(state, detail) is one of "connecting" | "connected" |
// "reconnecting" | "error" and onMessage receives
//   { provider, channel, author, color, action, parts: [{ type: "text", value } | { type: "emote", id, name }] }

const ENDPOINT = "wss://irc-ws.chat.twitch.tv:443"
const CHANNEL_PATTERN = /^[A-Za-z0-9_]{1,25}$/
const EMOTE_ID_PATTERN = /^[A-Za-z0-9_]+$/
const COLOR_PATTERN = /^#[0-9A-Fa-f]{6}$/
const MAX_RETRY_DELAY_MS = 30000

const TAG_ESCAPES = { ":": ";", s: " ", r: "\r", n: "\n", "\\": "\\" }

export function unescapeTag(value) {
  return value.replace(/\\(.)/g, (_, char) => TAG_ESCAPES[char] ?? char)
}

// "@k=v;k2=v2 :nick!nick@nick.tmi.twitch.tv PRIVMSG #chan :hello" -> parts
export function parseIrcLine(line) {
  let rest = line
  const tags = {}

  if (rest.startsWith("@")) {
    const space = rest.indexOf(" ")
    for (const pair of rest.slice(1, space).split(";")) {
      const eq = pair.indexOf("=")
      if (eq === -1) tags[pair] = ""
      else tags[pair.slice(0, eq)] = unescapeTag(pair.slice(eq + 1))
    }
    rest = rest.slice(space + 1)
  }

  let prefix = null
  if (rest.startsWith(":")) {
    const space = rest.indexOf(" ")
    prefix = rest.slice(1, space)
    rest = rest.slice(space + 1)
  }

  let trailing = null
  const trailingStart = rest.indexOf(" :")
  if (trailingStart !== -1) {
    trailing = rest.slice(trailingStart + 2)
    rest = rest.slice(0, trailingStart)
  }

  const [command, ...params] = rest.split(" ").filter(Boolean)
  return { tags, prefix, command, params, trailing }
}

// Split message text into text runs and emotes. The emotes tag
// ("25:0-4,12-16/1902:6-10") indexes by Unicode code point, not UTF-16 unit.
export function buildParts(text, emotesTag) {
  const chars = Array.from(text)
  const ranges = []

  for (const entry of (emotesTag || "").split("/")) {
    const [id, positions] = entry.split(":")
    if (!id || !positions || !EMOTE_ID_PATTERN.test(id)) continue

    for (const range of positions.split(",")) {
      const [start, end] = range.split("-").map(Number)
      if (Number.isInteger(start) && Number.isInteger(end) && start >= 0 && end >= start && end < chars.length) {
        ranges.push({ id, start, end })
      }
    }
  }
  ranges.sort((a, b) => a.start - b.start)

  const parts = []
  let cursor = 0
  for (const { id, start, end } of ranges) {
    if (start < cursor) continue // overlapping/duplicate range

    if (start > cursor) parts.push({ type: "text", value: chars.slice(cursor, start).join("") })
    parts.push({ type: "emote", id, name: chars.slice(start, end + 1).join("") })
    cursor = end + 1
  }
  if (cursor < chars.length) parts.push({ type: "text", value: chars.slice(cursor).join("") })

  return parts
}

export function toChatMessage(parsed, channel) {
  if (parsed.command !== "PRIVMSG" || parsed.trailing === null) return null

  let text = parsed.trailing
  const action = /^\u0001ACTION (.*)\u0001$/.exec(text)
  if (action) text = action[1]

  const nick = parsed.prefix ? parsed.prefix.split("!")[0] : "unknown"
  return {
    provider: "twitch",
    channel,
    author: parsed.tags["display-name"] || nick,
    color: COLOR_PATTERN.test(parsed.tags.color || "") ? parsed.tags.color : null,
    action: Boolean(action),
    parts: buildParts(text, parsed.tags.emotes)
  }
}

export function connect(channel, { onMessage, onStatus }) {
  if (!CHANNEL_PATTERN.test(channel)) {
    onStatus("error", "Invalid channel name")
    return { close() {} }
  }

  const login = channel.toLowerCase()
  let socket = null
  let closed = false
  let joined = false
  let attempt = 0
  let retryTimer = null

  const scheduleReconnect = () => {
    attempt += 1
    const delay = Math.min(MAX_RETRY_DELAY_MS, 1000 * 2 ** Math.min(attempt, 5)) + Math.random() * 500
    onStatus("reconnecting")
    retryTimer = setTimeout(open, delay)
  }

  const handleLine = (line) => {
    const parsed = parseIrcLine(line)

    switch (parsed.command) {
      case "PING":
        socket.send(`PONG :${parsed.trailing ?? "tmi.twitch.tv"}`)
        break
      case "JOIN":
      case "366": // end of NAMES: the join succeeded
        if (!joined) {
          joined = true
          attempt = 0
          onStatus("connected")
        }
        break
      case "PRIVMSG": {
        const message = toChatMessage(parsed, login)
        if (message) onMessage(message)
        break
      }
      case "RECONNECT": // Twitch asking us to move servers
        socket.close()
        break
      case "NOTICE":
        if (!joined) onStatus("error", parsed.trailing || "Twitch refused the connection")
        break
    }
  }

  function open() {
    joined = false
    if (attempt === 0) onStatus("connecting")

    socket = new WebSocket(ENDPOINT)
    socket.addEventListener("open", () => {
      socket.send("CAP REQ :twitch.tv/tags twitch.tv/commands")
      socket.send("PASS SCHMOOPIIE")
      socket.send(`NICK justinfan${Math.floor(10000 + Math.random() * 80000)}`)
      socket.send(`JOIN #${login}`)
    })
    socket.addEventListener("message", (event) => {
      String(event.data).split("\r\n").filter(Boolean).forEach(handleLine)
    })
    socket.addEventListener("close", () => {
      if (!closed) scheduleReconnect()
    })
  }

  open()

  return {
    close() {
      closed = true
      clearTimeout(retryTimer)
      socket?.close()
    }
  }
}
