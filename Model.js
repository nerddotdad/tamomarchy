.import "Looks/parts/Bodies.js" as Bodies
.import "Looks/parts/Heads.js" as Heads
.import "Looks/parts/Hats.js" as Hats
.import "Looks/parts/Arms.js" as Arms
.import "Looks/parts/Legs.js" as Legs
.import "Looks/parts/Tails.js" as Tails
.import "Looks/Egg.js" as Egg
.import "Looks/Mess.js" as Mess
.import "Looks/Grave.js" as Grave

// Tamagotchi stats, mood, and stitched part sprites (Looks/parts/*.js).

var STAT_MAX = 100

// Real-time decay: a full belly lasts ~40 minutes, mood ~70 minutes,
// and walking energy ~2 hours. Sleep refills energy in about 6 minutes.
var HUNGER_DECAY_PER_MS = STAT_MAX / (40 * 60 * 1000)
var HAPPY_DECAY_PER_MS = STAT_MAX / (70 * 60 * 1000)
var ENERGY_WALK_PER_MS = STAT_MAX / (120 * 60 * 1000)
var ENERGY_SLEEP_PER_MS = STAT_MAX / (6 * 60 * 1000)

var FEED_HUNGER = 38
var FEED_HAPPY = 6
var PLAY_HAPPY = 32
var PLAY_ENERGY = 18
var PLAY_HUNGER = 10
var PET_HAPPY = 12

var SPRITE_COLS = 12
var SPRITE_ROWS = 11

var MESS_STALE_MS = 4 * 60 * 1000
var HAPPY_STALE_MESS_PER_MS = STAT_MAX / (18 * 60 * 1000)
var MAX_MESS_EACH = 10
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

function normalizeGraves(raw) {
  if (!Array.isArray(raw)) return []
  var out = []
  for (var i = 0; i < raw.length; i++) {
    var g = raw[i]
    if (!g || typeof g !== "object") continue
    var died = Number(g.diedAt)
    if (!isFinite(died) || died <= 0) continue
    var born = Number(g.bornAt)
    var cause = g.cause === "lonely" ? "lonely" : "starved"
    var genome = hasGenome(g.genome) ? normalizeGenome(g.genome) : genomeFromAppearance(g.appearance)
    out.push({
      name: String(g.name || "Mochi"),
      genome: genome,
      bornAt: isFinite(born) && born > 0 ? born : died,
      diedAt: died,
      cause: cause
    })
    if (out.length >= MAX_GRAVES) break
  }
  return out
}

function causeLabel(cause) {
  if (cause === "farm") return "the farm"
  if (cause === "lonely") return "lonely"
  return "starved"
}

function roman(n) {
  var v = Math.max(1, Math.floor(Number(n) || 1))
  var map = [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
  var s = ""
  for (var i = 0; i < map.length; i++) {
    while (v >= map[i][0]) {
      s += map[i][1]
      v -= map[i][0]
    }
  }
  return s
}

function makeGrave(state, now, cause) {
  return {
    name: state.name || "Mochi",
    genome: normalizeGenome(state.genome),
    bornAt: state.bornAt,
    diedAt: now,
    cause: cause
  }
}

function eggState(prev, now, graves) {
  var next = defaultState(now)
  next.shown = prev.shown
  next.pen = prev.pen
  next.graves = graves
  next.hatched = false
  next.genome = null
  next.name = ""
  next.hunger = STAT_MAX
  next.happiness = STAT_MAX
  next.energy = STAT_MAX
  next.gravesShown = prev.gravesShown !== false
  next.maintenance = prev.maintenance !== false
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
  if (s.length > 18) s = s.substring(0, 18)
  return s
}

function hasGenome(raw) {
  return raw && typeof raw === "object" && (raw.body || raw.head)
}

function genomesEqual(a, b) {
  if (!a && !b) return true
  if (!a || !b) return false
  return a.body === b.body && a.head === b.head && a.hat === b.hat
    && a.arms === b.arms && a.legs === b.legs && a.tail === b.tail
}

function pickId(ids, value, fallback) {
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

function normalizeGenome(raw) {
  var src = raw && typeof raw === "object" ? raw : {}
  return {
    body: pickId(Bodies.ids, src.body, "round"),
    head: pickId(Heads.ids, src.head, "round"),
    hat: pickId(Hats.ids, src.hat, "none"),
    arms: pickId(Arms.ids, src.arms, "stubs"),
    legs: pickId(Legs.ids, src.legs, "stubs"),
    tail: pickId(Tails.ids, src.tail, "none")
  }
}

function randomGenome() {
  return {
    body: pickRandom(Bodies.ids),
    head: pickRandom(Heads.ids),
    hat: pickRandom(Hats.ids),
    arms: pickRandom(Arms.ids),
    legs: pickRandom(Legs.ids),
    tail: pickRandom(Tails.ids)
  }
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
    sleeping: false,
    shown: true,
    pen: null,
    mess: [],
    graves: [],
    gravesShown: true,
    maintenance: true,
    hungerEmptySince: 0,
    happyEmptySince: 0,
    bornAt: t,
    lastTick: t
  }
}

function normalizeState(raw, now) {
  var base = defaultState(now)
  if (!raw || typeof raw !== "object") return base
  base.hunger = clamp(raw.hunger, 0, STAT_MAX)
  base.happiness = clamp(raw.happiness, 0, STAT_MAX)
  base.energy = clamp(raw.energy, 0, STAT_MAX)
  base.sleeping = raw.sleeping === true
  base.shown = raw.shown !== false
  base.pen = normalizePen(raw.pen)
  base.mess = normalizeMess(raw.mess)
  base.graves = normalizeGraves(raw.graves)
  base.gravesShown = raw.gravesShown !== false
  base.maintenance = raw.maintenance !== false
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
    base.name = String(raw.name || "Mochi")
    base.genome = hasGenome(raw.genome) ? normalizeGenome(raw.genome) : genomeFromAppearance(raw.appearance)
  } else {
    base.hatched = false
    base.name = ""
    base.genome = null
  }
  return base
}

