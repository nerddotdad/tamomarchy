import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "Model.js" as Model


// Persistent pet: hunger, mood, energy, and whether the overlay is showing.
// Overlay and bar widget both read this singleton.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string statePath: home + "/.local/state/omarchy/tamagotchi.json"

  property string petName: ""
  property bool hatched: false
  property bool naming: false
  property var genome: null
  property real hunger: 100
  property real happiness: 100
  property real energy: 100
  property bool sleeping: false
  property bool shown: true
  property bool drawingPen: false
  property bool hasPen: false
  property real penX: 0
  property real penY: 0
  property real penW: 0
  property real penH: 0
  property string penOutput: ""
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
  property bool maintenance: true
  property bool farming: false

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
  readonly property int messCount: messItems.count
  readonly property int graveCount: graveItems.count

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

  function replaceGraves(list) {
    graveItems.clear()
    var next = Model.normalizeGraves(list)
    for (var i = 0; i < next.length; i++) {
      var g = next[i]
      graveItems.append({
        name: g.name,
        genomeJson: JSON.stringify(g.genome || {}),
        bornAt: g.bornAt,
        diedAt: g.diedAt,
        cause: g.cause
      })
    }
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
        cause: row.cause
      })
    }
    return out
  }

  function parseGenomeJson(text) {
    try {
      var g = JSON.parse(text || "{}")
      return Model.normalizeGenome(g)
    } catch (e) {
      return Model.normalizeGenome(null)
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
      sleeping: sleeping,
      shown: shown,
      pen: hasPen ? { x: penX, y: penY, w: penW, h: penH, output: penOutput } : null,
      mess: messSnapshot(),
      graves: graveSnapshot(),
      gravesShown: gravesShown,
      maintenance: maintenance,
      hungerEmptySince: hungerEmptySince,
      happyEmptySince: happyEmptySince,
      bornAt: bornAt,
      lastTick: lastTick
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
    var g = hatched ? Model.normalizeGenome(next.genome) : null
    if (!Model.genomesEqual(genome, g)) genome = g
    hunger = next.hunger
    happiness = next.happiness
    energy = next.energy
    sleeping = next.sleeping === true
    shown = next.shown !== false
    applyPen(next.pen)
    if (!root._skipMessApply) replaceMess(next.mess)
    if (!root._skipGraveApply) replaceGraves(next.graves)
    gravesShown = next.gravesShown !== false
    maintenance = next.maintenance !== false
    hungerEmptySince = next.hungerEmptySince || 0
    happyEmptySince = next.happyEmptySince || 0
    bornAt = next.bornAt
    lastTick = next.lastTick
  }

  function persist() {
    if (root._hydrating || !root._loaded) return
    stateFile.setText(JSON.stringify(snapshot(), null, 2) + "\n")
  }

  function scheduleSave() {
    if (root._hydrating) return
    saveTimer.restart()
  }

  function tick() {
    var prevGraves = graveItems.count
    root._skipMessApply = true
    root._skipGraveApply = true
    var next = Model.tickState(snapshot(), Date.now(), root.walking && root.shown && !root.sleeping && root.scene === "")
    if (next.graves && next.graves.length !== prevGraves) {
      root._skipGraveApply = false
      root._skipMessApply = false
    }
    apply(next)
    root._skipMessApply = false
    root._skipGraveApply = false
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
    apply(Model.hatchPet(snapshot(), name, Date.now()))
    persist()
  }

  function feed() {
    if (!hatched) { beginHatch(); return }
    apply(Model.feed(snapshot(), Date.now()))
    poopBoostUntil = Date.now() + 3 * 60 * 1000
    persist()
  }

  function play() {
    if (!hatched) { beginHatch(); return }
    apply(Model.play(snapshot(), Date.now()))
    persist()
  }

  function pet() {
    if (!hatched) { beginHatch(); return }
    apply(Model.pet(snapshot(), Date.now()))
    persist()
  }

  function toggleSleep() {
    if (!hatched) return
    apply(Model.toggleSleep(snapshot(), Date.now()))
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

  function toggleGraves() {
    gravesShown = !gravesShown
    persist()
  }

  function toggleMaintenance() {
    if (!maintenance) {
      maintenance = true
      persist()
      return
    }
    maintenance = false
    hunger = 100
    happiness = 100
    energy = 100
    sleeping = false
    hungerEmptySince = 0
    happyEmptySince = 0
    cleanAll()
    persist()
  }

  function nibble() {
    if (!hatched) return
    apply(Model.nibble(snapshot(), Date.now()))
    persist()
  }

  function lullaby() {
    if (!hatched) return
    apply(Model.lullaby(snapshot(), Date.now()))
    persist()
  }

  function bath() {
    if (!hatched) return
    cleanAll()
    apply(Model.bath(snapshot(), Date.now()))
    persist()
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
    apply(Model.farmKill(snapshot(), Date.now()))
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
    if (countKind(kind) >= 10) return
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
    if (messItems.count <= 0) return
    messItems.clear()
    persist()
  }

  function maybeLeaveMess() {
    if (!root.maintenance) return
    if (!root.hatched || !root.shown || root.sleeping || root.scene === "tv") return
    var boosted = Date.now() < root.poopBoostUntil
    var chance = boosted ? 0.028 : 0.007
    if (Math.random() > chance) return
    root.leaveMess(Math.random() < 0.7 ? "poop" : "pee")
  }

  onHungerChanged: scheduleSave()
  onHappinessChanged: scheduleSave()
  onEnergyChanged: scheduleSave()
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

  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      root.tick()
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

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root._hydrating = true
      try {
        root.apply(Model.normalizeState(JSON.parse(text() || "{}"), Date.now()))
      } catch (e) {
        root.apply(Model.defaultState(Date.now()))
      }
      root._loaded = true
      root._hydrating = false
      root.tick()
    }
    onLoadFailed: {
      root._hydrating = true
      root.apply(Model.defaultState(Date.now()))
      root._loaded = true
      root._hydrating = false
      root.persist()
    }
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
      var snap = root.snapshot()
      snap.hunger = 0
      snap.hungerEmptySince = Date.now() - (12 * 60 * 1000 + 5000)
      root._skipMessApply = false
      root._skipGraveApply = false
      root.apply(Model.tickState(snap, Date.now(), false))
      root.persist()
      return root.petName
    }
    function state(): string { return JSON.stringify(root.snapshot()) }
  }
}
