.pragma library
.import "../Md.js" as Md

// Parse hat/toy markdown. One file can hold several items (each starts with #).

var POSES = { idle: true, walk: true, dance: true, jump: true }

function kindFrom(folder, fallback) {
  if (folder === "toys" || folder === "toy" || fallback === "toy") return "toy"
  return "hat"
}

function parseSection(text, fallbackKind) {
  var item = {
    id: "",
    name: "",
    kind: kindFrom(fallbackKind),
    cost: 0,
    pose: "idle",
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
      else if (meta.key === "pose" && POSES[meta.val]) item.pose = meta.val
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
  if (item.kind === "hat") item.pose = "idle"
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
  var byId = {}
  var chunks = Md.splitMarked(text, "___TAM_ITEM___")
  for (var i = 0; i < chunks.length; i++) {
    var kindFolder = Md.headerTag(chunks[i].header) || "hats"
    var parsed = parseDocument(chunks[i].body, kindFolder)
    for (var j = 0; j < parsed.length; j++) {
      var item = parsed[j]
      item.kind = kindFrom(kindFolder)
      if (item.id) byId[item.kind + ":" + item.id] = item
    }
  }
  for (var key in byId) {
    var it = byId[key]
    if (it.kind === "toy") toys.push(it)
    else hats.push(it)
  }
  return { hats: hats, toys: toys }
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