function hatchPet(state, name, now) {
  var t = Number(now) || Date.now()
  var next = normalizeState(state, t)
  next.hatched = true
  next.name = hatchName(name)
  next.genome = randomGenome()
  next.hunger = 82
  next.happiness = 78
  next.energy = 88
  next.sleeping = false
  next.hungerEmptySince = 0
  next.happyEmptySince = 0
  next.bornAt = t
  next.lastTick = t
  next.mess = []
  next.maintenance = state && state.maintenance !== false
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
  if (state && state.mess && state.mess.length > 0 && m !== "sleeping") return "stinky!"
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

function blankFrame() {
  var rows = []
  for (var y = 0; y < SPRITE_ROWS; y++) rows.push("............")
  return rows
}

function stamp(base, overlay) {
  if (!overlay) return base
  var out = []
  for (var y = 0; y < SPRITE_ROWS; y++) {
    var a = String(base[y] || "")
    var b = String(overlay[y] || "")
    var row = ""
    for (var x = 0; x < SPRITE_COLS; x++) {
      var ch = b.charAt(x)
      row += (ch && ch !== "." && ch !== " ") ? ch : (a.charAt(x) || ".")
    }
    out.push(row)
  }
  return out
}

function pieceOf(lib, id) {
  if (!lib) return null
  var piece = null
  if (id === "round") piece = lib.round
  else if (id === "bean") piece = lib.bean
  else if (id === "squat") piece = lib.squat
  else if (id === "cat") piece = lib.cat
  else if (id === "cyclops") piece = lib.cyclops
  else if (id === "bird") piece = lib.bird
  else if (id === "none") piece = lib.none
  else if (id === "sprout") piece = lib.sprout
  else if (id === "horns") piece = lib.horns
  else if (id === "bow") piece = lib.bow
  else if (id === "stubs") piece = lib.stubs
  else if (id === "paws") piece = lib.paws
  else if (id === "wings") piece = lib.wings
  else if (id === "hooves") piece = lib.hooves
  else if (id === "stub") piece = lib.stub
  else if (id === "tuft") piece = lib.tuft
  if (piece && piece.idle) return piece
  return null
}

function pieceFrame(lib, id, pose, frame) {
  var piece = pieceOf(lib, id)
  if (!piece) return null
  if (pose === "walk") {
    var w = (frame % 2 === 0) ? piece.walkA : piece.walkB
    return w || piece.idle
  }
  if (pose === "dance") {
    var d = (frame % 2 === 0) ? piece.danceA : piece.danceB
    return d || piece.idle
  }
  if (pose === "watch") return piece.watch || piece.idle
  if (pose === "eat") return piece.eat || piece.idle
  if (pose === "sit") return piece.sit || piece.idle
  if (pose === "sleep") return piece.sleep || piece.idle
  if (pose === "sad") return piece.sad || piece.idle
  return piece.idle
}

function compositePixels(genome, pose, frame) {
  var g = normalizeGenome(genome)
  var canvas = blankFrame()
  canvas = stamp(canvas, pieceFrame(Tails, g.tail, pose, frame))
  canvas = stamp(canvas, pieceFrame(Bodies, g.body, pose, frame))
  canvas = stamp(canvas, pieceFrame(Legs, g.legs, pose, frame))
  canvas = stamp(canvas, pieceFrame(Arms, g.arms, pose, frame))
  canvas = stamp(canvas, pieceFrame(Heads, g.head, pose, frame))
  canvas = stamp(canvas, pieceFrame(Hats, g.hat, pose, frame))
  return canvas
}

function framePixels(pose, frame, genome, hatched) {
  if (hatched === false) {
    if (pose === "walk") return (frame % 2 === 0) ? Egg.walkA : Egg.walkB
    return Egg.idle
  }
  return compositePixels(genome, pose, frame)
}

function messPixels(kind) {
  return kind === "pee" ? Mess.pee : Mess.poop
}

var GRAVE_KINDS = ["cross", "flower", "sprout", "mound"]
var GRAVE_SLOT = 34

function graveKind(index, diedAt) {
  var n = (Math.floor(Number(index) || 0) + Math.floor((Number(diedAt) || 0) / 1000)) % GRAVE_KINDS.length
  if (n < 0) n += GRAVE_KINDS.length
  return GRAVE_KINDS[n]
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

function nibble(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.hunger = clamp(next.hunger + 16, 0, STAT_MAX)
  next.happiness = clamp(next.happiness + 3, 0, STAT_MAX)
  next.sleeping = false
  return recoverEmptyFlags(next)
}

function lullaby(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.energy = STAT_MAX
  next.happiness = clamp(next.happiness + 10, 0, STAT_MAX)
  next.sleeping = true
  return recoverEmptyFlags(next)
}

function bath(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.happiness = clamp(next.happiness + 20, 0, STAT_MAX)
  next.sleeping = false
  return recoverEmptyFlags(next)
}

function farmKill(state, now) {
  var t = Number(now) || Date.now()
  var next = normalizeState(state, t)
  if (!next.hatched) return next
  var graves = next.graves.concat([makeGrave(next, t, "farm")])
  if (graves.length > MAX_GRAVES) graves = graves.slice(graves.length - MAX_GRAVES)
  return eggState(next, t, graves)
}

function tickState(state, now, walking) {
  var next = normalizeState(state, now)
  var t = Number(now) || Date.now()
  var dt = Math.max(0, Math.min(t - next.lastTick, 6 * 60 * 60 * 1000))
  next.lastTick = t
  if (!next.hatched) return next
  if (dt <= 0) return next

  if (next.maintenance === false) {
    next.hunger = STAT_MAX
    next.happiness = STAT_MAX
    next.energy = STAT_MAX
    next.hungerEmptySince = 0
    next.happyEmptySince = 0
    next.sleeping = false
    return next
  }

  next.hunger = clamp(next.hunger - HUNGER_DECAY_PER_MS * dt, 0, STAT_MAX)
  next.happiness = clamp(next.happiness - HAPPY_DECAY_PER_MS * dt, 0, STAT_MAX)

  var stale = 0
  for (var i = 0; i < next.mess.length; i++) {
    if (t - next.mess[i].bornAt >= MESS_STALE_MS) stale++
  }
  if (stale > 0)
    next.happiness = clamp(next.happiness - HAPPY_STALE_MESS_PER_MS * stale * dt, 0, STAT_MAX)

  if (next.sleeping)
    next.energy = clamp(next.energy + ENERGY_SLEEP_PER_MS * dt, 0, STAT_MAX)
  else if (walking)
    next.energy = clamp(next.energy - ENERGY_WALK_PER_MS * dt, 0, STAT_MAX)

  if (!next.sleeping && next.energy <= 4) next.sleeping = true
  if (next.sleeping && next.energy >= STAT_MAX - 0.5) next.sleeping = false

  next.hungerEmptySince = emptySince(next.hungerEmptySince, next.hunger <= 0.5, t)
  next.happyEmptySince = emptySince(next.happyEmptySince, next.happiness <= 0.5, t)

  var cause = ""
  if (next.hungerEmptySince > 0 && t - next.hungerEmptySince >= STARVE_MS) cause = "starved"
  else if (next.happyEmptySince > 0 && t - next.happyEmptySince >= LONELY_MS) cause = "lonely"

  if (cause) {
    var graves = next.graves.concat([makeGrave(next, t, cause)])
    if (graves.length > MAX_GRAVES) graves = graves.slice(graves.length - MAX_GRAVES)
    return eggState(next, t, graves)
  }
  return next
}

function recoverEmptyFlags(next) {
  if (next.hunger > 0.5) next.hungerEmptySince = 0
  if (next.happiness > 0.5) next.happyEmptySince = 0
  return next
}

function feed(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.hunger = clamp(next.hunger + FEED_HUNGER, 0, STAT_MAX)
  next.happiness = clamp(next.happiness + FEED_HAPPY, 0, STAT_MAX)
  next.sleeping = false
  return recoverEmptyFlags(next)
}

function play(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.happiness = clamp(next.happiness + PLAY_HAPPY, 0, STAT_MAX)
  next.energy = clamp(next.energy - PLAY_ENERGY, 0, STAT_MAX)
  next.hunger = clamp(next.hunger - PLAY_HUNGER, 0, STAT_MAX)
  next.sleeping = next.energy <= 4
  return recoverEmptyFlags(next)
}

function pet(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.happiness = clamp(next.happiness + PET_HAPPY, 0, STAT_MAX)
  if (next.sleeping && next.happiness > 40) next.sleeping = false
  return recoverEmptyFlags(next)
}

function toggleSleep(state, now) {
  if (state && state.hatched === false) return normalizeState(state, now)
  var next = tickState(state, now, false)
  next.sleeping = !(state && state.sleeping === true)
  return next
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
