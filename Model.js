.import "Looks/Egg.js" as Egg
.import "Looks/Mess.js" as Mess
.import "Looks/Grave.js" as Grave
.import "Looks/Md.js" as Md
.import "Looks/shop/Parse.js" as Shop
.import "Looks/parts/Parse.js" as Parts

// Tamagotchi stats, mood, and stitched part sprites (Looks/parts/*/*.md).

var STAT_MAX = 100
var NAME_MAX = 18

// Wallet is stored as copper. 100 copper = 1 silver, 100 silver = 1 gold.
var COPPER_PER_SILVER = 100
var SILVER_PER_GOLD = 100
var COPPER_PER_GOLD = COPPER_PER_SILVER * SILVER_PER_GOLD
var COPPER_ACCRUE_MS = 60 * 1000
var COPPER_NODEATH_MULT = 3

function coinsFromCopper(n) {
  var copper = Math.max(0, Math.floor(Number(n) || 0))
  return {
    gold: Math.floor(copper / COPPER_PER_GOLD),
    silver: Math.floor((copper % COPPER_PER_GOLD) / COPPER_PER_SILVER),
    copper: copper % COPPER_PER_SILVER
  }
}

function formatCoins(n) {
  var c = coinsFromCopper(n)
  var parts = []
  if (c.gold) parts.push(c.gold + "g")
  if (c.silver) parts.push(c.silver + "s")
  if (c.copper || !parts.length) parts.push(c.copper + "c")
  return parts.join(" ")
}

// Real-time decay on Medium: a full belly lasts ~40 minutes, mood ~70 minutes,
// and walking energy ~2 hours. Easy is half that drop; Hard is twice.
// Sleep refill stays the same (~6 minutes to full).
var DIFFICULTIES = ["easy", "medium", "hard"]
var DECAY_RATE = { easy: 0.5, medium: 1, hard: 2 }
var HUNGER_DECAY_PER_MS = STAT_MAX / (40 * 60 * 1000)
var HAPPY_DECAY_PER_MS = STAT_MAX / (70 * 60 * 1000)
var ENERGY_WALK_PER_MS = STAT_MAX / (120 * 60 * 1000)
var ENERGY_SLEEP_PER_MS = STAT_MAX / (6 * 60 * 1000)
var DIRTY_IDLE_PER_MS = STAT_MAX / (180 * 60 * 1000)
var DIRTY_WALK_PER_MS = STAT_MAX / (90 * 60 * 1000)
var BATH_HAPPY = 20
var SCOOP_HAPPY = 4

var FEED_HUNGER = 38
var FEED_HAPPY = 6
var PLAY_HAPPY = 32
var PLAY_ENERGY = 18
var PLAY_HUNGER = 10
var PET_HAPPY = 12
var NIBBLE_HUNGER = 16
var LULLABY_ENERGY = STAT_MAX / 8
var LULLABY_HAPPY = 10

var SPRITE_COLS = Md.COLS
var SPRITE_ROWS = Md.ROWS
var MESS_COLS = 12
var MESS_ROWS = 12
var MESS_PIXEL = 5
var MESS_SCOOP_RADIUS = 40

var DIRT_SPOTS = [
  [3, 5, 0], [8, 6, 1], [5, 8, 2], [4, 6, 0], [7, 8, 1],
  [6, 5, 2], [2, 7, 0], [9, 7, 1], [5, 4, 2], [4, 9, 0],
  [7, 5, 1], [3, 8, 2], [8, 8, 0], [6, 9, 1], [4, 4, 2],
  [5, 7, 0], [2, 6, 1], [9, 6, 2]
]

var GENOME_SLOTS = [
  ["body", "bodies", "round"],
  ["head", "heads", "round"],
  ["hat", "horns", "none"],
  ["arms", "arms", "stubs"],
  ["legs", "legs", "stubs"],
  ["tail", "tails", "none"]
]

