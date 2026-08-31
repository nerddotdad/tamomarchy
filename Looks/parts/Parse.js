.pragma library
.import "../Md.js" as Md

// Creature part markdown. Each file is one part; ## headings are poses.

var SLOTS = ["bodies", "heads", "horns", "arms", "legs", "tails"]

function poseKey(title) {
  var t = Md.trim(title).toLowerCase().replace(/\s+/g, "")
  if (t === "walka") return "walkA"
  if (t === "walkb") return "walkB"
  if (t === "dancea") return "danceA"
  if (t === "danceb") return "danceB"
  if (t === "idle" || t === "walk" || t === "dance" || t === "watch"
      || t === "eat" || t === "sit" || t === "sleep" || t === "sad")
    return t
  return ""
}

function applyFrames(piece, key, frames) {
  if (!frames || !frames.length) return
  if (key === "walk") {
    piece.walkA = frames[0]
    piece.walkB = frames[1] || frames[0]
    return
  }
  if (key === "dance") {
    piece.danceA = frames[0]
    piece.danceB = frames[1] || frames[0]
    return
  }
  piece[key] = frames[0]
}

function parsePart(text, fallbackId) {
  var src = String(text || "").replace(/\r\n/g, "\n")
  var piece = { id: "", name: "", idle: Md.blankFrame() }
  var blocks = src.split(/\n(?=##\s+)/)
  var lead = blocks.length ? blocks[0] : ""
  var lines = lead.split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.charAt(0) === "#" && line.charAt(1) !== "#") {
      if (!piece.name) piece.name = Md.headingTitle(line)
      continue
    }
    var meta = Md.parseMeta(line)
    if (meta && meta.key === "id") piece.id = meta.val
    if (meta && meta.key === "name") piece.name = meta.val
  }
  var leadFrames = Md.extractFences(lead)
  if (leadFrames.length) applyFrames(piece, "idle", leadFrames)
  for (var b = 1; b < blocks.length; b++) {
    var chunk = blocks[b]
    var nl = chunk.indexOf("\n")
    var heading = Md.headingTitle(nl >= 0 ? chunk.substring(0, nl) : chunk)
    var body = nl >= 0 ? chunk.substring(nl + 1) : ""
    var key = poseKey(heading)
    if (!key) continue
    applyFrames(piece, key, Md.extractFences(body))
  }
  if (!piece.id) piece.id = Md.slug(piece.name || fallbackId)
  piece.id = Md.cleanId(piece.id)
  piece.name = piece.name || piece.id
  if (!piece.idle) piece.idle = Md.blankFrame()
  return piece.id ? piece : null
}

function emptySlot() {
  return { ids: [], byId: {} }
}

function emptySet() {
  var set = {}
  for (var i = 0; i < SLOTS.length; i++) set[SLOTS[i]] = emptySlot()
  return set
}

function parseBundle(text) {
  var set = emptySet()
  var chunks = Md.splitMarked(text, "___TAM_PART___")
  for (var i = 0; i < chunks.length; i++) {
    var slot = Md.headerTag(chunks[i].header)
    if (!set[slot]) continue
    var piece = parsePart(chunks[i].body, chunks[i].header)
    if (!piece) continue
    if (set[slot].byId[piece.id]) {
      var idx = set[slot].ids.indexOf(piece.id)
      if (idx >= 0) set[slot].ids.splice(idx, 1)
    }
    set[slot].byId[piece.id] = piece
    set[slot].ids.push(piece.id)
  }
  return set
}

function slotIds(parts, slot) {
  if (!parts || !parts[slot] || !parts[slot].ids) return []
  return parts[slot].ids
}

function pieceOf(parts, slot, id) {
  if (!parts || !parts[slot] || !parts[slot].byId || !id) return null
  var piece = parts[slot].byId[id]
  return piece && piece.idle ? piece : null
}
