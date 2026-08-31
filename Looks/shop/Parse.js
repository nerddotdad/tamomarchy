.pragma library
.import "../Md.js" as Md

// Parse hat/toy markdown. One file can hold several items (each starts with #).

var PLAYS = { roll: true, glide: true, jump: true, spin: true, throw: true, think: true }

var AUTOS = { hunger: true, potty: true, dirty: true, energy: true, mood: true }

function normalizePlay(play, pose, kind) {
  if (kind === "hat" || kind === "gear") return ""
  var s = String(play || pose || "").toLowerCase()
  if (PLAYS[s]) return s
  if (s === "dance" || s === "walk") return "roll"
  if (s === "jump") return "jump"
  return "think"
}

function normalizeAuto(auto, kind) {
  if (kind !== "gear") return ""
  var s = String(auto || "").toLowerCase()
  if (AUTOS[s]) return s
  if (s === "food" || s === "eat") return "hunger"
  if (s === "scoop" || s === "mess") return "potty"
  if (s === "bath" || s === "wash") return "dirty"
  if (s === "sleep" || s === "bed") return "energy"
  if (s === "play" || s === "happy") return "mood"
  return ""
}

function autoLabel(auto) {
  if (auto === "hunger") return "Hunger"
  if (auto === "potty") return "Potty"
  if (auto === "dirty") return "Dirty"
  if (auto === "energy") return "Sleep"
  if (auto === "mood") return "Play"
  return ""
}

function autoAbout(auto) {
  if (auto === "hunger") return "Hunger slowly refills on its own. The Eat mini-game is optional."
  if (auto === "potty") return "They use this instead of the floor. No more scooping."
  if (auto === "dirty") return "They wash themselves. Dirty fades without a Bath mini-game."
  if (auto === "energy") return "They put themselves to bed when tired and wake when rested."
  if (auto === "mood") return "Mood slowly recovers while they are up. The Play mini-game is optional."
  return ""
}

function kindFrom(folder, fallback) {
  var s = String(folder || fallback || "")
  if (s === "toys" || s === "toy") return "toy"
  if (s === "gear" || s === "utility" || s === "utilities") return "gear"
  return "hat"
}

function parseSection(text, fallbackKind) {
  var item = {
    id: "",
    name: "",
    kind: kindFrom(fallbackKind),
    cost: 0,
    play: "think",
    auto: "",
    about: "",
    frames: []
  }
  var lines = String(text || "").split("\n")
  var bodyLines = []
  var inFence = false
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line.indexOf("```") === 0) {
      inFence = !inFence
      bodyLines.push(line)
      continue
    }
    if (!inFence && line.charAt(0) === "#" && line.charAt(1) !== "#") {
      if (!item.name) item.name = Md.headingTitle(line)
      continue
    }
    var meta = !inFence ? Md.parseMeta(line) : null
    if (meta) {
      if (meta.key === "id") item.id = meta.val
      else if (meta.key === "name") item.name = meta.val
      else if (meta.key === "kind") item.kind = kindFrom(meta.val, item.kind)
      else if (meta.key === "cost") item.cost = Number(meta.val)
      else if (meta.key === "play" || meta.key === "animation" || meta.key === "pose")
        item.play = meta.val
      else if (meta.key === "auto" || meta.key === "stat" || meta.key === "covers")
        item.auto = meta.val
      else if (meta.key === "about" || meta.key === "blurb" || meta.key === "desc")
        item.about = meta.val
    }
    bodyLines.push(line)
  }
  item.frames = Md.extractFences(bodyLines.join("\n"), Md.MAX_FRAMES)
  if (!item.frames.length) item.frames = [Md.blankFrame()]
  if (!item.id) item.id = Md.slug(item.name)
  item.id = Md.cleanId(item.id)
  item.name = item.name || item.id
  item.cost = Math.floor(Number(item.cost))
  if (!isFinite(item.cost) || item.cost < 0) item.cost = 0
  item.play = normalizePlay(item.play, "", item.kind)
  item.auto = normalizeAuto(item.auto, item.kind)
  item.about = Md.trim(item.about)
  if (item.kind === "gear" && !item.about) item.about = autoAbout(item.auto)
  return item
}

function parseDocument(text, fallbackKind) {
  var items = []
  var parts = String(text || "").replace(/\r\n/g, "\n").split(/\n(?=# )/g)
  for (var i = 0; i < parts.length; i++) {
    var chunk = Md.trim(parts[i])
    if (!chunk) continue
    var item = parseSection(chunk, fallbackKind)
    if (item.id) items.push(item)
  }
  return items
}

function parseBundle(text) {
  var hats = []
  var toys = []
  var gear = []
  var byId = {}
  var chunks = Md.splitMarked(text, "___TAM_ITEM___")
  for (var i = 0; i < chunks.length; i++) {
    var kindFolder = Md.headerTag(chunks[i].header) || "hats"
    var parsed = parseDocument(chunks[i].body, kindFolder)
    for (var j = 0; j < parsed.length; j++) {
      var item = parsed[j]
      item.kind = kindFrom(kindFolder)
      item.play = normalizePlay(item.play, "", item.kind)
      item.auto = normalizeAuto(item.auto, item.kind)
      if (item.kind === "gear" && !item.about) item.about = autoAbout(item.auto)
      if (item.id) byId[item.kind + ":" + item.id] = item
    }
  }
  for (var key in byId) {
    var it = byId[key]
    if (it.kind === "toy") toys.push(it)
    else if (it.kind === "gear") gear.push(it)
    else hats.push(it)
  }
  return { hats: hats, toys: toys, gear: gear }
}

function findById(list, id) {
  if (!list || !id) return null
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) return list[i]
  }
  return null
}

function shopFrame(item, frame) {
  if (!item || !item.frames || !item.frames.length) return Md.blankFrame()
  var n = Math.min(item.frames.length, Md.MAX_FRAMES)
  var i = Math.floor(Number(frame) || 0) % n
  if (i < 0) i += n
  return item.frames[i]
}
