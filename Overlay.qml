import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

// Fullscreen click-through overlay. The pet is the only input region, so
// the rest of the desktop stays usable while Mochi wanders on top of it.
Item {
  id: root

  property var shell: null
  property var manifest: null
  property var service: null

  readonly property var pet: service || (shell ? shell.serviceFor("io.github.nerddotdad.tamomarchy") : null)
  readonly property bool opened: pet ? pet.shown === true : false

  property real petX: 80
  property real petY: 120
  property real targetX: 80
  property real targetY: 120
  property int pauseMs: 800
  property bool placed: false
  property bool moving: false
  property bool facingLeft: false
  property int walkFrame: 0
  property int shopFrame: 0
  property double nowMs: 0

  readonly property int spriteScale: 6
  readonly property int spriteW: Model.SPRITE_COLS * spriteScale
  readonly property int spriteH: Model.SPRITE_ROWS * spriteScale
  property bool toyPlaying: false
  property string toyPlayKind: ""
  property real toyPlayT: 0
  property real toyPlayElapsed: 0
  property real toyPlayDur: 8000
  property int toyPlayDir: 1
  property int toyThrowPhase: -1
  property int toyCatchPhase: -1
  property real toyOffX: 0
  property real toyOffY: 0
  property real toyRot: 0
  property real toyScale: 1
  property real petRot: 0
  property bool toyFacingLeft: false
  property double toyPlayDueAt: 0
  readonly property real toyDrawX: root.toyOffX
  readonly property real toyDrawY: Math.round(spriteH * 0.32) + root.toyOffY
  readonly property bool toyVisible: root.toyPlaying && root.pet && root.pet.toyItem
  readonly property string pose: {
    if (!pet) return "idle"
    if (root.holding) return "walk"
    if (root.game === "sleep") return "sleep"
    if (root.game === "play" && root.moving) return "walk"
    if (!pet.hatched) return "walk"
    if (root.toyPlaying) {
      if (root.toyPlayKind === "jump" || root.toyPlayKind === "throw" || root.toyPlayKind === "glide") return "walk"
      if (root.toyPlayKind === "spin") return "dance"
      if (root.toyPlayKind === "think" || root.toyPlayKind === "roll") return "sit"
      return "idle"
    }
    return Model.poseFor(pet.snapshot(), root.moving, pet.scene)
  }
  readonly property real bounceY: {
    if (root.toyPlaying && root.toyPlayKind === "jump")
      return Math.round(Math.abs(Math.sin(root.toyPlayT * Math.PI * 6)) * 14)
    if (pose === "dance" && !root.toyPlaying) return Math.round(Math.sin(nowMs / 140) * 7)
    return 0
  }
  readonly property bool watching: pose === "watch" && root.game === ""
  readonly property bool dancing: pose === "dance" && root.game === "" && !root.toyPlaying
  readonly property bool drawing: pet ? pet.drawingPen === true : false
  readonly property bool hasPen: pet ? pet.hasPen === true : false
  readonly property int graveCount: pet ? pet.graveCount : 0
  readonly property int graveRev: pet ? pet.graveRev : 0
  readonly property bool gravesShown: pet ? pet.gravesShown !== false : true
  readonly property bool showGraves: gravesShown && graveCount > 0 && root.game === "" && !root.holding
  readonly property int graveyardSize: 56
  readonly property bool inGame: game !== ""
  readonly property bool gameSpansScreens: game === "scoop"
  readonly property bool naming: pet ? pet.naming === true : false
  readonly property bool captureInput: drawing || holding || inGame || naming
  readonly property real gameProgress: {
    if (game === "sleep") return lullabyHits / Math.max(1, gameNeed)
    if (game === "eat") return eatScore / Math.max(1, gameNeed)
    if (game === "play") return playScore / Math.max(1, gameNeed)
    if (game === "bath") return root.pet ? Math.max(0, 1 - root.pet.dirty / 100) : 1
    if (game === "scoop") return scoopStart > 0 ? Math.max(0, 1 - (root.pet ? root.pet.messCount : 0) / scoopStart) : 1
    if (game === "farm") return Math.min(1, grateTravel / grateNeed)
    return 0
  }

  property bool waitMouseUp: false
  property bool holding: false
  property real grabOffX: 0
  property real grabOffY: 0
  property real grabStartX: 0
  property real grabStartY: 0
  property real menuX: 0
  property real menuY: 0
  property string menuOutput: ""
  property string hoverAction: ""
  readonly property string hoverImpact: {
    if (hoverAction === "eat")
      return "Each food: +" + Model.NIBBLE_HUNGER + " hunger · +3 mood"
    if (hoverAction === "play")
      return "Each catch: +" + Model.PLAY_HAPPY + " mood · −" + Model.PLAY_ENERGY + " energy · −" + Model.PLAY_HUNGER + " hunger"
    if (hoverAction === "sleep")
      return "Each note: +" + Math.round(Model.LULLABY_ENERGY) + " energy · finish to sleep (+" + Model.LULLABY_HAPPY + " mood)"
    if (hoverAction === "bath")
      return "Scrub dirt off · +" + Model.BATH_HAPPY + " mood when clean"
    if (hoverAction === "scoop")
      return "Scoop poop and pee · +" + Model.SCOOP_HAPPY + " mood each pile"
    if (hoverAction === "farm")
      return "Ends their life"
    return ""
  }
  readonly property string hoverFocusStat: {
    if (hoverAction === "eat") return "hunger"
    if (hoverAction === "play") return "mood"
    if (hoverAction === "sleep") return "energy"
    if (hoverAction === "bath") return "dirty"
    if (hoverAction === "scoop") return "potty"
    return ""
  }
  property string game: ""
  property var lullabyKeys: []
  property int lullabyHits: 0
  property int eatScore: 0
  property int playScore: 0
  property int gameNeed: 1
  property real scrub: 0
  property real lastBrushX: -1
  property real lastBrushY: -1
  property bool brushHeld: false
  property bool scoopHeld: false
  property real lastScoopX: -1
  property real lastScoopY: -1
  property int scoopStart: 0
  property double lastScrubSfx: 0
  property double lastGrateSfx: 0
  property real ballX: 0
  property real ballY: 0
  property bool ballLive: false
  property int ballPhase: 0
  property real ballT: 0
  property real ballDur: 0.4
  property real bounceT: 0
  property real ballStartX: 0
  property real ballStartY: 0
  property real ballLandX: 0
  property real ballLandY: 0
  readonly property int ballSize: 28
  readonly property int foodSize: 36
  property real grateTravel: 0
  readonly property real grateNeed: 1800
  property real lastGrateX: -1
  property real lastGrateY: -1
  property bool dragging: false
  property string gameOutput: ""

  ListModel { id: hearts }
  ListModel { id: foods }
  ListModel { id: shreds }
  ListModel { id: notes }
  readonly property alias heartModel: hearts
  readonly property alias foodModel: foods
  readonly property alias shredModel: shreds
  readonly property alias noteModel: notes
  property real dragStartX: 0
  property real dragStartY: 0
  property real dragX: 0
  property real dragY: 0

  function open() {
    if (root.pet) root.pet.show()
  }

  function close() {
    // Plugin unload calls close() on this overlay. Do not persist hidden —
    // that made Mochi vanish after every hot reload.
  }

  function toggle() {
    if (root.pet) root.pet.toggleShown()
  }

  // A plugin reload calls hide() on the outgoing overlay. Bring the pet back
  // when this instance is handed the live service, unless the user hid it
  // after that injection.
  onPetChanged: {
    if (root.pet) root.pet.show()
  }

  function barClearance(side) {
    var position = shell && shell.barConfig ? String(shell.barConfig.position || "top") : "top"
    var bar = shell && shell.bar ? shell.bar : null
    var size = bar && !bar.barHidden ? bar.barSize : Style.bar.sizeHorizontal
    var pad = size + Style.gapsOut + 8
    if (side === "top") return position === "top" ? pad : 12
    if (side === "bottom") return position === "bottom" ? pad : 16
    if (side === "left") return position === "left" ? pad : 16
    return position === "right" ? pad : 16
  }

  function firstScreen() {
    var screens = Quickshell.screens
    return screens && screens.length ? screens[0] : null
  }

  function screenByName(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i] && screens[i].name === name) return screens[i]
    }
    return null
  }

  function screenAt(gx, gy) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s) continue
      if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
        return s
    }
    return null
  }

  function screenAtPet() {
    return root.screenAt(root.petX + spriteW / 2, root.petY + spriteH / 2) || root.nearestScreen(root.petX, root.petY)
  }

  function screenNameAtPet() {
    var s = root.screenAtPet()
    return s ? String(s.name) : ""
  }

  function nearestScreen(gx, gy) {
    var screens = Quickshell.screens
    var best = null
    var bestD = 1e15
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s) continue
      var cx = Math.min(Math.max(gx, s.x), s.x + s.width)
      var cy = Math.min(Math.max(gy, s.y), s.y + s.height)
      var d = (gx - cx) * (gx - cx) + (gy - cy) * (gy - cy)
      if (d < bestD) {
        bestD = d
        best = s
      }
    }
    return best
  }

  function messOnScreen(output, screenName) {
    if (output) return output === screenName
    var first = root.firstScreen()
    return first && first.name === screenName
  }

  function graveOnScreen(output, screenName) {
    var _ = root.graveRev
    if (output && root.screenByName(output)) return output === screenName
    if (!output) return root.screenNameAtPet() === screenName
    var first = root.firstScreen()
    return first && first.name === screenName
  }

  function gravesOnScreen(screenName) {
    if (!root.showGraves || !root.pet) return false
    var model = root.pet.graveModel
    if (!model) return false
    for (var i = 0; i < model.count; i++) {
      if (root.graveOnScreen(model.get(i).output, screenName)) return true
    }
    return false
  }

  function graveSlot(index, screenName) {
    var slot = 0
    if (!root.pet || !root.pet.graveModel) return 0
    var model = root.pet.graveModel
    var n = Math.max(0, Math.floor(Number(index) || 0))
    for (var i = 0; i < n && i < model.count; i++) {
      if (root.graveOnScreen(model.get(i).output, screenName)) slot++
    }
    return slot
  }

  function graveyardHFor(screenName) {
    if (!root.showGraves) return 0
    return root.gravesOnScreen(screenName) ? root.graveyardSize : 0
  }

  function walkBoundsForScreen(s) {
    if (!s) return { minX: 0, maxX: 0, minY: 0, maxY: 0 }
    var minX = s.x + root.barClearance("left")
    var minY = s.y + root.barClearance("top")
    var maxX = Math.max(minX, s.x + s.width - spriteW - root.barClearance("right"))
    var yard = root.graveyardHFor(s.name)
    var maxY = Math.max(minY, s.y + s.height - spriteH - root.barClearance("bottom") - 18 - yard)
    return { minX: minX, maxX: maxX, minY: minY, maxY: maxY, screen: s }
  }

  function confineScreen() {
    if (!root.pet || !root.pet.confineOutput) return null
    return root.screenByName(root.pet.confineOutput)
  }

  function screenAllowed(s) {
    if (!s) return false
    var lock = root.confineScreen()
    if (lock && s.name !== lock.name) return false
    return true
  }

  function penApplies() {
    if (!root.pet || !root.pet.hasPen || root.holding || root.inGame) return false
    if (root.pet.confineOutput && root.pet.penOutput && root.pet.confineOutput !== root.pet.penOutput)
      return false
    var s = root.screenAtPet()
    return s && s.name === root.pet.penOutput
  }

  function walkRects() {
    var rects = []
    var screens = Quickshell.screens
    var pen = root.penApplies()
    var lock = root.confineScreen()
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s) continue
      if (lock && s.name !== lock.name) continue
      if (pen && s.name !== root.pet.penOutput) continue
      var b = root.walkBoundsForScreen(s)
      if (pen) {
        b.minX = Math.max(b.minX, s.x + root.pet.penX)
        b.minY = Math.max(b.minY, s.y + root.pet.penY)
        b.maxX = Math.min(b.maxX, s.x + root.pet.penX + root.pet.penW - spriteW)
        b.maxY = Math.min(b.maxY, s.y + root.pet.penY + root.pet.penH - spriteH)
        if (b.maxX < b.minX) b.maxX = b.minX
        if (b.maxY < b.minY) b.maxY = b.minY
      }
      rects.push(b)
    }
    return rects
  }

  function clampPointToRects(x, y, rects) {
    for (var i = 0; i < rects.length; i++) {
      var r = rects[i]
      if (x >= r.minX && x <= r.maxX && y >= r.minY && y <= r.maxY)
        return { x: x, y: y }
    }
    var best = { x: x, y: y }
    var bestD = 1e15
    for (var j = 0; j < rects.length; j++) {
      var b = rects[j]
      var cx = Math.min(Math.max(x, b.minX), b.maxX)
      var cy = Math.min(Math.max(y, b.minY), b.maxY)
      var d = (x - cx) * (x - cx) + (y - cy) * (y - cy)
      if (d < bestD) {
        bestD = d
        best = { x: cx, y: cy }
      }
    }
    return best
  }

  function boundsFor(window) {
    var s = window && window.screen ? window.screen : root.screenAtPet() || root.firstScreen()
    return root.walkBoundsForScreen(s)
  }

  function pickTarget(window) {
    var rects = root.walkRects()
    if (!rects.length) {
      var b = root.boundsFor(window)
      rects = [b]
    }
    var r = rects[Math.floor(Math.random() * rects.length)]
    root.targetX = r.minX + Math.random() * Math.max(1, r.maxX - r.minX)
    root.targetY = r.minY + Math.random() * Math.max(1, r.maxY - r.minY)
  }

  function screenInDirection(here, dir) {
    if (!here) return null
    var screens = Quickshell.screens
    var best = null
    var bestGap = 1e15
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s || s.name === here.name) continue
      var overlap = 0
      var gap = 1e15
      if (dir === "right" || dir === "left") {
        overlap = Math.min(here.y + here.height, s.y + s.height) - Math.max(here.y, s.y)
        if (overlap < 8) continue
        if (dir === "right") {
          if (s.x + s.width / 2 <= here.x + here.width / 2) continue
          gap = s.x - (here.x + here.width)
        } else {
          if (s.x + s.width / 2 >= here.x + here.width / 2) continue
          gap = here.x - (s.x + s.width)
        }
      } else {
        overlap = Math.min(here.x + here.width, s.x + s.width) - Math.max(here.x, s.x)
        if (overlap < 8) continue
        if (dir === "down") {
          if (s.y + s.height / 2 <= here.y + here.height / 2) continue
          gap = s.y - (here.y + here.height)
        } else {
          if (s.y + s.height / 2 >= here.y + here.height / 2) continue
          gap = here.y - (s.y + s.height)
        }
      }
      if (gap < bestGap) {
        bestGap = gap
        best = s
      }
    }
    return best
  }

  function tryScreenHop() {
    if (root.holding || root.inGame || root.penApplies()) return false
    var here = root.screenAtPet() || root.nearestScreen(root.petX + spriteW / 2, root.petY + spriteH / 2)
    if (!here) return false
    var b = root.walkBoundsForScreen(here)
    var edge = 28
    var inward = 56
    var dir = ""
    if (root.petX >= b.maxX - edge && (root.targetX > root.petX + 4 || root.petX >= b.maxX - 2))
      dir = "right"
    else if (root.petX <= b.minX + edge && (root.targetX < root.petX - 4 || root.petX <= b.minX + 2))
      dir = "left"
    else if (root.petY >= b.maxY - edge && (root.targetY > root.petY + 4 || root.petY >= b.maxY - 2))
      dir = "down"
    else if (root.petY <= b.minY + edge && (root.targetY < root.petY - 4 || root.petY <= b.minY + 2))
      dir = "up"
    if (!dir) return false
    var dest = root.screenInDirection(here, dir)
    if (!dest || !root.screenAllowed(dest)) return false
    var tb = root.walkBoundsForScreen(dest)
    var p = root.clampPointToRects(root.petX, root.petY, [tb])
    if (dir === "right") p.x = Math.min(tb.maxX, tb.minX + inward)
    else if (dir === "left") p.x = Math.max(tb.minX, tb.maxX - inward)
    else if (dir === "down") p.y = Math.min(tb.maxY, tb.minY + inward)
    else p.y = Math.max(tb.minY, tb.maxY - inward)
    root.petX = p.x
    root.petY = p.y
    root.targetX = tb.minX + Math.random() * Math.max(1, tb.maxX - tb.minX)
    root.targetY = tb.minY + Math.random() * Math.max(1, tb.maxY - tb.minY)
    return true
  }

  function clampTo(window) {
    if (root.inGame && root.gameOutput && root.game !== "scoop") {
      var gs = root.screenByName(root.gameOutput)
      if (gs) {
        var gb = root.walkBoundsForScreen(gs)
        root.petX = Math.min(gb.maxX, Math.max(gb.minX, root.petX))
        root.petY = Math.min(gb.maxY, Math.max(gb.minY, root.petY))
        return
      }
    }
    if (root.tryScreenHop()) return
    var rects = root.walkRects()
    if (!rects.length) return
    var p = root.clampPointToRects(root.petX, root.petY, rects)
    root.petX = p.x
    root.petY = p.y
  }

  function placeIfNeeded(window) {
    if (root.placed) return
    var s = root.confineScreen() || root.firstScreen()
    if (!s || s.width < 40) return
    var b = root.walkBoundsForScreen(s)
    root.petX = b.minX + (b.maxX - b.minX) * 0.72
    root.petY = b.minY + (b.maxY - b.minY) * 0.58
    root.pickTarget(window)
    root.placed = true
  }

  function step(window, dt) {
    var s = root.screenAtPet() || root.firstScreen()
    if (!s || s.width < 40) return

    if (!root.pet || !root.opened) {
      root.moving = false
      if (root.pet) root.pet.walking = false
      return
    }

    root.placeIfNeeded(window)
    if (!root.holding)
      root.clampTo(window)
    if (root.pet) {
      var here = root.screenAtPet() || s
      root.pet.dropX = root.petX - here.x
      root.pet.dropY = root.petY - here.y
      root.pet.dropOutput = here.name || ""
      root.pet.pinHomelessGraves(root.pet.dropOutput)
    }

    if (root.game === "eat") {
      root.stepEat(dt)
      if (root.holding) {
        root.moving = false
        if (root.pet) root.pet.walking = true
        return
      }
      root.moving = false
      if (root.pet) root.pet.walking = false
      return
    }

    if (root.holding) {
      root.moving = false
      if (root.pet) root.pet.walking = true
      return
    }

    if (root.game === "play") {
      root.stepPlay(window, dt)
      return
    }

    if (root.inGame) {
      root.moving = false
      if (root.pet) root.pet.walking = false
      return
    }

    if (!root.pet.hatched) {
      root.moving = false
      root.pet.walking = false
      return
    }

    if (root.toyPlaying && !root.canToyPlay())
      root.endToyPlay(true)

    if (root.toyPlaying) {
      root.moving = false
      if (root.pet) root.pet.walking = false
      root.toyPlayTick(dt)
      return
    }

    if (root.pet.sleeping || root.watching || root.dancing) {
      root.moving = false
      root.pet.walking = false
      if (root.watching) root.facingLeft = false
      root.pauseMs = 800
      return
    }

    if (root.pauseMs > 0) {
      root.pauseMs -= dt
      root.moving = false
      root.pet.walking = false
      if (root.pauseMs <= 0) root.pickTarget(window)
      return
    }

    var dx = root.targetX - root.petX
    var dy = root.targetY - root.petY
    var dist = Math.sqrt(dx * dx + dy * dy)
    if (dist < 5) {
      root.moving = false
      root.pet.walking = false
      root.pauseMs = 1400 + Math.random() * 4200
      root.pickTarget(window)
      return
    }

    var speed = (root.pet.mood === "hungry" || root.pet.mood === "sad") ? 48 : 78
    root.petX += (dx / dist) * speed * dt / 1000
    root.petY += (dy / dist) * speed * dt / 1000
    root.facingLeft = dx < 0
    root.moving = true
    root.pet.walking = true
    root.tryScreenHop()
  }

  function spawnHeart() {
    hearts.append({ hx: root.petX + spriteW * 0.55, hy: root.petY - 4, born: Date.now() })
  }

  function screenBounds() {
    var s = root.screenAtPet() || root.firstScreen()
    if (!s) return { minX: 0, maxX: 0, minY: 0, maxY: 0 }
    var minX = s.x + root.barClearance("left")
    var minY = s.y + root.barClearance("top")
    var maxX = Math.max(minX, s.x + s.width - spriteW - root.barClearance("right"))
    var maxY = Math.max(minY, s.y + s.height - spriteH - root.barClearance("bottom"))
    return { minX: minX, maxX: maxX, minY: minY, maxY: maxY }
  }

  function dragBounds() {
    var rects = []
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      var s = screens[i]
      if (!s) continue
      rects.push({
        minX: s.x + 4,
        maxX: s.x + s.width - spriteW - 4,
        minY: s.y + 4,
        maxY: s.y + s.height - spriteH - 4
      })
    }
    return rects
  }

  function centerPet() {
    var s = root.screenAtPet() || root.firstScreen()
    if (!s) return
    var b = root.walkBoundsForScreen(s)
    root.petX = b.minX + (b.maxX - b.minX) * 0.5
    root.petY = b.minY + (b.maxY - b.minY) * 0.5
    root.placed = true
    if (root.pet) {
      root.pet.dropX = root.petX - s.x
      root.pet.dropY = root.petY - s.y
      root.pet.dropOutput = s.name || ""
      root.pet.pinHomelessGraves(root.pet.dropOutput)
    }
    root.pickTarget(null)
  }

  function putPet(x, y) {
    var rects = root.dragBounds()
    if (!rects.length) {
      var b = root.screenBounds()
      root.petX = Math.min(b.maxX, Math.max(b.minX, x))
      root.petY = Math.min(b.maxY, Math.max(b.minY, y))
    } else {
      var p = root.clampPointToRects(x, y, rects)
      root.petX = p.x
      root.petY = p.y
    }
    root.placed = true
  }

  function actionUnderPet() {
    var s = root.screenAtPet()
    if (!s) return ""
    var names = ["sleep", "eat", "play", "bath", "scoop", "farm"]
    var iconW = 56
    var iconH = 70
    var spacing = 4
    var lx = root.petX - s.x
    var ly = root.petY - s.y
    var cx = lx + spriteW / 2
    var cy = ly + spriteH / 2
    var pad = 8
    var best = ""
    var bestD = 1e9
    for (var i = 0; i < names.length; i++) {
      var ix = root.menuX + i * (iconW + spacing)
      var iy = root.menuY
      if (lx >= ix + iconW + pad || lx + spriteW <= ix - pad || ly >= iy + iconH + pad || ly + spriteH <= iy - pad)
        continue
      var dx = cx - (ix + iconW / 2)
      var dy = cy - (iy + iconH / 2)
      var d = dx * dx + dy * dy
      if (d < bestD) {
        bestD = d
        best = names[i]
      }
    }
    return best
  }

  function placeHoldMenu() {
    var s = root.screenAtPet() || root.nearestScreen(root.petX, root.petY)
    if (!s) return
    root.menuOutput = s.name || ""
    var rowW = 360
    var iconH = 70
    var extraBelow = 118
    var caption = (root.pet && (root.pet.carePaused || root.pet.crisisSleep)) ? 28 : 0
    var rowH = iconH + extraBelow
    var minX = 12
    var maxX = Math.max(minX, s.width - rowW - 12)
    var lx = root.petX - s.x
    var ly = root.petY - s.y
    var cx = lx + spriteW / 2
    root.menuX = Math.min(maxX, Math.max(minX, cx - rowW / 2))
    var below = ly + spriteH + 12 + caption
    var above = ly - rowH - 12 - caption
    var maxY = s.height - rowH - root.barClearance("bottom")
    var minY = root.barClearance("top")
    if (below <= maxY) root.menuY = below
    else root.menuY = Math.min(maxY, Math.max(minY, above))
  }

  function canToyPlay() {
    if (!root.pet || !root.opened || !root.pet.hatched) return false
    if (!root.pet.equippedToy || !root.pet.toyItem) return false
    if (root.pet.sleeping || root.holding || root.inGame || root.drawing || root.naming) return false
    return true
  }

  function resetToyPlayVisuals() {
    root.toyPlaying = false
    root.toyPlayT = 0
    root.toyPlayElapsed = 0
    root.toyOffX = 0
    root.toyOffY = 0
    root.toyRot = 0
    root.toyScale = 1
    root.petRot = 0
    root.toyFacingLeft = false
    root.toyThrowPhase = -1
    root.toyCatchPhase = -1
  }

  function scheduleToyPlay(ms) {
    root.toyPlayDueAt = Date.now() + Math.max(400, Math.floor(ms))
  }

  function nextToyPlayDelay() {
    return 60000 + Math.floor(Math.random() * 60000)
  }

  function startToyPlay() {
    if (!root.canToyPlay()) {
      root.scheduleToyPlay(8000)
      return
    }
    root.toyPlaying = true
    root.toyPlayKind = root.pet.toyPlay || "think"
    root.toyPlayElapsed = 0
    root.toyPlayT = 0
    root.toyPlayDur = 12000
    root.toyPlayDir = root.facingLeft ? -1 : 1
    root.toyThrowPhase = -1
    root.toyCatchPhase = -1
    root.toyPlayTick(0)
  }

  function endToyPlay(soon) {
    root.resetToyPlayVisuals()
    root.scheduleToyPlay(soon ? 12000 + Math.floor(Math.random() * 8000) : root.nextToyPlayDelay())
  }

  function toyPlayTick(dt) {
    root.toyPlayElapsed += Math.max(0, dt)
    var t = root.toyPlayElapsed / root.toyPlayDur
    if (t >= 1) {
      root.endToyPlay()
      return
    }
    root.toyPlayT = t
    var kind = root.toyPlayKind
    var dir = root.toyPlayDir
    root.petRot = 0
    root.toyScale = 1
    root.toyFacingLeft = false
    if (kind === "glide") {
      var passes = 4
      var u = (t * passes) % 1
      var goingRight = Math.floor(t * passes) % 2 === 0
      var ease = 0.5 - 0.5 * Math.cos(u * Math.PI)
      var span = 58
      root.toyOffX = goingRight ? (-span + ease * span * 2) : (span - ease * span * 2)
      root.toyOffY = 0
      root.toyRot = goingRight ? -3 : 3
      root.toyFacingLeft = !goingRight
      root.facingLeft = !goingRight
    } else if (kind === "roll") {
      var a = t * Math.PI * 8
      root.toyOffX = Math.sin(a) * 48
      root.toyOffY = (1 - Math.abs(Math.cos(a))) * -8
      root.toyRot = t * 1440
      root.toyFacingLeft = Math.cos(a) < 0
      if (Math.cos(a) > 0.2) root.facingLeft = false
      else if (Math.cos(a) < -0.2) root.facingLeft = true
    } else if (kind === "jump") {
      root.toyOffX = 0
      root.toyOffY = Math.round(-Math.abs(Math.sin(t * Math.PI * 6)) * 10)
      root.toyRot = 0
    } else if (kind === "spin") {
      var s = t * Math.PI * 4
      root.petRot = t * 720
      root.toyOffX = Math.cos(s) * 24
      root.toyOffY = Math.sin(s) * 12 - 4
      root.toyRot = t * 720
    } else if (kind === "throw") {
      var cycles = 2
      var u = (t * cycles) % 1
      var phase = Math.floor(t * cycles)
      if (phase !== root.toyThrowPhase && u < 0.15) {
        root.toyThrowPhase = phase
        throwSfx.stop()
        throwSfx.play()
      }
      if (u > 0.88 && root.toyCatchPhase !== phase) {
        root.toyCatchPhase = phase
        catchSfx.stop()
        catchSfx.play()
      }
      root.toyOffX = dir * u * 52
      root.toyOffY = -Math.sin(u * Math.PI) * 36
      root.toyRot = u * 360 * dir
    } else {
      root.toyOffX = dir * 16
      root.toyOffY = -20 + Math.sin(t * Math.PI * 4) * 5
      root.toyRot = Math.sin(t * Math.PI * 2) * 14
      root.toyScale = 1 + 0.06 * Math.sin(t * Math.PI * 4)
    }
  }

  function grabPet(px, py) {
    if (root.toyPlaying) root.endToyPlay(true)
    root.holding = true
    root.grabOffX = px - root.petX
    root.grabOffY = py - root.petY
    root.grabStartX = root.petX
    root.grabStartY = root.petY
    root.hoverAction = ""
    root.moving = false
    if (root.pet) {
      root.pet.walking = true
      if (root.pet.hatched && root.pet.sleeping && !root.pet.crisisSleep) root.pet.toggleSleep()
    }
    root.placeHoldMenu()
    Qt.callLater(root.placeHoldMenu)
  }

  function moveHeldPet(px, py) {
    if (!root.holding) return
    var nx = px - root.grabOffX
    var ny = py - root.grabOffY
    if (nx !== root.petX) root.facingLeft = nx < root.petX
    root.putPet(nx, ny)
    var here = root.screenNameAtPet()
    if (here && here !== root.menuOutput)
      root.placeHoldMenu()
    root.hoverAction = (root.pet && root.pet.hatched) ? root.actionUnderPet() : ""
  }

  function confirmOverlayHatch(name) {
    if (!root.pet || root.pet.hatched) return
    root.pet.hatch(name)
  }

  function cancelOverlayHatch() {
    if (root.pet) root.pet.cancelHatch()
  }

  function dropPet() {
    if (!root.holding) return
    root.holding = false
    var act = root.hoverAction
    root.hoverAction = ""
    root.menuOutput = ""
    if (root.pet) root.pet.walking = false
    root.pauseMs = 800
    if (!root.pet) return
    if (!root.pet.hatched) {
      var dx = root.petX - root.grabStartX
      var dy = root.petY - root.grabStartY
      if ((dx * dx + dy * dy) < (16 * 16))
        root.pet.beginHatch()
      return
    }
    if (act) root.startGame(act)
  }

  function startGame(kind) {
    root.game = kind
    root.gameOutput = root.screenNameAtPet()
    root.grateTravel = 0
    root.eatScore = 0
    root.playScore = 0
    root.gameNeed = 1
    root.scrub = 0
    root.lullabyHits = 0
    root.ballLive = false
    root.brushHeld = false
    root.scoopHeld = false
    root.scoopStart = 0
    root.lastGrateX = -1
    root.lastGrateY = -1
    foods.clear()
    shreds.clear()
    if (kind === "eat")
      root.gameNeed = Model.stepsToFill(root.pet.hunger, Model.NIBBLE_HUNGER)
    else if (kind === "play")
      root.gameNeed = Model.stepsToFill(root.pet.happiness, Model.PLAY_HAPPY)
    else if (kind === "sleep")
      root.gameNeed = Model.stepsToFill(root.pet.energy, Model.LULLABY_ENERGY)
    if (kind === "sleep") {
      var keys = ["W", "A", "S", "D"]
      var seq = []
      for (var i = 0; i < root.gameNeed; i++) seq.push(keys[Math.floor(Math.random() * 4)])
      root.lullabyKeys = seq
    }
    if (kind === "bath")
      root.placeBrushBesidePet()
    if (kind === "scoop") {
      root.scoopStart = root.pet ? root.pet.messCount : 0
      root.placeScoopBesidePet()
    }
  }

  function endGame(ok) {
    var kind = root.game
    root.game = ""
    root.gameOutput = ""
    root.holding = false
    root.brushHeld = false
    root.scoopHeld = false
    foods.clear()
    shreds.clear()
    root.ballLive = false
    if (!ok || !root.pet) return
    if (kind === "sleep") root.pet.lullaby()
    else if (kind === "bath") root.pet.bath()
    else if (kind === "farm") {
      root.waitMouseUp = true
      root.centerPet()
      root.pet.finishFarm()
    }
    if (kind !== "farm") root.spawnHeart()
  }

  function keyLetter(event) {
    if (event.key === Qt.Key_W || event.key === Qt.Key_Up) return "W"
    if (event.key === Qt.Key_A || event.key === Qt.Key_Left) return "A"
    if (event.key === Qt.Key_S || event.key === Qt.Key_Down) return "S"
    if (event.key === Qt.Key_D || event.key === Qt.Key_Right) return "D"
    return ""
  }

  function playLullabyTone(letter) {
    var tone = letter === "W" ? toneW
      : letter === "A" ? toneA
      : letter === "S" ? toneS
      : letter === "D" ? toneD
      : null
    if (!tone) return
    tone.stop()
    tone.play()
  }

  function playMunch() {
    munch.stop()
    munch.play()
  }

  function playSfx(fx) {
    if (!fx) return
    fx.stop()
    fx.play()
  }

  function playSoapPickup() {
    root.playSfx(soapSfx)
  }

  function playScrubSfx() {
    var t = Date.now()
    if (t - root.lastScrubSfx < 80) return
    root.lastScrubSfx = t
    root.playSfx(scrubSfx)
  }

  function playGrateSfx() {
    var t = Date.now()
    if (t - root.lastGrateSfx < 70) return
    root.lastGrateSfx = t
    root.playSfx(grateSfx)
  }

  function gameStepDone(score) {
    if (score >= root.gameNeed) return true
    if (!root.pet) return false
    if (root.game === "eat") return Model.barFull(root.pet.hunger)
    if (root.game === "play") return Model.barFull(root.pet.happiness)
    if (root.game === "sleep") return Model.barFull(root.pet.energy)
    return false
  }

  function pressLullaby(letter) {
    if (root.game !== "sleep" || !letter) return
    root.playLullabyTone(letter)
    var need = root.lullabyKeys[root.lullabyHits] || ""
    if (letter !== need) return
    root.lullabyHits = root.lullabyHits + 1
    if (root.pet) root.pet.lullabyNote()
    if (root.gameStepDone(root.lullabyHits)) root.endGame(true)
  }

  function handleLullabyKey(event) {
    root.pressLullaby(root.keyLetter(event))
  }

  function stepEat(dt) {
    var s = root.screenByName(root.gameOutput) || root.screenAtPet()
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    var floor = s ? s.height : 2000
    for (var i = foods.count - 1; i >= 0; i--) {
      var f = foods.get(i)
      var ny = f.fy + 0.22 * dt
      if (ny > floor) {
        foods.remove(i)
        continue
      }
      foods.setProperty(i, "fy", ny)
      if (f.fx + root.foodSize > lx && f.fx < lx + spriteW && ny + root.foodSize > ly && ny < ly + spriteH) {
        foods.remove(i)
        root.eatScore = root.eatScore + 1
        if (root.pet) root.pet.nibble()
        root.playMunch()
        root.spawnHeart()
        if (root.gameStepDone(root.eatScore)) root.endGame(true)
      }
    }
  }

  function stepPlay(window, dt) {
    if (!root.ballLive) {
      root.moving = false
      if (root.pet) root.pet.walking = false
      return
    }
    var sec = dt / 1000
    if (root.ballPhase === 0) {
      root.ballT += sec / Math.max(0.12, root.ballDur)
      var u = Math.min(1, root.ballT)
      var e = u * u * (3 - 2 * u)
      root.ballX = root.ballStartX + (root.ballLandX - root.ballStartX) * e
      root.ballY = root.ballStartY + (root.ballLandY - root.ballStartY) * e - 78 * 4 * u * (1 - u)
      if (u >= 1) {
        root.ballPhase = 1
        root.bounceT = 0
        root.ballX = root.ballLandX
        root.ballY = root.ballLandY
      }
    } else if (root.ballPhase === 1) {
      root.bounceT += sec
      var t = root.bounceT
      var hop = 0
      if (t < 0.16) hop = 20 * Math.sin(Math.PI * t / 0.16)
      else if (t < 0.28) hop = 9 * Math.sin(Math.PI * (t - 0.16) / 0.12)
      else if (t < 0.38) hop = 3 * Math.sin(Math.PI * (t - 0.28) / 0.10)
      else {
        hop = 0
        root.ballPhase = 2
      }
      root.ballX = root.ballLandX
      root.ballY = root.ballLandY - hop
    }

    var s = root.screenByName(root.gameOutput) || root.screenAtPet()
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    var cx = lx + spriteW / 2
    var cy = ly + spriteH / 2
    var dx = root.ballX + root.ballSize / 2 - cx
    var dy = root.ballY + root.ballSize / 2 - cy
    var dist = Math.sqrt(dx * dx + dy * dy)
    if (root.ballPhase === 2 && dist < 40) {
      root.ballLive = false
      root.playScore = root.playScore + 1
      root.playSfx(catchSfx)
      if (root.pet) root.pet.play()
      root.spawnHeart()
      root.moving = false
      if (root.pet) root.pet.walking = false
      if (root.gameStepDone(root.playScore)) root.endGame(true)
      return
    }
    var speed = 280
    if (dist > 4) {
      root.petX += (dx / dist) * speed * dt / 1000
      root.petY += (dy / dist) * speed * dt / 1000
      root.facingLeft = dx < 0
      root.moving = true
      if (root.pet) root.pet.walking = true
    } else {
      root.moving = false
      if (root.pet) root.pet.walking = false
    }
    root.clampTo(window)
  }

  function throwBall(px, py) {
    if (root.game !== "play" || root.ballLive) return
    var s = root.screenByName(root.gameOutput) || root.screenAtPet() || root.firstScreen()
    var w = s ? s.width : 800
    var h = s ? s.height : 600
    var minX = root.barClearance("left")
    var minY = root.barClearance("top")
    var maxX = Math.max(minX, w - root.ballSize - root.barClearance("right"))
    var maxY = Math.max(minY, h - root.ballSize - root.barClearance("bottom"))
    var tx = Math.min(maxX, Math.max(minX, px - root.ballSize / 2))
    var ty = Math.min(maxY, Math.max(minY, py - root.ballSize / 2))
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    root.ballStartX = lx + spriteW / 2 - root.ballSize / 2
    root.ballStartY = ly + spriteH / 2 - root.ballSize / 2
    root.ballLandX = tx
    root.ballLandY = ty
    root.ballX = root.ballStartX
    root.ballY = root.ballStartY
    var dx = tx - root.ballStartX
    var dy = ty - root.ballStartY
    var dist = Math.sqrt(dx * dx + dy * dy)
    root.ballDur = Math.max(0.28, Math.min(0.65, dist / 980))
    root.ballT = 0
    root.bounceT = 0
    root.ballPhase = 0
    root.ballLive = true
    root.playSfx(throwSfx)
  }

  function placeBrushBesidePet() {
    var s = root.screenByName(root.gameOutput) || root.screenAtPet()
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    var w = s ? s.width : 800
    var right = lx + spriteW + 58
    var left = lx - 58
    var x = right
    if (w > 40 && right > w - root.barClearance("right") - 24)
      x = left
    root.lastBrushX = x
    root.lastBrushY = ly + spriteH * 0.42
    root.brushHeld = false
  }

  function nearBrush(px, py) {
    var dx = px - root.lastBrushX
    var dy = py - root.lastBrushY
    return (dx * dx + dy * dy) < (38 * 38)
  }

  function scrubAt(px, py) {
    if (!root.brushHeld) return
    var s = root.screenByName(root.gameOutput) || root.screenAtPet()
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    if (root.lastBrushX >= 0) {
      var d = Math.sqrt((px - root.lastBrushX) * (px - root.lastBrushX) + (py - root.lastBrushY) * (py - root.lastBrushY))
      if (px >= lx && px <= lx + spriteW && py >= ly && py <= ly + spriteH) {
        root.scrub += d
        if (d > 1.5) {
          root.playScrubSfx()
          if (root.pet) root.pet.wash(d * 0.55)
        }
      }
    }
    root.lastBrushX = px
    root.lastBrushY = py
    if (root.pet && root.pet.dirty <= 0.5) root.endGame(true)
  }

  function placeScoopBesidePet() {
    var s = root.screenByName(root.gameOutput) || root.screenAtPet()
    var originX = s ? s.x : 0
    var originY = s ? s.y : 0
    var lx = s ? root.petX - s.x : root.petX
    var ly = s ? root.petY - s.y : root.petY
    var w = s ? s.width : 800
    var right = lx + spriteW + 58
    var left = lx - 58
    var x = right
    if (w > 40 && right > w - root.barClearance("right") - 24)
      x = left
    root.lastScoopX = originX + x
    root.lastScoopY = originY + ly + spriteH * 0.42
    root.scoopHeld = false
  }

  function nearScoop(gx, gy) {
    var dx = gx - root.lastScoopX
    var dy = gy - root.lastScoopY
    return (dx * dx + dy * dy) < (38 * 38)
  }

  function scoopAt(gx, gy) {
    if (!root.scoopHeld || !root.pet) return
    root.lastScoopX = gx
    root.lastScoopY = gy
    var s = root.screenAt(gx, gy)
    if (!s) return
    var size = Model.MESS_COLS * Model.MESS_PIXEL
    if (root.pet.scoopNear(gx - s.x, gy - s.y, s.name || "", size, Model.MESS_SCOOP_RADIUS)) {
      root.playSfx(catchSfx)
      root.spawnHeart()
      if (root.pet.messCount <= 0) root.endGame(true)
    }
  }

  function spawnShredsAt(gx, gy, gw, n) {
    gw = Math.max(8, gw)
    while (shreds.count > 90)
      shreds.remove(0)
    for (var i = 0; i < n; i++) {
      shreds.append({
        sx: gx + Math.random() * gw,
        sy: gy + Math.random() * 6,
        svx: (Math.random() - 0.5) * 70,
        svy: 50 + Math.random() * 90,
        ssize: 2 + Math.floor(Math.random() * 4),
        sdark: Math.random() < 0.45 ? 1 : 0,
        sborn: Date.now()
      })
    }
  }

  function stepShreds(dt) {
    var g = 540
    var now = Date.now()
    for (var i = shreds.count - 1; i >= 0; i--) {
      var s = shreds.get(i)
      if (now - s.sborn > 1300 || s.sy > 2400) {
        shreds.remove(i)
        continue
      }
      shreds.setProperty(i, "sx", s.sx + s.svx * dt / 1000)
      shreds.setProperty(i, "sy", s.sy + s.svy * dt / 1000)
      shreds.setProperty(i, "svy", s.svy + g * dt / 1000)
    }
  }

  function applyPenScreen() {
    root.confineToPen()
  }

  function confineToPen() {
    if (!root.placed) return
    root.clampTo(null)
    root.pickTarget(null)
  }

  function applyDrawScreen() {
  }

  function cancelPenDraw() {
    root.dragging = false
    if (root.pet) root.pet.cancelDrawPen()
  }

  function beginPenDrag(x, y) {
    root.dragging = true
    root.dragStartX = x
    root.dragStartY = y
    root.dragX = x
    root.dragY = y
  }

  function updatePenDrag(x, y) {
    if (!root.dragging) return
    root.dragX = x
    root.dragY = y
  }

  function endPenDrag(x, y, outputName) {
    if (!root.dragging) return
    root.updatePenDrag(x, y)
    root.dragging = false
    var bx = Math.min(root.dragStartX, root.dragX)
    var by = Math.min(root.dragStartY, root.dragY)
    var bw = Math.abs(root.dragX - root.dragStartX)
    var bh = Math.abs(root.dragY - root.dragStartY)
    if (!root.pet || bw < 80 || bh < 80) {
      root.cancelPenDraw()
      return
    }
    root.pet.setPen(bx, by, bw, bh, outputName || "")
    root.placed = true
    Qt.callLater(function() {
      root.clampTo(null)
      root.pickTarget(null)
    })
  }

  SoundEffect { id: toneW; source: Qt.resolvedUrl("sounds/lullaby-w.wav"); volume: 0.55 }
  SoundEffect { id: toneA; source: Qt.resolvedUrl("sounds/lullaby-a.wav"); volume: 0.55 }
  SoundEffect { id: toneS; source: Qt.resolvedUrl("sounds/lullaby-s.wav"); volume: 0.55 }
  SoundEffect { id: toneD; source: Qt.resolvedUrl("sounds/lullaby-d.wav"); volume: 0.55 }
  SoundEffect { id: munch; source: Qt.resolvedUrl("sounds/munch.wav"); volume: 0.7 }
  SoundEffect { id: throwSfx; source: Qt.resolvedUrl("sounds/throw.wav"); volume: 0.55 }
  SoundEffect { id: catchSfx; source: Qt.resolvedUrl("sounds/catch.wav"); volume: 0.6 }
  SoundEffect { id: soapSfx; source: Qt.resolvedUrl("sounds/soap.wav"); volume: 0.65 }
  SoundEffect { id: scrubSfx; source: Qt.resolvedUrl("sounds/scrub.wav"); volume: 0.45 }
  SoundEffect { id: grateSfx; source: Qt.resolvedUrl("sounds/grate.wav"); volume: 0.5 }

  Timer {
    interval: (root.pet && !root.pet.hatched) ? 560 : 180
    repeat: true
    running: root.opened && (root.moving || root.dancing || root.holding || root.toyPlaying || (root.pet && !root.pet.hatched))
    onTriggered: root.walkFrame = (root.walkFrame + 1) % 2
  }

  Timer {
    interval: 280
    repeat: true
    running: root.opened && root.pet && root.pet.hatched
    onTriggered: root.shopFrame = (root.shopFrame + 1) % 5
  }

  Timer {
    interval: 520
    repeat: true
    running: root.game === "eat"
    onTriggered: {
      var s = root.screenByName(root.gameOutput) || root.screenAtPet() || root.firstScreen()
      var w = s ? s.width : 800
      foods.append({
        fx: root.barClearance("left") + Math.random() * Math.max(40, w - 40 - root.barClearance("left") - root.barClearance("right") - root.foodSize),
        fy: root.barClearance("top") + 8,
        kind: Math.random() < 0.5 ? "pizza" : "burger",
        spin: (Math.random() * 50) - 25
      })
    }
  }


  Connections {
    target: root.pet
    function onHasPenChanged() { root.applyPenScreen() }
    function onPenOutputChanged() { root.applyPenScreen() }
    function onConfineOutputChanged() { root.applyPenScreen() }
    function onDrawingPenChanged() {
      root.dragging = false
    }
    function onEquippedToyChanged() {
      if (root.toyPlaying) root.resetToyPlayVisuals()
      root.toyPlayDueAt = 0
    }
    function onShownChanged() {
      if (root.toyPlaying && !(root.pet && root.pet.shown)) root.resetToyPlayVisuals()
      root.toyPlayDueAt = 0
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.pet && root.pet.hatched && !!root.pet.equippedToy
    onTriggered: {
      if (root.toyPlaying) return
      if (!root.pet.toyItem) return
      if (root.toyPlayDueAt <= 0)
        root.scheduleToyPlay(3000 + Math.floor(Math.random() * 4000))
      if (Date.now() < root.toyPlayDueAt) return
      if (root.canToyPlay())
        root.startToyPlay()
      else
        root.scheduleToyPlay(8000)
    }
  }

  Timer {
    interval: 16
    repeat: true
    running: root.opened || hearts.count > 0 || notes.count > 0 || shreds.count > 0 || root.inGame || root.holding
    onTriggered: {
      root.nowMs = Date.now()
      root.step(null, interval)
      root.stepShreds(interval)
      for (var i = hearts.count - 1; i >= 0; i--) {
        if (root.nowMs - hearts.get(i).born > 900) hearts.remove(i)
      }
      for (var n = notes.count - 1; n >= 0; n--) {
        if (root.nowMs - notes.get(n).born > 1100) notes.remove(n)
      }
    }
  }

  Timer {
    interval: 420
    repeat: true
    running: root.opened && root.dancing
    onTriggered: {
      var side = Math.random() < 0.5 ? -1 : 1
      notes.append({
        nx: side < 0
          ? root.petX - 10 - Math.random() * 16
          : root.petX + spriteW + 6 + Math.random() * 16,
        ny: root.petY + spriteH * 0.22 + Math.random() * spriteH * 0.28,
        nside: side,
        born: Date.now()
      })
    }
  }

  Variants {
    model: Quickshell.screens
    OverlayScreen {
      host: root
    }
  }
}