var MESS_STALE_MS = 4 * 60 * 1000
var MESS_EXPIRE_MS = 12 * 60 * 1000
var HAPPY_STALE_MESS_PER_MS = STAT_MAX / (18 * 60 * 1000)
var MAX_MESS_EACH = 20
var POTTY_PER_MESS = STAT_MAX / (MAX_MESS_EACH * 2)
var STINKY_MESS_MIN = 4
var STARVE_MS = 12 * 60 * 1000
var LONELY_MS = 20 * 60 * 1000
var MAX_GRAVES = 36

function clamp(value, min, max) {
  var n = Number(value)
  if (!isFinite(n)) return min
  if (n < min) return min
  if (n > max) return max
  return n
}

function barFull(value) {
  return Number(value) >= STAT_MAX - 0.5
}

function stepsToFill(current, perStep) {
  var left = STAT_MAX - Number(current)
  var step = Number(perStep)
  if (!(step > 0)) step = 1
  if (left <= 0.5) return 1
  return Math.max(1, Math.ceil(left / step))
}

function normalizeMess(raw) {
  if (!Array.isArray(raw)) return []
  var poop = 0
  var pee = 0
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var m = raw[i]
    if (!m || (m.kind !== "poop" && m.kind !== "pee")) continue
    if (m.kind === "poop") {
      if (poop >= MAX_MESS_EACH) continue
      poop++
    } else {
      if (pee >= MAX_MESS_EACH) continue
      pee++
    }
    var x = Number(m.x)
    var y = Number(m.y)
    var born = Number(m.bornAt)
    if (!isFinite(x) || !isFinite(y)) continue
    out.push({
      kind: m.kind,
      x: x,
      y: y,
      bornAt: isFinite(born) && born > 0 ? born : Date.now(),
      output: m.output ? String(m.output) : ""
    })
  }
  return out
}

function normalizeGraves(raw, parts) {
  if (!Array.isArray(raw)) return []
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var g = raw[i]
    if (!g || typeof g !== "object") continue
    var died = Number(g.diedAt)
    if (!isFinite(died) || died <= 0) continue
    var born = Number(g.bornAt)
    var cause = g.cause === "lonely" || g.cause === "farm" ? g.cause : "starved"
    var genome = hasGenome(g.genome) ? normalizeGenome(g.genome, parts) : genomeFromAppearance(g.appearance)
    out.push({
      name: hatchName(g.name),
      genome: genome,
      bornAt: isFinite(born) && born > 0 ? born : died,
      diedAt: died,
      cause: cause,
      output: g.output ? String(g.output) : ""
    })
    if (out.length >= MAX_GRAVES) break
  }
  return out
}

function makeGrave(state, now, cause, parts, output) {
  return {
    name: state.name || "Mochi",
    genome: normalizeGenome(state.genome, parts),
    bornAt: state.bornAt,
    diedAt: now,
    cause: cause,
    output: output ? String(output) : ""
  }
}

function normalizeIds(raw) {
  if (!Array.isArray(raw)) return []
  var out = []
  var seen = {}
  for (var i = 0; i < raw.length; i++) {
    var id = Md.cleanId(raw[i])
    if (!id || seen[id]) continue
    seen[id] = true
    out.push(id)
  }
  return out
}

function normalizeDifficulty(raw) {
  var s = String(raw || "").toLowerCase()
  if (s === "easy" || s === "hard") return s
  return "medium"
}

function difficultyLabel(raw) {
  var s = normalizeDifficulty(raw)
  if (s === "easy") return "Easy"
  if (s === "hard") return "Hard"
  return "Medium"
}

function decayRate(raw) {
  return DECAY_RATE[normalizeDifficulty(raw)] || 1
}

function cycleDifficulty(current, dir) {
  var idx = 1
  var cur = normalizeDifficulty(current)
  for (var i = 0; i < DIFFICULTIES.length; i++) {
    if (DIFFICULTIES[i] === cur) idx = i
  }
  var step = dir < 0 ? -1 : 1
  return DIFFICULTIES[(idx + step + DIFFICULTIES.length) % DIFFICULTIES.length]
}

