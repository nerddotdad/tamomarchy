import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Model.js" as Model
import "catalog"


// Persistent pet: hunger, mood, energy, and whether the overlay is showing.
// Overlay and bar widget both read this singleton.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/tamagotchi.json"
  readonly property int stateCap: 262144
  readonly property string stateHelper: {
    var u = String(Qt.resolvedUrl("scripts/state-file.py"))
    if (u.indexOf("file://") === 0) u = u.substring(7)
    return u
  }

  property string petName: ""
  property bool hatched: false
  property bool naming: false
  property var genome: null
  property real hunger: 100
  property real happiness: 100
  property real energy: 100
  property real dirty: 0
  property bool sleeping: false
  property bool shown: true
  property bool drawingPen: false
  property bool hasPen: false
  property real penX: 0
  property real penY: 0
  property real penW: 0
  property real penH: 0
  property string penOutput: ""
  property string confineOutput: ""
  property string drawOnOutput: ""
  property double bornAt: Date.now()
  property double lastTick: Date.now()
  property bool walking: false
  property real dropX: 80
  property real dropY: 120
  property string dropOutput: ""
  property double poopBoostUntil: 0
  property bool youtubeWindow: false
  property double hungerEmptySince: 0
  property double happyEmptySince: 0
  property bool _skipGraveApply: false
  property bool gravesShown: true
  property int graveRev: 0
  property bool maintenance: true
  property string difficulty: "medium"
  property bool noDeath: false
  property bool farming: false
  property int score: 0
  property double scoreAccruedMs: 0
  property var ownedHats: []
  property var ownedToys: []
  property var ownedGear: []
  property string equippedHat: ""
  property string equippedToy: ""
  property int shopRev: 0

  property bool _hydrating: true
  property bool _loaded: false
  property bool _skipMessApply: false

  readonly property var media: shell ? shell.firstPartyServiceFor("omarchy.media") : null
  readonly property var mprisPlayers: Mpris.players ? Mpris.players.values : []
  readonly property bool youtubePlaying: {
    if (root.youtubeWindow) return true
    var p = root.media && root.media.activePlayer
    if (p && p.isPlaying && root.looksLikeYoutube(p)) return true
    var list = root.mprisPlayers
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying && root.looksLikeYoutube(list[i])) return true
    }
    return false
  }
  readonly property bool musicPlaying: {
    if (root.youtubePlaying) return false
    var p = root.media && root.media.activePlayer
    if (p && p.isPlaying) return true
    var list = root.mprisPlayers
    for (var i = 0; i < list.length; i++) {
      if (list[i] && list[i].isPlaying) return true
    }
    return false
  }
  readonly property string scene: {
    if (!hatched) return ""
    if (sleeping) return "sleep"
    if (youtubePlaying) return "tv"
    if (musicPlaying) return "music"
    return ""
  }

  readonly property string mood: Model.mood(snapshot())
  readonly property string moodLabel: Model.moodLabel(mood)
  readonly property string speech: Model.speech(snapshot())
  readonly property string ageLabel: Model.ageLabel(bornAt, Date.now(), hatched)
  readonly property int hungerPct: Math.round(hunger)
  readonly property int happinessPct: Math.round(happiness)
  readonly property int energyPct: Math.round(energy)
  readonly property int dirtyPct: Math.round(dirty)
  readonly property int messCount: messItems.count
  readonly property int pottyPct: Math.round(Math.min(100, messCount * Model.POTTY_PER_MESS))
  readonly property int graveCount: graveItems.count
  readonly property string coinLabel: Model.formatCoins(score)
  readonly property bool carePaused: maintenance === false
  readonly property string difficultyLabel: Model.difficultyLabel(difficulty)
  readonly property bool crisisSleep: Model.inCrisisSleep({
    hatched: hatched,
    noDeath: noDeath,
    hungerEmptySince: hungerEmptySince,
    happyEmptySince: happyEmptySince
  }, lastTick)
  readonly property var shopHats: catalog.hats
  readonly property var shopToys: catalog.toys
  readonly property var shopGear: catalog.gear
  readonly property var hatItem: catalog.itemById("hat", equippedHat)
  readonly property var toyItem: catalog.itemById("toy", equippedToy)
  readonly property var ownedGearItems: {
    var _ = root.shopRev
    var list = root.shopGear || []
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (root.owns("gear", list[i].id)) out.push(list[i])
    }
    return out
  }
  readonly property string toyPlay: toyItem && toyItem.play ? String(toyItem.play) : ""
  readonly property var partSet: partsCatalog.partSet

  ListModel { id: messItems }
  readonly property alias messModel: messItems
  ListModel { id: graveItems }
  readonly property alias graveModel: graveItems

  function looksLikeYoutube(player) {
    if (!player) return false
    var blob = ((player.identity || "") + " " + (player.trackTitle || "") + " " + (player.desktopEntry || "")).toLowerCase()
    return blob.indexOf("youtube") !== -1
  }

  function messSnapshot() {
    var out = []
    for (var i = 0; i < messItems.count; i++) {
      var row = messItems.get(i)
      out.push({ kind: row.kind, x: row.x, y: row.y, bornAt: row.bornAt, output: row.output || "" })
    }
    return out
  }

  function replaceMess(list) {
    messItems.clear()
    var next = Model.normalizeMess(list)
    for (var i = 0; i < next.length; i++)
      messItems.append(next[i])
  }

  function bumpGraves() {
    graveRev++
  }

  function replaceGraves(list) {
    graveItems.clear()
    var next = Model.normalizeGraves(list, root.partSet)
    for (var i = 0; i < next.length; i++) {
      var g = next[i]
      graveItems.append({
        name: g.name,
        genomeJson: JSON.stringify(g.genome || {}),
        bornAt: g.bornAt,
        diedAt: g.diedAt,
        cause: g.cause,
        output: g.output || ""
      })
    }
    root.bumpGraves()
  }

  function graveSnapshot() {
    var out = []
    for (var i = 0; i < graveItems.count; i++) {
      var row = graveItems.get(i)
      out.push({
        name: row.name,
        genome: root.parseGenomeJson(row.genomeJson),
        bornAt: row.bornAt,
        diedAt: row.diedAt,
        cause: row.cause,
        output: row.output || ""
      })
    }
    return out
  }

  function parseGenomeJson(text) {
    try {
      var g = JSON.parse(text || "{}")
      return Model.normalizeGenome(g, root.partSet)
    } catch (e) {
      return Model.normalizeGenome(null, root.partSet)
    }
  }

  function snapshot() {
    return {
      name: petName,
      hatched: hatched,
      genome: hatched ? genome : null,
      hunger: hunger,
      happiness: happiness,
      energy: energy,
      dirty: dirty,
      sleeping: sleeping,
      shown: shown,
      pen: hasPen ? { x: penX, y: penY, w: penW, h: penH, output: penOutput } : null,
      confineOutput: confineOutput,
      mess: messSnapshot(),
      graves: graveSnapshot(),
      gravesShown: gravesShown,
      maintenance: maintenance,
      difficulty: difficulty,
      noDeath: noDeath,
      hungerEmptySince: hungerEmptySince,
      happyEmptySince: happyEmptySince,
      bornAt: bornAt,
      lastTick: lastTick,
      score: score,
      scoreAccruedMs: scoreAccruedMs,
      ownedHats: ownedHats,
      ownedToys: ownedToys,
      ownedGear: ownedGear,
      equippedHat: equippedHat,
      equippedToy: equippedToy,
      dropOutput: dropOutput
    }
  }

  function applyPen(pen) {
    var next = Model.normalizePen(pen)
    hasPen = next !== null
    penX = next ? next.x : 0
    penY = next ? next.y : 0
    penW = next ? next.w : 0
    penH = next ? next.h : 0
    penOutput = next && next.output ? String(next.output) : ""
  }

  function apply(next) {
    hatched = next.hatched === true
    petName = hatched ? next.name : ""
    var g = hatched ? Model.normalizeGenome(next.genome, root.partSet) : null
    if (!Model.genomesEqual(genome, g)) genome = g
    hunger = next.hunger
    happiness = next.happiness
    energy = next.energy
    dirty = next.dirty || 0
    sleeping = next.sleeping === true
    shown = next.shown !== false
    applyPen(next.pen)
    confineOutput = next.confineOutput ? String(next.confineOutput) : ""
    if (!root._skipMessApply) replaceMess(next.mess)
    if (!root._skipGraveApply) replaceGraves(next.graves)
    gravesShown = next.gravesShown !== false
    maintenance = next.maintenance !== false
    difficulty = Model.normalizeDifficulty(next.difficulty)
    noDeath = next.noDeath === true
    hungerEmptySince = next.hungerEmptySince || 0
    happyEmptySince = next.happyEmptySince || 0
    bornAt = next.bornAt
    lastTick = next.lastTick
    score = Math.max(0, Math.floor(Number(next.score) || 0))
    scoreAccruedMs = Math.max(0, Number(next.scoreAccruedMs) || 0)
    ownedHats = next.ownedHats || []
    ownedToys = next.ownedToys || []
    ownedGear = next.ownedGear || []
    equippedHat = next.equippedHat || ""
    equippedToy = next.equippedToy || ""
  }

  function persist() {
    if (root._hydrating || !root._loaded) return
    if (stateWrite.running) {
      saveTimer.restart()
      return
    }
    var snap = snapshot()
    delete snap.dropOutput
    var blob = JSON.stringify(snap, null, 2) + "\n"
    if (blob.length > root.stateCap) return
    stateWrite.payload = blob
    stateWrite.stdinEnabled = true
    stateWrite.running = true
  }

  function pinHomelessGraves(output) {
    var where = output ? String(output) : ""
    if (!where || graveItems.count <= 0) return
    var changed = false
    for (var i = 0; i < graveItems.count; i++) {
      if (graveItems.get(i).output) continue
      graveItems.setProperty(i, "output", where)
      changed = true
    }
    if (changed) {
      persist()
      root.bumpGraves()
    }
  }

  function scheduleSave() {
    if (root._hydrating) return
    saveTimer.restart()
  }

  function accrueScore(dt) {
    if (!root.hatched || root.carePaused) return
    var unit = Model.COPPER_ACCRUE_MS
    if (root.noDeath) unit *= Model.COPPER_NODEATH_MULT
    var ms = root.scoreAccruedMs + Math.max(0, dt)
    var n = Math.floor(ms / unit)
    if (n > 0) {
      root.score += n
      ms -= n * unit
    }
    root.scoreAccruedMs = ms
  }

  function tick() {
    var now = Date.now()
    var dt = Math.max(0, Math.min(now - lastTick, 6 * 60 * 60 * 1000))
    var prevGraves = graveItems.count
    root._skipMessApply = true
    root._skipGraveApply = true
    var next = Model.tickState(snapshot(), now, root.walking && root.shown && !root.sleeping && root.scene === "", root.partSet)
    if (next.graves && next.graves.length !== prevGraves) {
      root._skipGraveApply = false
      root._skipMessApply = false
    }
    apply(next)
    root._skipMessApply = false
    root._skipGraveApply = false
    root.accrueScore(dt)
    scheduleSave()
  }

  function cancelHatch() {
    if (hatched) return
    naming = false
  }

  function beginHatch() {
    if (hatched) return
    shown = true
    naming = true
  }

  function hatch(name) {
    if (hatched) return
    naming = false
    apply(Model.hatchPet(snapshot(), name, Date.now(), root.partSet))
    persist()
  }

  function feed() {
    if (!hatched) { beginHatch(); return }
    apply(Model.feed(snapshot(), Date.now(), root.partSet))
    poopBoostUntil = Date.now() + 3 * 60 * 1000
    persist()
  }

  function play() {
    if (!hatched) { beginHatch(); return }
    if (root.carePaused) return
    apply(Model.play(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function pet() {
    if (!hatched) { beginHatch(); return }
    apply(Model.pet(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function toggleSleep() {
    if (!hatched) return
    apply(Model.toggleSleep(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function show() { shown = true; persist() }
  function hide() { shown = false; persist() }
  function toggleShown() { shown = !shown; persist() }

  function startDrawPen(outputName) {
    shown = true
    drawOnOutput = outputName ? String(outputName) : ""
    drawingPen = true
  }

  function cancelDrawPen() {
    drawingPen = false
  }

  function setPen(x, y, w, h, output) {
    applyPen({ x: x, y: y, w: w, h: h, output: output || "" })
    drawingPen = false
    persist()
  }

  function clearPen() {
    applyPen(null)
    penOutput = ""
    drawingPen = false
    persist()
  }

  function setConfineOutput(name) {
    confineOutput = name ? String(name) : ""
    persist()
  }

  function toggleGraves() {
    gravesShown = !gravesShown
    persist()
  }

  function toggleMaintenance() {
    maintenance = !maintenance
    persist()
  }

  function cycleDifficulty(dir) {
    difficulty = Model.cycleDifficulty(difficulty, dir)
    persist()
  }

  function toggleNoDeath() {
    noDeath = !noDeath
    persist()
    if (hatched) tick()
  }

  function reloadShop() {
    catalog.reload()
  }

  function owns(kind, id) {
    var list = kind === "toy" ? ownedToys : kind === "gear" ? ownedGear : ownedHats
    if (!list) return false
    for (var i = 0; i < list.length; i++) {
      if (list[i] === id) return true
    }
    return false
  }

  function gearAutoLabel(auto) {
    return Model.gearAutoLabel(auto)
  }

  function priceLabel(n) {
    return Model.formatCoins(n)
  }

  function buyItem(kind, id) {
    var item = catalog.itemById(kind, id)
    if (!item || !item.id || item.cost <= 0) return false
    if (root.owns(kind, id)) return false
    if (root.score < item.cost) return false
    root.score -= item.cost
    if (kind === "toy") {
      var toys = (ownedToys || []).slice()
      toys.push(item.id)
      ownedToys = toys
    } else if (kind === "gear") {
      var gear = (ownedGear || []).slice()
      gear.push(item.id)
      ownedGear = gear
      if (item.id === "toilet") root.cleanAll()
    } else {
      var hats = (ownedHats || []).slice()
      hats.push(item.id)
      ownedHats = hats
    }
    root.shopRev++
    persist()
    return true
  }

  function cycleEquip(kind, dir) {
    var owned = kind === "toy" ? (ownedToys || []) : (ownedHats || [])
    var ids = [""]
    for (var i = 0; i < owned.length; i++) ids.push(owned[i])
    var cur = kind === "toy" ? equippedToy : equippedHat
    var idx = 0
    for (var j = 0; j < ids.length; j++) {
      if (ids[j] === cur) idx = j
    }
    var step = dir < 0 ? -1 : 1
    idx = (idx + step + ids.length) % ids.length
    if (kind === "toy") equippedToy = ids[idx]
    else equippedHat = ids[idx]
    root.shopRev++
    persist()
  }

  function nibble() {
    if (!hatched || root.carePaused) return
    apply(Model.nibble(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function lullabyNote() {
    if (!hatched || root.carePaused) return
    apply(Model.lullabyNote(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function lullaby() {
    if (!hatched || root.carePaused) return
    apply(Model.lullaby(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function bath() {
    if (!hatched || root.carePaused) return
    apply(Model.bath(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function wash(amount) {
    if (!hatched || root.carePaused) return
    apply(Model.wash(snapshot(), Date.now(), root.partSet, amount))
    persist()
  }

  function scoopNear(px, py, output, size, radius) {
    if (root.carePaused) return false
    var r2 = radius * radius
    var best = -1
    var bestD = r2
    for (var i = 0; i < messItems.count; i++) {
      var m = messItems.get(i)
      var onScreen = m.output ? m.output === output : true
      if (!onScreen) continue
      var dx = px - (m.x + size / 2)
      var dy = py - (m.y + size / 2)
      var d = dx * dx + dy * dy
      if (d <= bestD) {
        bestD = d
        best = i
      }
    }
    if (best < 0) return false
    messItems.remove(best)
    apply(Model.scoopCheer(snapshot(), Date.now(), root.partSet))
    persist()
    return true
  }

  function beginFarm() {
    if (!hatched) return
    shown = true
    farming = true
  }

  function cancelFarm() {
    farming = false
  }

  function finishFarm() {
    if (!hatched) return
    farming = false
    root._skipMessApply = false
    root._skipGraveApply = false
    apply(Model.farmKill(snapshot(), Date.now(), root.partSet))
    persist()
  }

  function countKind(kind) {
    var n = 0
    for (var i = 0; i < messItems.count; i++) {
      if (messItems.get(i).kind === kind) n++
    }
    return n
  }

  function leaveMess(kind) {
    if (root.owns("gear", "toilet")) return
    if (countKind(kind) >= Model.MAX_MESS_EACH) return
    messItems.append({
      kind: kind,
      x: root.dropX + (Math.random() - 0.5) * 28,
      y: root.dropY + 18 + Math.random() * 10,
      bornAt: Date.now(),
      output: root.dropOutput || ""
    })
    persist()
  }

  function scoopOldest() {
    if (root.carePaused) return false
    if (messItems.count <= 0) return false
    var idx = 0
    var oldest = messItems.get(0).bornAt
    for (var i = 1; i < messItems.count; i++) {
      if (messItems.get(i).bornAt < oldest) {
        oldest = messItems.get(i).bornAt
        idx = i
      }
    }
    messItems.remove(idx)
    persist()
    return true
  }

  function cleanAll() {
    if (root.carePaused) return
    if (messItems.count <= 0) return
    messItems.clear()
    persist()
  }

  function expireMess() {
    if (root.carePaused || messItems.count <= 0) return
    var now = Date.now()
    var kept = []
    for (var i = 0; i < messItems.count; i++) {
      var m = messItems.get(i)
      if (now - m.bornAt < Model.MESS_EXPIRE_MS) kept.push({
        kind: m.kind,
        x: m.x,
        y: m.y,
        bornAt: m.bornAt,
        output: m.output || ""
      })
    }
    if (kept.length === messItems.count) return
    messItems.clear()
    for (var j = 0; j < kept.length; j++) messItems.append(kept[j])
    persist()
  }

  function maybeLeaveMess() {
    if (!root.maintenance) return
    if (!root.hatched || !root.shown || root.sleeping || root.scene === "tv") return
    var boosted = Date.now() < root.poopBoostUntil
    var chance = boosted ? 0.006 : 0.0015
    if (Math.random() > chance) return
    root.leaveMess(Math.random() < 0.7 ? "poop" : "pee")
  }

  onHungerChanged: scheduleSave()
  onHappinessChanged: scheduleSave()
  onEnergyChanged: scheduleSave()
  onDirtyChanged: scheduleSave()
  onSleepingChanged: scheduleSave()
  onShownChanged: scheduleSave()
  onHasPenChanged: scheduleSave()
  onPenXChanged: scheduleSave()
  onPenYChanged: scheduleSave()
  onPenWChanged: scheduleSave()
  onPenHChanged: scheduleSave()
  onHatchedChanged: scheduleSave()
  onPetNameChanged: scheduleSave()
  onGravesShownChanged: scheduleSave()
  onMaintenanceChanged: scheduleSave()
  onDifficultyChanged: scheduleSave()
  onNoDeathChanged: scheduleSave()
  onScoreChanged: scheduleSave()
  onEquippedHatChanged: scheduleSave()
  onEquippedToyChanged: scheduleSave()
  onOwnedGearChanged: scheduleSave()

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root.tick()
      root.expireMess()
      root.maybeLeaveMess()
    }
  }

  Timer {
    id: youtubeTimer
    interval: 2500
    repeat: true
    running: true
    onTriggered: {
      if (!youtubeProc.running) youtubeProc.running = true
    }
  }

  Process {
    id: youtubeProc
    command: ["hyprctl", "clients", "-j"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.youtubeWindow = /youtube/i.test(text || "")
    }
  }

  Timer {
    id: saveTimer
    interval: 750
    repeat: false
    onTriggered: root.persist()
  }

  ShopCatalog {
    id: catalog
    home: root.home
  }

  PartsCatalog {
    id: partsCatalog
    home: root.home
    onPartSetChanged: {
      if (root._hydrating || !root._loaded || !root.hatched) return
      var g = Model.normalizeGenome(root.genome, root.partSet)
      if (!Model.genomesEqual(root.genome, g)) root.genome = g
    }
  }

  function ingestState(code, raw) {
    if (root._loaded) return
    root._hydrating = true
    var next = null
    if (code === 0) {
      try {
        next = Model.normalizeState(JSON.parse(raw || "{}"), Date.now(), root.partSet)
      } catch (e) {
        next = Model.defaultState(Date.now())
      }
    } else {
      next = Model.defaultState(Date.now())
    }
    root.apply(next)
    root._loaded = true
    root._hydrating = false
    if (code === 2) root.persist()
    else root.tick()
  }

  Process {
    id: stateRead
    running: !!root.home && !!root.stateHelper
    command: ["python3", root.stateHelper, "read", root.statePath, String(root.stateCap)]
    stdout: StdioCollector {
      id: stateReadOut
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.ingestState(exitCode, stateReadOut.text)
    }
  }

  Process {
    id: stateWrite
    property string payload: ""
    stdinEnabled: true
    command: ["python3", root.stateHelper, "write", root.statePath, String(root.stateCap)]
    onStarted: {
      write(payload)
      stdinEnabled = false
    }
    onExited: stdinEnabled = true
  }

  IpcHandler {
    target: "io.github.nerddotdad.tamomarchy"

    function feed(): string { root.feed(); return "ok" }
    function play(): string { root.play(); return "ok" }
    function pet(): string { root.pet(); return "ok" }
    function sleep(): string { root.toggleSleep(); return "ok" }
    function show(): string { root.show(); return "ok" }
    function hide(): string { root.hide(); return "ok" }
    function toggle(): string { root.toggleShown(); return "ok" }
    function yard(): string { root.startDrawPen(); return "ok" }
    function wander(): string { root.clearPen(); return "ok" }
    function scoop(): string { return root.scoopOldest() ? "ok" : "empty" }
    function clean(): string { root.cleanAll(); return "ok" }
    function hatch(name: string): string { root.hatch(name); return root.petName }
    function farm(): string { root.beginFarm(); return "ok" }
    function die(): string {
      root._skipMessApply = false
      root._skipGraveApply = false
      root.apply(Model.killPet(root.snapshot(), Date.now(), "starved", root.partSet))
      root.persist()
      return root.petName
    }
    function state(): string { return JSON.stringify(root.snapshot()) }
  }
}
