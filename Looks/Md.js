.pragma library

// Shared markdown grid helpers for shop items and creature parts.

var COLS = 12
var ROWS = 11
var MAX_FRAMES = 5

function trim(s) {
  return String(s || "").replace(/^\s+|\s+$/g, "")
}

function slug(name) {
  return String(name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
}

function cleanId(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9_-]/g, "")
}

function blankFrame() {
  var rows = []
  for (var y = 0; y < ROWS; y++) rows.push("............")
  return rows
}

function normalizeFrame(lines) {
  var rows = []
  for (var y = 0; y < ROWS; y++) {
    var row = String(lines[y] || "")
    if (row.length < COLS)
      row += new Array(COLS - row.length + 1).join(".")
    rows.push(row.substring(0, COLS))
  }
  return rows
}

function extractFences(body, maxFrames) {
  var limit = maxFrames > 0 ? maxFrames : 99
  var frames = []
  var i = 0
  var src = String(body || "")
  while (i < src.length && frames.length < limit) {
    var start = src.indexOf("```", i)
    if (start < 0) break
    var nl = src.indexOf("\n", start)
    if (nl < 0) break
    var end = src.indexOf("```", nl + 1)
    if (end < 0) break
    var lines = src.substring(nl + 1, end).split("\n")
    while (lines.length && trim(lines[lines.length - 1]) === "") lines.pop()
    frames.push(normalizeFrame(lines))
    i = end + 3
  }
  return frames
}

function parseMeta(line) {
  var m = /^([a-zA-Z][a-zA-Z0-9_-]*)\s*:\s*(.*)$/.exec(trim(line))
  if (!m) return null
  return { key: m[1].toLowerCase(), val: trim(m[2]) }
}

function headingTitle(line) {
  return trim(String(line || "").replace(/^#+\s*/, ""))
}

function splitMarked(text, marker) {
  var out = []
  var chunks = String(text || "").split(marker)
  for (var i = 0; i < chunks.length; i++) {
    var chunk = trim(chunks[i])
    if (!chunk) continue
    var nl = chunk.indexOf("\n")
    out.push({
      header: trim(nl >= 0 ? chunk.substring(0, nl) : chunk),
      body: nl >= 0 ? chunk.substring(nl + 1) : ""
    })
  }
  return out
}

function headerTag(header) {
  var bits = trim(header).split(/\s+/)
  return bits[0] || ""
}