function deathCause(state, now) {
  if (!state || !state.hatched) return ""
  var t = Number(now) || Date.now()
  if (state.hungerEmptySince > 0 && t - state.hungerEmptySince >= STARVE_MS) return "starved"
  if (state.happyEmptySince > 0 && t - state.happyEmptySince >= LONELY_MS) return "lonely"
  return ""
}

function inCrisisSleep(state, now) {
  return !!(state && state.noDeath && deathCause(state, now))
}

function applyCrisisSleep(next, now) {
  if (inCrisisSleep(next, now)) next.sleeping = true
  return next
}

function copyPrefs(from, to) {
  to.maintenance = from && from.maintenance !== false
  to.difficulty = normalizeDifficulty(from && from.difficulty)
  to.noDeath = !!(from && from.noDeath)
  return to
}

function copyShop(from, to) {
  to.score = Math.max(0, Math.floor(Number(from && from.score) || 0))
  to.scoreAccruedMs = Math.max(0, Number(from && from.scoreAccruedMs) || 0)
  to.ownedHats = normalizeIds(from && from.ownedHats)
  to.ownedToys = normalizeIds(from && from.ownedToys)
  to.ownedGear = normalizeIds(from && from.ownedGear)
  to.equippedHat = Md.cleanId(from && from.equippedHat)
  to.equippedToy = Md.cleanId(from && from.equippedToy)
  if (to.ownedHats.indexOf(to.equippedHat) < 0) to.equippedHat = ""
  if (to.ownedToys.indexOf(to.equippedToy) < 0) to.equippedToy = ""
  return to
}

function eggState(prev, now, graves) {
  var next = defaultState(now)
  next.shown = prev.shown
  next.pen = prev.pen
  next.confineOutput = prev.confineOutput || ""
  next.graves = graves
  next.hatched = false
  next.genome = null
  next.name = ""
  next.hunger = STAT_MAX
  next.happiness = STAT_MAX
  next.energy = STAT_MAX
  next.dirty = 0
  next.gravesShown = prev.gravesShown !== false
  copyPrefs(prev, next)
  copyShop(prev, next)
  return next
}

function emptySince(current, isEmpty, now) {
  if (!isEmpty) return 0
  var prev = Number(current)
  if (isFinite(prev) && prev > 0) return prev
  return now
}

function hatchName(name) {
  var s = String(name || "").replace(/^\s+|\s+$/g, "")
  if (!s) s = "Mochi"
  if (s.length > NAME_MAX) s = s.substring(0, NAME_MAX)
  return s
}

function hasGenome(raw) {
  return raw && typeof raw === "object" && (raw.body || raw.head)
}

function genomesEqual(a, b) {
  if (!a && !b) return true
  if (!a || !b) return false
  for (var i = 0; i < GENOME_SLOTS.length; i++) {
    var key = GENOME_SLOTS[i][0]
    if (a[key] !== b[key]) return false
  }
  return true
}

function pickId(ids, value, fallback) {
  if (value && (!ids || !ids.length)) return String(value)
  if (value && ids) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] === value) return value
    }
  }
  return fallback
}

function pickRandom(ids) {
  if (!ids || !ids.length) return ""
  return ids[Math.floor(Math.random() * ids.length)]
}

function genomeFromAppearance(appearance) {
  if (appearance === "kitty")
    return { body: "bean", head: "cat", hat: "none", arms: "paws", legs: "paws", tail: "cat" }
  if (appearance === "beholder")
    return { body: "squat", head: "cyclops", hat: "none", arms: "stubs", legs: "stubs", tail: "none" }
  return { body: "round", head: "round", hat: "none", arms: "stubs", legs: "stubs", tail: "none" }
}

