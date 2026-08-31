import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "../Model.js" as Model

PanelWindow {
  id: panel

  required property var modelData
  property var host: null

  readonly property var screenObj: modelData
  readonly property string screenName: screenObj ? String(screenObj.name) : ""
  readonly property real originX: screenObj ? Number(screenObj.x) : 0
  readonly property real originY: screenObj ? Number(screenObj.y) : 0
  readonly property real localPetX: host ? host.petX - originX : 0
  readonly property real localPetY: host ? host.petY - originY : 0
  readonly property bool petHere: {
    if (!host || !host.opened) return false
    return localPetX < width && localPetX + host.spriteW > 0 && localPetY < height && localPetY + host.spriteH > 0
  }
  readonly property int bubbleGap: 8
  readonly property bool bubbleOnLeft: {
    if (!host) return false
    var w = bubble.width
    var left = panel.localPetX - w - panel.bubbleGap
    var right = panel.localPetX + host.spriteW + panel.bubbleGap + w
    if (host.facingLeft) {
      if (left >= 0) return true
      if (right <= panel.width) return false
      return true
    }
    if (right <= panel.width) return false
    if (left >= 0) return true
    return false
  }
  readonly property bool isGameScreen: host && (host.gameSpansScreens || host.gameOutput === screenName)
  readonly property bool scoopHere: {
    if (!host || host.game !== "scoop" || host.lastScoopX < 0) return false
    var lx = host.lastScoopX - originX
    var ly = host.lastScoopY - originY
    return lx > -56 && lx < width + 56 && ly > -56 && ly < height + 56
  }
  readonly property bool isDrawScreen: host && host.pet && host.pet.drawOnOutput === screenName
  readonly property bool takeKeys: host && ((host.drawing && isDrawScreen) || (host.naming && petHere) || (host.inGame && isGameScreen))

  screen: modelData
  visible: host && host.opened && !remapGuard.remapping
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }

  ScreenMoveRemap {
    id: remapGuard
    window: panel
  }

  WlrLayershell.namespace: "tamomarchy"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: takeKeys ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore

  mask: Region {
    id: inputMask
    item: {
      if (!host || !host.opened) return null
      if (host.drawing && isDrawScreen) return drawCatcher
      if (host.naming && petHere) return hatchCatcher
      if (host.inGame && isGameScreen) return gameCatcher
      if (host.holding || host.waitMouseUp) return petPointer
      if (petHere) return hitArea
      return null
    }
  }

  Timer {
    interval: 16
    repeat: true
    running: host && (host.opened || host.holding || host.inGame)
    onTriggered: inputMask.changed()
  }

  Repeater {
    model: host && host.pet ? host.pet.ownedGearItems : 0

    Item {
      required property var modelData
      required property int index
      visible: panel.petHere && host && host.opened && !host.inGame && !host.holding
      width: gearSprite.implicitWidth
      height: gearSprite.implicitHeight
      x: host.barClearance("left") + 10 + index * 50
      y: panel.height - host.barClearance("bottom") - (host ? (host.graveRev, host.graveyardHFor(panel.screenName)) : 0) - height - 10
      z: 3

      PetSprite {
        id: gearSprite
        itemOnly: true
        hatched: true
        shopGear: modelData
        shopFrame: host ? host.shopFrame : 0
        pixelSize: 4
        bodyColor: Color.accent
      }
    }
  }

  Repeater {
    model: host && host.pet ? host.pet.messModel : 0

    MessSprite {
      visible: host && host.messOnScreen(model.output, panel.screenName)
      kind: model.kind
      x: model.x
      y: model.y
      z: 4
    }
  }

  Rectangle {
    visible: panel.petHere && host.watching
    x: panel.localPetX - 10
    y: panel.localPetY + host.spriteH - 12
    width: host.spriteW + 20
    height: 16
    radius: 6
    z: 6
    color: Qt.darker(Color.accent, 1.85)
  }

  Rectangle {
    visible: panel.petHere && host.watching
    x: host.facingLeft ? panel.localPetX - 36 : panel.localPetX + host.spriteW + 6
    y: panel.localPetY + 10
    width: 30
    height: 24
    radius: 3
    z: 6
    color: Qt.rgba(0.12, 0.12, 0.14, 0.95)

    Rectangle {
      anchors.centerIn: parent
      width: 22
      height: 14
      color: Qt.hsva((host.nowMs / 1800) % 1, 0.45, 0.75, 1)
    }
  }

  Rectangle {
    visible: host && host.opened && (host.holding || (host.inGame && panel.isGameScreen))
    anchors.fill: parent
    z: 8
    color: Qt.rgba(0, 0, 0, host.inGame ? 0.38 : 0.22)
  }

  Item {
    id: holdMenu
    visible: host && host.holding && host.pet && host.pet.hatched && !host.inGame && panel.screenName === host.menuOutput
    x: host.menuX
    y: host.menuY
    width: menuCol.implicitWidth
    height: menuCol.implicitHeight
    z: 50

    Text {
      visible: host.pet && (host.pet.carePaused || host.pet.crisisSleep)
      anchors.horizontalCenter: menuCol.horizontalCenter
      anchors.bottom: menuCol.top
      anchors.bottomMargin: 6
      width: menuCol.implicitWidth
      text: host.pet && host.pet.crisisSleep ? "Sleeping it off. Feed or play to wake." : "Stats paused. Re-enable in the panel."
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      id: menuCol
      spacing: 8

      Row {
        id: menuRow
        spacing: 4

        ActionIcon { glyph: "\uf236"; label: "Sleep"; lit: host.hoverAction === "sleep" }
        ActionIcon { glyph: "\uf0f5"; label: "Eat"; lit: host.hoverAction === "eat" }
        ActionIcon { glyph: "\uf1e3"; label: "Play"; lit: host.hoverAction === "play" }
        ActionIcon { glyph: "\uf2cd"; label: "Bath"; lit: host.hoverAction === "bath" }
        ActionIcon { glyph: "\uf51a"; label: "Scoop"; lit: host.hoverAction === "scoop" }
        ActionIcon { glyph: "\uee15"; label: "Kill"; lit: host.hoverAction === "farm" }
      }

      StatMeters {
        width: menuRow.implicitWidth
        pet: host.pet
        focusStat: host.hoverFocusStat
      }

      Text {
        width: menuRow.implicitWidth
        height: 32
        text: host.hoverImpact
        color: Color.accent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        opacity: host.hoverImpact !== "" ? 1 : 0
      }
    }
  }

  Item {
    id: gameHud
    visible: host && host.inGame && panel.isGameScreen
    anchors.fill: parent
    z: 60

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: host.barClearance("top") + 8
      width: Math.min(420, parent.width * 0.5)
      height: 18
      radius: 9
      color: Qt.rgba(0, 0, 0, 0.45)

      Rectangle {
        width: Math.round(parent.width * Math.max(0, Math.min(1, host.gameProgress)))
        height: parent.height
        radius: parent.radius
        color: Color.accent
      }
    }

    Text {
      visible: host.game !== "sleep"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: host.barClearance("top") + 32
      text: host.game === "eat" ? "Catch the falling food"
        : host.game === "play" ? (host.ballLive ? "Fetch!" : "Click to throw")
        : host.game === "bath" ? (host.brushHeld ? "Scrub him" : "Pick up the soap")
        : host.game === "scoop" ? (host.scoopHeld ? "Move over mess — click to put down" : "Pick up the scooper")
        : "Drag him up and down the grater"
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }

    StatMeters {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: host.barClearance("top") + (host.game === "sleep" ? 32 : 58)
      width: Math.min(420, parent.width * 0.55)
      pet: host.pet
      focusStat: host.game === "eat" ? "hunger"
        : host.game === "play" ? "mood"
        : host.game === "bath" ? "dirty"
        : host.game === "sleep" ? "energy"
        : host.game === "scoop" ? "potty"
        : ""
    }

    Repeater {
      model: host ? host.foodModel : 0
      Item {
        x: model.fx
        y: model.fy
        width: host.foodSize
        height: host.foodSize
        z: 61
        rotation: model.spin

        ThemeSvg {
          anchors.fill: parent
          source: model.kind === "pizza" ? Qt.resolvedUrl("../icons/pizza.svg") : Qt.resolvedUrl("../icons/burger.svg")
          sourceSize.width: host.foodSize * 2
          sourceSize.height: host.foodSize * 2
          tint: Color.foreground
        }
      }
    }

    Rectangle {
      visible: host.game === "play" && host.ballLive
      x: host.ballX
      y: host.ballY
      width: host.ballSize
      height: host.ballSize
      radius: host.ballSize / 2
      color: Color.accent
      border.width: 2
      border.color: Color.foreground
      z: 62
    }

    Item {
      visible: host.game === "bath" && host.lastBrushX >= 0
      width: 56
      height: 56
      x: host.lastBrushX - width / 2
      y: host.lastBrushY - height / 2
      z: 63
      rotation: host.brushHeld ? -12 : 0
      scale: host.brushHeld ? 1.08 : (1 + 0.07 * Math.sin(host.nowMs / 200))

      Rectangle {
        visible: !host.brushHeld
        anchors.centerIn: parent
        width: 54
        height: 54
        radius: 27
        color: Color.popups.background
        border.width: 2
        border.color: Color.accent
      }

      ThemeSvg {
        anchors.centerIn: parent
        width: 34
        height: 34
        source: Qt.resolvedUrl("../icons/soap.svg")
        sourceSize.width: 68
        sourceSize.height: 68
        tint: Color.foreground
      }
    }

    Item {
      visible: panel.scoopHere
      width: 56
      height: 56
      x: host.lastScoopX - panel.originX - width / 2
      y: host.lastScoopY - panel.originY - height / 2
      z: 63
      rotation: host.scoopHeld ? -18 : 0
      scale: host.scoopHeld ? 1.08 : (1 + 0.07 * Math.sin(host.nowMs / 200))

      Rectangle {
        visible: !host.scoopHeld
        anchors.centerIn: parent
        width: 54
        height: 54
        radius: 27
        color: Color.popups.background
        border.width: 2
        border.color: Color.accent
      }

      ThemeSvg {
        anchors.centerIn: parent
        width: 34
        height: 34
        source: Qt.resolvedUrl("../icons/scoop.svg")
        sourceSize.width: 68
        sourceSize.height: 68
        tint: Color.foreground
      }
    }

    MouseArea {
      id: gameCatcher
      anchors.fill: parent
      enabled: host && host.inGame && panel.isGameScreen
      hoverEnabled: true
      preventStealing: true
      focus: host && host.inGame && panel.isGameScreen
      cursorShape: {
        if (!host) return Qt.ArrowCursor
        if (host.game === "play") return Qt.PointingHandCursor
        if (host.game === "sleep") return Qt.ArrowCursor
        if (host.game === "bath") {
          if (host.brushHeld) return Qt.ClosedHandCursor
          if (containsMouse && host.nearBrush(mouseX, mouseY)) return Qt.OpenHandCursor
          return Qt.ArrowCursor
        }
        if (host.game === "scoop") {
          if (host.scoopHeld) return Qt.ClosedHandCursor
          if (containsMouse && host.nearScoop(panel.originX + mouseX, panel.originY + mouseY)) return Qt.OpenHandCursor
          return Qt.ArrowCursor
        }
        return Qt.ClosedHandCursor
      }
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          host.endGame(false)
          return
        }
        if (host.game === "play") {
          host.throwBall(mouse.x, mouse.y)
          return
        }
        if (host.game === "sleep") return
        if (host.game === "bath") {
          if (host.nearBrush(mouse.x, mouse.y) && !host.brushHeld) {
            host.brushHeld = true
            host.playSoapPickup()
          }
          if (host.brushHeld)
            host.scrubAt(mouse.x, mouse.y)
          return
        }
        if (host.game === "scoop") {
          if (host.scoopHeld) {
            host.scoopAt(panel.originX + mouse.x, panel.originY + mouse.y)
            host.scoopHeld = false
            return
          }
          if (host.nearScoop(panel.originX + mouse.x, panel.originY + mouse.y)) {
            host.scoopHeld = true
            host.playSoapPickup()
            host.scoopAt(panel.originX + mouse.x, panel.originY + mouse.y)
          }
          return
        }
        host.grabOffX = mouse.x - panel.localPetX
        host.grabOffY = mouse.y - panel.localPetY
        host.holding = true
      }
      onEntered: {
        if (host.game === "scoop" && host.scoopHeld)
          host.scoopAt(panel.originX + mouseX, panel.originY + mouseY)
      }
      onPositionChanged: function(mouse) {
        if (host.game === "scoop" && host.scoopHeld) {
          host.scoopAt(panel.originX + mouse.x, panel.originY + mouse.y)
          return
        }
        if (!pressed && !host.holding && !host.brushHeld) return
        if (host.game === "eat" || host.game === "farm")
          host.putPet(panel.originX + mouse.x - host.grabOffX, panel.originY + mouse.y - host.grabOffY)
        if (host.game === "farm") panel.grateAt()
        if (host.game === "bath" && host.brushHeld) host.scrubAt(mouse.x, mouse.y)
      }
      onReleased: function(mouse) {
        if (mouse.button !== Qt.LeftButton) return
        if (host.game === "bath") {
          host.brushHeld = false
          return
        }
        if (host.game === "scoop")
          return
        if (host.game !== "play")
          host.holding = false
      }
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          host.endGame(false)
          event.accepted = true
          return
        }
        if (host.game === "sleep") {
          host.handleLullabyKey(event)
          event.accepted = true
        }
      }
    }

    Lullaby {
      visible: host.game === "sleep"
      z: 80
      nextKey: host.lullabyKeys[host.lullabyHits] || ""
      hits: host.lullabyHits
      keys: host.lullabyKeys
      x: {
        var right = panel.localPetX + host.spriteW + 16
        var left = panel.localPetX - width - 16
        if (right + width <= panel.width - host.barClearance("right")) return right
        return Math.max(host.barClearance("left"), left)
      }
      y: {
        var mid = panel.localPetY + host.spriteH / 2 - height / 2
        var minY = host.barClearance("top")
        var maxY = panel.height - height - host.barClearance("bottom")
        return Math.min(maxY, Math.max(minY, mid))
      }
      onTapped: function(letter) { host.pressLullaby(letter) }
    }
  }

  Grater {
    id: grater
    visible: host && host.game === "farm" && panel.isGameScreen
    z: 25
    anchors.centerIn: parent
    petName: host && host.pet && host.pet.petName ? host.pet.petName : "them"
    pulse: host ? host.nowMs / 220 : 0
  }

  Repeater {
    model: host ? host.shredModel : 0
    Rectangle {
      x: model.sx
      y: model.sy
      width: model.ssize
      height: model.ssize
      color: model.sdark ? Qt.darker(Color.accent, 1.4) : Color.accent
      z: 48
    }
  }

  Item {
    id: hitArea
    visible: panel.petHere
    x: Math.round(panel.localPetX)
    y: Math.round(panel.localPetY - host.bounceY - sprite.hatLift)
    width: host.spriteW
    height: host.spriteH + sprite.hatLift
    opacity: host && host.opened ? 1 : 0
    z: host && host.inGame ? 40 : 100

    Rectangle {
      width: host.spriteW * 0.55
      height: 7
      radius: 4
      anchors.horizontalCenter: sprite.horizontalCenter
      anchors.bottom: sprite.bottom
      anchors.bottomMargin: -1
      color: Qt.rgba(0, 0, 0, 0.22)
    }

    PetSprite {
      id: sprite
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      pixelSize: host.spriteScale
      pose: host.pose
      frame: host.walkFrame
      facingLeft: host.facingLeft
      rotation: host.petRot
      transformOrigin: Item.Center
      hatched: host.pet ? host.pet.hatched : false
      genome: host.pet ? host.pet.genome : null
      shopHat: host.pet ? host.pet.hatItem : null
      shopToy: null
      parts: host.pet ? host.pet.partSet : null
      shopFrame: host.shopFrame
      dirty: host.pet ? host.pet.dirty : 0
      bodyColor: Color.accent
    }
  }

  Rectangle {
    id: bubble
    visible: panel.petHere && host && host.pet && host.pet.speech !== "" && !host.moving
    x: panel.bubbleOnLeft
      ? Math.round(panel.localPetX - width - panel.bubbleGap)
      : Math.round(panel.localPetX + host.spriteW + panel.bubbleGap)
    y: Math.round(panel.localPetY - host.bounceY + host.spriteH * 0.12 - height / 2)
    width: bubbleText.implicitWidth + Style.space(12)
    height: visible ? bubbleText.implicitHeight + Style.space(8) : 0
    radius: Style.cornerRadius
    z: 101
    color: Color.popups.background
    border.width: Style.spacing.hairline
    border.color: Color.popups.border

    Text {
      id: bubbleText
      anchors.centerIn: parent
      text: host && host.pet ? host.pet.speech : ""
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  PetSprite {
    id: toySprite
    visible: panel.petHere && host && host.toyVisible
    x: panel.localPetX + host.toyDrawX
    y: panel.localPetY - host.bounceY + host.toyDrawY
    z: 102
    pixelSize: host.spriteScale
    facingLeft: host.toyFacingLeft
    rotation: host.toyRot
    scale: host.toyScale
    transformOrigin: Item.Center
    hatched: true
    itemOnly: true
    shopToy: host.pet ? host.pet.toyItem : null
    shopFrame: host.shopFrame
    bodyColor: Color.accent
  }

  MouseArea {
    id: petPointer
    anchors.fill: parent
    z: 110
    enabled: host && host.opened && !host.drawing && !host.inGame && !host.naming && !host.waitMouseUp && (panel.petHere || host.holding)
    hoverEnabled: true
    preventStealing: true
    cursorShape: host && host.holding ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onPressed: function(mouse) {
      if (mouse.button === Qt.RightButton) {
        if (host.pet && host.pet.hatched && !host.holding) host.pet.toggleSleep()
        return
      }
      host.grabPet(panel.originX + mouse.x, panel.originY + mouse.y)
    }
    onPositionChanged: function(mouse) {
      if (!pressed && !host.holding) return
      host.moveHeldPet(panel.originX + mouse.x, panel.originY + mouse.y)
    }
    onReleased: function(mouse) {
      if (mouse.button === Qt.LeftButton)
        host.dropPet()
    }
    onCanceled: {}
  }

  MouseArea {
    anchors.fill: parent
    z: 112
    enabled: host && host.waitMouseUp && panel.petHere
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onReleased: host.waitMouseUp = false
  }

  Item {
    id: graveyard
    visible: host && host.showGraves && (host.graveRev, host.gravesOnScreen(panel.screenName))
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: host.barClearance("bottom")
    height: visible ? host.graveyardSize : 0
    z: 5

    Repeater {
      model: host && host.pet ? host.pet.graveModel : 0

      GraveSprite {
        readonly property int slot: host ? host.graveSlot(index, panel.screenName) : index
        visible: host && host.graveOnScreen(model.output, panel.screenName)
        petName: model.name
        cause: model.cause
        bornAt: model.bornAt
        diedAt: model.diedAt
        pixelSize: 4
        graveIndex: index
        tilt: Model.graveTilt(index, model.diedAt)
        lean: Model.graveLean(index)
        x: Model.graveX(slot, graveyard.width)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Model.graveLift(index) + Model.graveRow(slot, graveyard.width) * 22
        z: slot + 1
      }
    }
  }

  Repeater {
    model: host ? host.heartModel : 0
    Text {
      required property real hx
      required property real hy
      required property double born
      visible: hx >= panel.originX - 20 && hx <= panel.originX + panel.width + 20
      text: "♥"
      color: Color.accent
      font.pixelSize: Style.font.body
      opacity: Math.max(0, 1 - (host.nowMs - born) / 900)
      x: hx - panel.originX - 6
      y: hy - panel.originY - ((host.nowMs - born) / 900) * 28
      z: 20
    }
  }

  Repeater {
    model: host ? host.noteModel : 0
    Text {
      required property real nx
      required property real ny
      required property double born
      visible: nx >= panel.originX - 20 && nx <= panel.originX + panel.width + 20
      text: Math.floor((host.nowMs + born) / 400) % 2 === 0 ? "♪" : "♫"
      color: Color.accent
      font.pixelSize: Style.font.caption
      opacity: Math.max(0, 1 - (host.nowMs - born) / 1100)
      x: nx - panel.originX
      y: ny - panel.originY - ((host.nowMs - born) / 1100) * 36
      z: 21
    }
  }

  Item {
    id: hatchCatcher
    visible: host && host.naming && panel.petHere
    anchors.fill: parent
    z: 200
    focus: visible

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          host.cancelOverlayHatch()
          return
        }
        var p = hatchCard.mapFromItem(hatchCatcher, mouse.x, mouse.y)
        if (p.x < 0 || p.y < 0 || p.x > hatchCard.width || p.y > hatchCard.height)
          host.cancelOverlayHatch()
      }
    }

    Rectangle {
      id: hatchCard
      width: 236
      height: hatchCol.implicitHeight + Style.space(24)
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: Style.spacing.hairline
      border.color: Color.popups.border
      x: {
        var cx = panel.localPetX + host.spriteW / 2
        var minX = host.barClearance("left") + 8
        var maxX = panel.width - width - host.barClearance("right") - 8
        return Math.round(Math.min(Math.max(cx - width / 2, minX), Math.max(minX, maxX)))
      }
      y: {
        var gap = 10
        var above = panel.localPetY - height - gap
        var below = panel.localPetY + host.spriteH + gap
        var minY = host.barClearance("top") + 8
        var maxY = panel.height - height - host.barClearance("bottom") - 8
        if (above >= minY) return Math.round(above)
        return Math.round(Math.min(maxY, Math.max(minY, below)))
      }

      Column {
        id: hatchCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Style.space(12)
        spacing: Style.space(8)

        Text {
          width: parent.width
          text: "Name your tamOmarchy"
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        TextField {
          id: overlayNameField
          width: parent.width
          placeholderText: "Mochi"
          foreground: Color.foreground
          maximumLength: 18
          onAccepted: host.confirmOverlayHatch(text)
          Keys.onEscapePressed: function(event) {
            host.cancelOverlayHatch()
            event.accepted = true
          }
        }

        Button {
          width: parent.width
          text: "Hatch"
          bordered: true
          foreground: Color.foreground
          onClicked: host.confirmOverlayHatch(overlayNameField.text)
        }
      }
    }

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        host.cancelOverlayHatch()
        event.accepted = true
      }
    }

    Connections {
      target: host
      function onNamingChanged() {
        if (!host.naming || !panel.petHere) return
        overlayNameField.text = ""
        Qt.callLater(function() { overlayNameField.forceActiveFocus() })
      }
    }
  }

  Rectangle {
    id: drawCatcher
    visible: host && host.drawing && panel.isDrawScreen
    anchors.fill: parent
    z: 200
    color: Qt.rgba(0, 0, 0, 0.45)
    focus: visible

    Rectangle {
      visible: host.dragging
      x: Math.min(host.dragStartX, host.dragX)
      y: Math.min(host.dragStartY, host.dragY)
      width: Math.abs(host.dragX - host.dragStartX)
      height: Math.abs(host.dragY - host.dragStartY)
      radius: Style.cornerRadius
      color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
      border.width: 2
      border.color: Color.accent
    }

    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.space(64)
      spacing: Style.space(8)

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Drag a box for Mochi"
        color: Color.foreground
        font.family: Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Right-click or Escape to cancel"
        color: Qt.darker(Color.foreground, 1.4)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.CrossCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          host.cancelPenDraw()
          return
        }
        host.beginPenDrag(mouse.x, mouse.y)
      }
      onPositionChanged: function(mouse) {
        host.updatePenDrag(mouse.x, mouse.y)
      }
      onReleased: function(mouse) {
        if (mouse.button === Qt.LeftButton)
          host.endPenDrag(mouse.x, mouse.y, panel.screenName)
      }
    }

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        host.cancelPenDraw()
        event.accepted = true
      }
    }
  }

  function grateAt() {
    if (!host || !grater.visible) return
    var gx = grater.x + grater.surfaceX
    var gy = grater.y + grater.surfaceY
    var lx = panel.localPetX
    var ly = panel.localPetY
    var over = lx + host.spriteW > gx && lx < gx + grater.surfaceW && ly + host.spriteH > gy && ly < gy + grater.surfaceH
    if (over && host.lastGrateY >= 0) {
      var dy = Math.abs(ly - host.lastGrateY)
      if (dy > 1.2) {
        host.grateTravel += dy
        host.spawnShredsAt(gx, gy + grater.surfaceH - 2, grater.surfaceW, Math.min(10, 1 + Math.floor(dy / 5)))
        host.playGrateSfx()
        if (host.grateTravel >= host.grateNeed) host.endGame(true)
      }
    }
    host.lastGrateX = lx
    host.lastGrateY = ly
  }

  Connections {
    target: host
    function onDrawingChanged() {
      if (host.drawing && panel.isDrawScreen)
        Qt.callLater(function() { if (drawCatcher) drawCatcher.forceActiveFocus() })
    }
    function onGameChanged() {
      if (host.game === "sleep" && panel.isGameScreen)
        Qt.callLater(function() { if (gameCatcher) gameCatcher.forceActiveFocus() })
    }
  }
}