function normalizeGenome(raw, parts) {
  var src = raw && typeof raw === "object" ? raw : {}
  var g = {}
  for (var i = 0; i < GENOME_SLOTS.length; i++) {
    var spec = GENOME_SLOTS[i]
    g[spec[0]] = pickId(Parts.slotIds(parts, spec[1]), src[spec[0]], spec[2])
  }
  return g
}

function randomGenome(parts) {
  var g = {}
  for (var i = 0; i < GENOME_SLOTS.length; i++) {
    var spec = GENOME_SLOTS[i]
    g[spec[0]] = pickRandom(Parts.slotIds(parts, spec[1])) || spec[2]
  }
  return g
}

function normalizePen(raw) {
  if (!raw || typeof raw !== "object") return null
  var x = Number(raw.x)
  var y = Number(raw.y)
  var w = Number(raw.w)
  var h = Number(raw.h)
  if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h)) return null
  if (w < 80 || h < 80) return null
  return { x: x, y: y, w: w, h: h, output: raw.output ? String(raw.output) : "" }
}

function defaultState(now) {
  var t = Number(now) || Date.now()
  return {
    name: "",
    hatched: false,
    genome: null,
    hunger: STAT_MAX,
    happiness: STAT_MAX,
    energy: STAT_MAX,
    dirty: 0,
    sleeping: false,
    shown: true,
    pen: null,
    confineOutput: "",
    mess: [],
    graves: [],
    gravesShown: true,
    maintenance: true,
    difficulty: "medium",
    noDeath: false,
    hungerEmptySince: 0,
    happyEmptySince: 0,
    bornAt: t,
    lastTick: t,
    score: 0,
    scoreAccruedMs: 0,
    ownedHats: [],
    ownedToys: [],
    ownedGear: [],
    equippedHat: "",
    equippedToy: ""
  }
}

function normalizeState(raw, now, parts) {
  var base = defaultState(now)
  if (!raw || typeof raw !== "object") return base
  base.hunger = clamp(raw.hunger, 0, STAT_MAX)
  base.happiness = clamp(raw.happiness, 0, STAT_MAX)
  base.energy = clamp(raw.energy, 0, STAT_MAX)
  base.dirty = clamp(raw.dirty, 0, STAT_MAX)
  base.sleeping = raw.sleeping === true
  base.shown = raw.shown !== false
  base.pen = normalizePen(raw.pen)
  base.confineOutput = raw.confineOutput ? String(raw.confineOutput) : ""
  base.mess = normalizeMess(raw.mess)
  base.graves = normalizeGraves(raw.graves, parts)
  base.gravesShown = raw.gravesShown !== false
  copyPrefs(raw, base)
  copyShop(raw, base)
  base.hungerEmptySince = Number(raw.hungerEmptySince) > 0 ? Number(raw.hungerEmptySince) : 0
  base.happyEmptySince = Number(raw.happyEmptySince) > 0 ? Number(raw.happyEmptySince) : 0
  var born = Number(raw.bornAt)
  base.bornAt = isFinite(born) && born > 0 ? born : base.bornAt
  var last = Number(raw.lastTick)
  base.lastTick = isFinite(last) && last > 0 ? last : base.lastTick

  var living = raw.hatched === true || hasGenome(raw.genome)
    || (raw.hatched !== false && raw.name && String(raw.name).length > 0)
  if (living) {
    base.hatched = true
    base.name = hatchName(raw.name)
    base.genome = hasGenome(raw.genome) ? normalizeGenome(raw.genome, parts) : genomeFromAppearance(raw.appearance)
  } else {
    base.hatched = false
    base.name = ""
    base.genome = null
  }
  return base
}

function hatchPet(state, name, now, parts) {
  var t = Number(now) || Date.now()
  var next = normalizeState(state, t, parts)
  next.hatched = true
  next.name = hatchName(name)
  next.genome = randomGenome(parts)
  next.hunger = 82
  next.happiness = 78
  next.energy = 88
  next.dirty = 0
  next.sleeping = false
  next.hungerEmptySince = 0
  next.happyEmptySince = 0
  next.bornAt = t
  next.lastTick = t
  next.mess = []
  copyPrefs(state, next)
  copyShop(state, next)
  return next
}

function mood(state) {
  if (!state) return "idle"
  if (state.hatched === false) return "egg"
  if (state.sleeping) return "sleeping"
  if (state.hunger < 22) return "hungry"
  if (state.happiness < 22) return "sad"
  if (state.energy < 16) return "tired"
  if (state.happiness >= 72 && state.hunger >= 50) return "happy"
  return "idle"
}

function moodLabel(value) {
  if (value === "egg") return "An egg"
  if (value === "sleeping") return "Sleeping"
  if (value === "hungry") return "Hungry"
  if (value === "sad") return "Lonely"
  if (value === "tired") return "Sleepy"
  if (value === "happy") return "Happy"
  return "Content"
}

function speech(state) {
  if (state && state.hatched === false) return "tap to hatch"
  var m = mood(state)
  if (m === "hungry") return "feed me!"
  if (state && state.mess && state.mess.length >= STINKY_MESS_MIN && m !== "sleeping") return "stinky!"
  if (state && state.dirty >= 60 && m !== "sleeping") return "bath?"
  if (m === "sad") return "play?"
  if (m === "tired") return "zzz"
  if (m === "sleeping") return "zzz"
  return ""
}

function poseFor(state, moving, scene) {
  if (!state || state.hatched === false) return "walk"
  var m = mood(state)
  if (m === "sleeping") return "sleep"
  if (scene === "tv") return "watch"
  if (scene === "music") return "dance"
  if (m === "tired" && !moving) return "sit"
  if (m === "sad" && !moving) return "sad"
  if (moving) return "walk"
  return "idle"
}

function isPaint(ch) {
  return !!(ch && ch !== "." && ch !== " ")
}

function blankRow() {
  var row = ""
  for (var x = 0; x < SPRITE_COLS; x++) row += "."
  return row
}

function padTop(frame, n) {
  if (n <= 0) return frame
  var out = []
  for (var i = 0; i < n; i++) out.push(blankRow())
  for (var y = 0; y < frame.length; y++) out.push(frame[y])
  return out
}

function paintedMaxY(frame) {
  var maxY = -1
  if (!frame) return maxY
  for (var y = 0; y < frame.length; y++) {
    var row = String(frame[y] || "")
    for (var x = 0; x < row.length; x++) {
      if (isPaint(row.charAt(x))) {
        maxY = y
        break
      }
    }
  }
  return maxY
}

function firstPaintedRow(frame) {
  if (!frame) return -1
  for (var y = 0; y < frame.length; y++) {
    var row = String(frame[y] || "")
    for (var x = 0; x < row.length; x++) {
      if (isPaint(row.charAt(x))) return y
    }
  }
  return -1
}

function stampAt(base, overlay, dx, dy) {
  if (!overlay || !base) return base
  var out = []
  var h = base.length
  var ox = Number(dx) || 0
  var oy = Number(dy) || 0
  for (var y = 0; y < h; y++) out.push(String(base[y] || ""))
  for (var iy = 0; iy < overlay.length; iy++) {
    var ty = iy + oy
    if (ty < 0 || ty >= h) continue
    var a = String(out[ty] || "")
    var b = String(overlay[iy] || "")
    var row = ""
    for (var x = 0; x < SPRITE_COLS; x++) {
      var sx = x - ox
      var ch = sx >= 0 && sx < b.length ? b.charAt(sx) : ""
      row += isPaint(ch) ? ch : (a.charAt(x) || ".")
    }
    out[ty] = row
  }
  return out
}

function stamp(base, overlay) {
  return stampAt(base, overlay, 0, 0)
}

function seatShopHat(canvas, hat, parts, genome, pose, frame) {
  if (!hat || !canvas) return canvas
  var hatBottom = paintedMaxY(hat)
  if (hatBottom < 0) return canvas
  var g = normalizeGenome(genome, parts)
  var head = pieceFrame(parts, "heads", g.head, pose, frame)
  var seat = firstPaintedRow(head)
  if (seat < 0) seat = 1
  var dy = seat - hatBottom
  var pad = dy < 0 ? -dy : 0
  return stampAt(padTop(canvas, pad), hat, 0, dy + pad)
}

function pieceFrame(parts, slot, id, pose, frame) {
  var piece = Parts.pieceOf(parts, slot, id)
  if (!piece) return null
  if (pose === "walk")
    return ((frame % 2 === 0) ? piece.walkA : piece.walkB) || piece.idle
  if (pose === "dance")
    return ((frame % 2 === 0) ? piece.danceA : piece.danceB) || piece.idle
  return piece[pose] || piece.idle
}

function compositePixels(genome, pose, frame, parts) {
  var g = normalizeGenome(genome, parts)
  var canvas = Md.blankFrame()
  canvas = stamp(canvas, pieceFrame(parts, "tails", g.tail, pose, frame))
  canvas = stamp(canvas, pieceFrame(parts, "bodies", g.body, pose, frame))
  canvas = stamp(canvas, pieceFrame(parts, "legs", g.legs, pose, frame))
  canvas = stamp(canvas, pieceFrame(parts, "arms", g.arms, pose, frame))
  canvas = stamp(canvas, pieceFrame(parts, "heads", g.head, pose, frame))
  canvas = stamp(canvas, pieceFrame(parts, "horns", g.hat, pose, frame))
  return canvas
}

function hasGear(state, id) {
  var list = state && state.ownedGear
  if (!list || !id) return false
  for (var i = 0; i < list.length; i++) {
    if (list[i] === id) return true
  }
  return false
}

function gearAutoLabel(auto) {
  return Shop.autoLabel(auto)
}

function framePixels(pose, frame, genome, hatched, shopHat, shopToy, shopFrame, parts, itemOnly, shopGear) {
  var tick = shopFrame === undefined || shopFrame === null ? frame : shopFrame
  if (itemOnly) {
    var item = Md.blankFrame()
    item = stamp(item, Shop.shopFrame(shopHat, tick))
    item = stamp(item, Shop.shopFrame(shopToy, tick))
    item = stamp(item, Shop.shopFrame(shopGear, tick))
    return item
  }
  if (hatched === false) {
    if (pose === "walk") return (frame % 2 === 0) ? Egg.walkA : Egg.walkB
    return Egg.idle
  }
  var canvas = compositePixels(genome, pose, frame, parts)
  if (shopHat)
    canvas = seatShopHat(canvas, Shop.shopFrame(shopHat, tick), parts, genome, pose, frame)
  var bodyOrigin = Math.max(0, canvas.length - SPRITE_ROWS)
  canvas = stampAt(canvas, Shop.shopFrame(shopToy, tick), 0, bodyOrigin)
  return canvas
}

function messPixels(kind, frame) {
  return Mess.pixels(kind, frame)
}

function pottyFromMess(mess) {
  var n = mess && mess.length ? mess.length : 0
  return clamp(n * POTTY_PER_MESS, 0, STAT_MAX)
}

function dirtShade(i) {
  if (i === 1) return "#6b3a18"
  if (i === 2) return "#3d220e"
  return "#5a3014"
}

var GRAVE_SLOT = 34

function graveKind(index, diedAt) {
  var kinds = Grave.ids
  var n = (Math.floor(Number(index) || 0) + Math.floor((Number(diedAt) || 0) / 1000)) % kinds.length
  if (n < 0) n += kinds.length
  return kinds[n]
}

function graveTilt(index, diedAt) {
  var i = Math.floor(Number(index) || 0)
  var s = (i * 7 + Math.floor((Number(diedAt) || 0) % 17)) % 11
  var t = s - 5
  if (t === 0) t = (i % 2 === 0) ? 4 : -4
  return t * 1.6
}

function graveLean(index) {
  return ((Math.floor(Number(index) || 0) % 3) - 1)
}

function graveLift(index) {
  var row = [6, 0, 12, 3, 9]
  return row[Math.floor(Number(index) || 0) % row.length]
}

function graveNudge(index) {
  return ((Math.floor(Number(index) || 0) * 5) % 9) - 4
}

function graveCols(width) {
  var w = Number(width) || 0
  return Math.max(1, Math.floor((w - 24) / GRAVE_SLOT))
}

function graveX(index, width) {
  var i = Math.floor(Number(index) || 0)
  var cols = graveCols(width)
  return 12 + (i % cols) * GRAVE_SLOT + graveNudge(i)
}

function graveRow(index, width) {
  var i = Math.floor(Number(index) || 0)
  return Math.floor(i / graveCols(width))
}

function gravePixels(kind) {
  if (kind === "flower") return Grave.flower
  if (kind === "sprout") return Grave.sprout
  if (kind === "mound") return Grave.mound
  return Grave.cross
}

function applyCare(state, now, parts, fn) {
  if (state && state.hatched === false) return normalizeState(state, now, parts)
  return applyCrisisSleep(fn(tickState(state, now, false, parts)), now)
}

function nibble(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.hunger = clamp(next.hunger + NIBBLE_HUNGER, 0, STAT_MAX)
    next.happiness = clamp(next.happiness + 3, 0, STAT_MAX)
    next.sleeping = false
    return recoverEmptyFlags(next)
  })
}

function lullabyNote(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.energy = clamp(next.energy + LULLABY_ENERGY, 0, STAT_MAX)
    return next
  })
}

function lullaby(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.energy = STAT_MAX
    next.happiness = clamp(next.happiness + LULLABY_HAPPY, 0, STAT_MAX)
    next.sleeping = true
    return recoverEmptyFlags(next)
  })
}

function wash(state, now, parts, amount) {
  return applyCare(state, now, parts, function(next) {
    next.dirty = clamp(next.dirty - (Number(amount) || 0), 0, STAT_MAX)
    return next
  })
}

function bath(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.dirty = 0
    next.happiness = clamp(next.happiness + BATH_HAPPY, 0, STAT_MAX)
    next.sleeping = false
    return recoverEmptyFlags(next)
  })
}

function scoopCheer(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.happiness = clamp(next.happiness + SCOOP_HAPPY, 0, STAT_MAX)
    return recoverEmptyFlags(next)
  })
}

function graveOutputOf(state, output) {
  if (output) return String(output)
  if (state && state.dropOutput) return String(state.dropOutput)
  return ""
}

function killPet(state, now, cause, parts, output) {
  var t = Number(now) || Date.now()
  var next = normalizeState(state, t, parts)
  if (!next.hatched) return next
  var graves = next.graves.concat([makeGrave(next, t, cause, parts, graveOutputOf(state, output))])
  if (graves.length > MAX_GRAVES) graves = graves.slice(graves.length - MAX_GRAVES)
  return eggState(next, t, graves)
}

function farmKill(state, now, parts) {
  return killPet(state, now, "farm", parts)
}

function tickState(state, now, walking, parts) {
  var next = normalizeState(state, now, parts)
  var t = Number(now) || Date.now()
  var dt = Math.max(0, Math.min(t - next.lastTick, 6 * 60 * 60 * 1000))
  next.lastTick = t
  if (!next.hatched) return next
  if (dt <= 0) return applyCrisisSleep(next, t)

  if (next.maintenance === false)
    return applyCrisisSleep(next, t)

  var rate = decayRate(next.difficulty)
  next.hunger = clamp(next.hunger - HUNGER_DECAY_PER_MS * rate * dt, 0, STAT_MAX)
  next.happiness = clamp(next.happiness - HAPPY_DECAY_PER_MS * rate * dt, 0, STAT_MAX)

  var stale = 0
  for (var i = 0; i < next.mess.length; i++) {
    if (t - next.mess[i].bornAt >= MESS_STALE_MS) stale++
  }
  if (stale > 0)
    next.happiness = clamp(next.happiness - HAPPY_STALE_MESS_PER_MS * rate * stale * dt, 0, STAT_MAX)

  if (next.sleeping)
    next.energy = clamp(next.energy + ENERGY_SLEEP_PER_MS * dt, 0, STAT_MAX)
  else if (walking)
    next.energy = clamp(next.energy - ENERGY_WALK_PER_MS * rate * dt, 0, STAT_MAX)

  if (!next.sleeping)
    next.dirty = clamp(next.dirty + (walking ? DIRTY_WALK_PER_MS : DIRTY_IDLE_PER_MS) * rate * dt, 0, STAT_MAX)

  if (hasGear(next, "microwave"))
    next.hunger = clamp(next.hunger + HUNGER_DECAY_PER_MS * 2 * rate * dt, 0, STAT_MAX)
  if (hasGear(next, "pc") && !next.sleeping)
    next.happiness = clamp(next.happiness + HAPPY_DECAY_PER_MS * 2 * rate * dt, 0, STAT_MAX)
  if (hasGear(next, "shower") && !next.sleeping)
    next.dirty = clamp(next.dirty - DIRTY_WALK_PER_MS * 2 * rate * dt, 0, STAT_MAX)

  var sleepAt = hasGear(next, "bed") ? 28 : 4
  if (!next.sleeping && next.energy <= sleepAt) next.sleeping = true
  if (next.sleeping && next.energy >= STAT_MAX - 0.5) next.sleeping = false

  next.hungerEmptySince = emptySince(next.hungerEmptySince, next.hunger <= 0.5, t)
  next.happyEmptySince = emptySince(next.happyEmptySince, next.happiness <= 0.5, t)

  var cause = deathCause(next, t)
  if (cause && !next.noDeath)
    return killPet(next, t, cause, parts, state && state.dropOutput)
  return applyCrisisSleep(next, t)
}

function recoverEmptyFlags(next) {
  if (next.hunger > 0.5) next.hungerEmptySince = 0
  if (next.happiness > 0.5) next.happyEmptySince = 0
  return next
}

function feed(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.hunger = clamp(next.hunger + FEED_HUNGER, 0, STAT_MAX)
    next.happiness = clamp(next.happiness + FEED_HAPPY, 0, STAT_MAX)
    next.sleeping = false
    return recoverEmptyFlags(next)
  })
}

function play(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.happiness = clamp(next.happiness + PLAY_HAPPY, 0, STAT_MAX)
    next.energy = clamp(next.energy - PLAY_ENERGY, 0, STAT_MAX)
    next.hunger = clamp(next.hunger - PLAY_HUNGER, 0, STAT_MAX)
    next.sleeping = next.energy <= 4
    return recoverEmptyFlags(next)
  })
}

function pet(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    next.happiness = clamp(next.happiness + PET_HAPPY, 0, STAT_MAX)
    if (next.sleeping && next.happiness > 40) next.sleeping = false
    return recoverEmptyFlags(next)
  })
}

function toggleSleep(state, now, parts) {
  return applyCare(state, now, parts, function(next) {
    if (inCrisisSleep(next, now)) {
      next.sleeping = true
      return next
    }
    next.sleeping = !(state && state.sleeping === true)
    return next
  })
}

function ageLabel(bornAt, now, hatched) {
  if (hatched === false) return "waiting to hatch"
  var born = Number(bornAt)
  var t = Number(now) || Date.now()
  if (!isFinite(born) || born <= 0) return "new"
  var hours = Math.max(0, Math.floor((t - born) / (60 * 60 * 1000)))
  if (hours < 1) return "just hatched"
  if (hours < 48) return hours + (hours === 1 ? " hour old" : " hours old")
  var days = Math.floor(hours / 24)
  return days + (days === 1 ? " day old" : " days old")
}
