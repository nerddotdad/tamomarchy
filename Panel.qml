import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "components"

Panel {
  id: root
  moduleName: "io.github.nerddotdad.tamomarchy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var pet: null
  property string view: "care"
  property string shopTab: "hats"
  readonly property var livePet: pet || (bar && bar.shell ? bar.shell.serviceFor("io.github.nerddotdad.tamomarchy") : null)
  readonly property bool isEgg: livePet ? livePet.hatched === false : true
  readonly property bool inShop: view === "shop"
  readonly property int points: livePet ? livePet.score : 0
  readonly property string hatLabel: {
    var p = root.livePet
    if (!p || !p.equippedHat) return "No hat"
    return (p.hatItem && p.hatItem.name) ? p.hatItem.name : "No hat"
  }
  readonly property string toyLabel: {
    var p = root.livePet
    if (!p || !p.equippedToy) return "No toy"
    return (p.toyItem && p.toyItem.name) ? p.toyItem.name : "No toy"
  }
  readonly property int shopRev: livePet ? livePet.shopRev : 0
  readonly property var shopItems: {
    if (!root.livePet) return []
    if (root.shopTab === "toys") return root.livePet.shopToys || []
    if (root.shopTab === "gear") return root.livePet.shopGear || []
    return root.livePet.shopHats || []
  }
  readonly property var displayOptions: {
    var opts = [{ value: "", label: "Any display" }]
    var screens = Quickshell.screens
    var n = screens ? screens.length : 0
    for (var i = 0; i < n; i++) {
      var s = screens[i]
      if (!s || !s.name) continue
      var w = Math.round(s.width)
      var h = Math.round(s.height)
      opts.push({ value: String(s.name), label: s.name + " · " + w + "×" + h })
    }
    return opts
  }

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
    root.view = "care"
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function startScreenDraw() {
    if (!root.livePet) return
    playpenStart.outputName = panel.screen ? panel.screen.name : ""
    root.close()
    playpenStart.restart()
  }

  function openShop() {
    root.shopTab = "hats"
    root.view = "shop"
    if (root.livePet) root.livePet.reloadShop()
  }

  function shopOwned(item) {
    return !!(root.livePet && item && root.livePet.owns(item.kind, item.id))
  }

  function shopCanBuy(item) {
    if (!root.livePet || !item || !(item.cost > 0)) return false
    if (root.shopOwned(item)) return false
    return root.livePet.score >= item.cost
  }

  function shopButtonLabel(item) {
    if (root.shopOwned(item)) return "Owned"
    if (!item || !(item.cost > 0)) return "Buy"
    if (!root.livePet || root.livePet.score < item.cost) return "Need more"
    return "Buy"
  }

  Timer {
    id: playpenStart
    interval: 280
    repeat: false
    property string outputName: ""
    onTriggered: if (root.livePet) root.livePet.startDrawPen(outputName)
  }

  function confirmHatch() {
    if (!root.livePet || root.livePet.hatched) return
    root.livePet.hatch(nameField.text)
  }

  function meterColor(value, invert) {
    if (invert) {
      if (value > 75) return Color.urgent
      return Style.selectedStateColor(root.contentForeground, Color.accent)
    }
    if (value < 25) return Color.urgent
    return Style.selectedStateColor(root.contentForeground, Color.accent)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    onOpenChanged: {
      if (!open) root.view = "care"
      if (open && root.isEgg)
        Qt.callLater(function() { nameField.forceActiveFocus() })
    }
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(root.inShop ? 380 : 320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: nameField.activeFocus || displayPick.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (!root.livePet || root.isEgg) return
        if (t === "y" || t === "Y") root.startScreenDraw()
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: content
          width: panelScroll.width
          spacing: Style.space(12)

          Column {
            width: parent.width
            spacing: Style.space(2)

            Text {
              text: root.inShop ? "Shop" : (root.isEgg ? "An egg" : (root.livePet ? root.livePet.petName : "tamOmarchy"))
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              CoinAmount {
                id: walletCoins
                visible: !!root.livePet
                copper: root.points
                foreground: Qt.darker(root.contentForeground, 1.5)
                fontFamily: root.contentFontFamily
                fontSize: Style.font.caption
                iconSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: !!root.livePet
                text: "· " + root.livePet.moodLabel + " · " + root.livePet.ageLabel
                color: Qt.darker(root.contentForeground, 1.5)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                width: Math.max(20, parent.width - walletCoins.implicitWidth - parent.spacing)
                anchors.verticalCenter: parent.verticalCenter
              }
            }
          }

          Item {
            visible: !root.inShop
            width: parent.width
            height: skinSprite.height

            PetSprite {
              id: skinSprite
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              pixelSize: 6
              hatched: root.livePet ? root.livePet.hatched : false
              genome: root.livePet ? root.livePet.genome : null
              shopHat: root.livePet ? root.livePet.hatItem : null
              shopToy: root.livePet ? root.livePet.toyItem : null
              parts: root.livePet ? root.livePet.partSet : null
              shopFrame: dressTick.frame
              dirty: root.livePet ? root.livePet.dirty : 0
              pose: {
                if (root.isEgg) return "walk"
                if (!root.livePet) return "idle"
                if (root.livePet.sleeping) return "sleep"
                if (root.livePet.mood === "sad") return "sad"
                return "idle"
              }
              frame: root.isEgg ? eggWobble.frame : dressTick.frame
              bodyColor: Color.accent
            }

            Timer {
              id: eggWobble
              property int frame: 0
              interval: 560
              repeat: true
              running: root.opened && root.isEgg && !root.inShop
              onTriggered: frame = (frame + 1) % 2
            }

            Timer {
              id: dressTick
              property int frame: 0
              interval: 280
              repeat: true
              running: root.opened && !root.isEgg
              onTriggered: frame = (frame + 1) % 5
            }
          }

          Column {
            visible: root.isEgg && !root.inShop
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: "Name your tamOmarchy, then hatch it. Each hatch stitches random parts into a unique creature."
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            TextField {
              id: nameField
              width: parent.width
              placeholderText: "Name your tamOmarchy"
              foreground: root.contentForeground
              font.family: root.contentFontFamily
              maximumLength: 18
              onAccepted: root.confirmHatch()
            }

            Button {
              width: parent.width
              text: "Hatch"
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.confirmHatch()
            }
          }

          Column {
            visible: !root.isEgg && !root.inShop
            width: parent.width
            spacing: Style.space(8)

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: Style.space(36)
                text: "‹"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleEquip("hat", -1)
              }

              Text {
                width: parent.width - Style.space(88)
                height: parent.height
                text: root.hatLabel
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              Button {
                width: Style.space(36)
                text: "›"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleEquip("hat", 1)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: Style.space(36)
                text: "‹"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleEquip("toy", -1)
              }

              Text {
                width: parent.width - Style.space(88)
                height: parent.height
                text: root.toyLabel
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              Button {
                width: Style.space(36)
                text: "›"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleEquip("toy", 1)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: Style.space(36)
                text: "‹"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleDifficulty(-1)
              }

              Text {
                width: parent.width - Style.space(88)
                height: parent.height
                text: root.livePet ? root.livePet.difficultyLabel : "Medium"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }

              Button {
                width: Style.space(36)
                text: "›"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.cycleDifficulty(1)
              }
            }

            Repeater {
              model: [
                { label: "HUNGER", value: root.livePet ? root.livePet.hunger : 0, invert: false },
                { label: "MOOD", value: root.livePet ? root.livePet.happiness : 0, invert: false },
                { label: "ENERGY", value: root.livePet ? root.livePet.energy : 0, invert: false },
                { label: "DIRTY", value: root.livePet ? root.livePet.dirty : 0, invert: true },
                { label: "POTTY", value: root.livePet ? root.livePet.pottyPct : 0, invert: true }
              ]

              Item {
                required property var modelData
                width: content.width
                height: Math.max(meterLabel.implicitHeight, Style.space(10))

                Text {
                  id: meterLabel
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(58)
                  text: modelData.label
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.letterSpacing: 1
                }

                Text {
                  id: meterPct
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  text: Math.round(modelData.value) + "%"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Rectangle {
                  anchors.left: meterLabel.right
                  anchors.right: meterPct.left
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  height: Style.space(6)
                  radius: Style.cornerRadius > 0 ? height / 2 : 0
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.12)

                  Rectangle {
                    width: Math.round(parent.width * Math.max(0, Math.min(1, modelData.value / 100)))
                    height: parent.height
                    radius: parent.radius
                    color: root.meterColor(modelData.value, modelData.invert)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                  }
                }
              }
            }

            Dropdown {
              id: displayPick
              width: parent.width
              label: "Stay on"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              options: root.displayOptions
              value: root.livePet ? (root.livePet.confineOutput || "") : ""
              onChanged: function(v) {
                if (root.livePet) root.livePet.setConfineOutput(v)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Draw playpen"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.startScreenDraw()
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Wander freely"
                bordered: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: if (root.livePet) root.livePet.clearPen()
              }
            }

            Button {
              width: parent.width
              text: "Shop"
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.openShop()
            }

            Toggle {
              width: parent.width
              label: "Pause Care"
              description: "Freeze stats and coins where they are. Turn off to resume care."
              checked: root.livePet ? root.livePet.carePaused : false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.livePet) root.livePet.toggleMaintenance()
            }

            Toggle {
              width: parent.width
              label: "No Death"
              description: "Starve and lonely put them to sleep instead of dying. Copper earns every 3 minutes instead of 1. The Kill mini-game still works."
              checked: root.livePet ? root.livePet.noDeath : false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.livePet) root.livePet.toggleNoDeath()
            }

            Toggle {
              visible: root.livePet && root.livePet.graveCount > 0
              width: parent.width
              label: "Graves"
              description: "Show tombstones along the bottom of the screen."
              checked: root.livePet ? root.livePet.gravesShown !== false : true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.livePet) root.livePet.toggleGraves()
            }
          }

          Column {
            visible: root.inShop
            width: parent.width
            spacing: Style.space(8)

            Timer {
              id: shopTick
              property int frame: 0
              interval: 280
              repeat: true
              running: root.opened && root.inShop
              onTriggered: frame = (frame + 1) % 5
            }

            Row {
              width: parent.width
              spacing: Style.space(6)

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: "Hats"
                bordered: root.shopTab !== "hats"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.shopTab = "hats"
              }

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: "Toys"
                bordered: root.shopTab !== "toys"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.shopTab = "toys"
              }

              Button {
                width: (parent.width - parent.spacing * 2) / 3
                text: "Home"
                bordered: root.shopTab !== "gear"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.shopTab = "gear"
              }
            }

            Grid {
              id: shopGrid
              width: parent.width
              columns: 2
              columnSpacing: Style.space(8)
              rowSpacing: Style.space(8)

              Repeater {
                model: root.shopItems

                Rectangle {
                  required property var modelData
                  width: (shopGrid.width - shopGrid.columnSpacing) / 2
                  height: shopCard.implicitHeight + Style.space(16)
                  radius: Style.cornerRadius
                  color: Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.08)

                  HoverHandler {
                    id: shopCardHover
                  }

                  PanelToolTip {
                    visible: !!(modelData && modelData.kind === "gear" && modelData.about && shopCardHover.hovered)
                    text: modelData && modelData.about ? modelData.about : ""
                    fontFamily: root.contentFontFamily
                  }

                  Column {
                    id: shopCard
                    width: parent.width - Style.space(16)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Style.space(8)
                    spacing: Style.space(6)

                    PetSprite {
                      anchors.horizontalCenter: parent.horizontalCenter
                      pixelSize: 5
                      hatched: true
                      itemOnly: !!(modelData && modelData.kind === "gear")
                      genome: root.livePet ? root.livePet.genome : null
                      parts: root.livePet ? root.livePet.partSet : null
                      shopHat: {
                        if (modelData && modelData.kind === "hat") return modelData
                        return root.livePet ? root.livePet.hatItem : null
                      }
                      shopToy: (modelData && modelData.kind === "toy") ? modelData : null
                      shopGear: (modelData && modelData.kind === "gear") ? modelData : null
                      pose: {
                        if (!modelData || modelData.kind === "gear") return "idle"
                        if (modelData.kind !== "toy") return "idle"
                        if (modelData.play === "jump" || modelData.play === "glide") return "walk"
                        if (modelData.play === "spin") return "dance"
                        if (modelData.play === "think" || modelData.play === "roll") return "sit"
                        return "idle"
                      }
                      rotation: (modelData && modelData.play === "spin") ? shopTick.frame * 24 : 0
                      frame: shopTick.frame
                      shopFrame: shopTick.frame
                      bodyColor: Color.accent
                    }

                    Text {
                      width: parent.width
                      text: modelData && modelData.name ? modelData.name : ""
                      color: root.contentForeground
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.bodySmall
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }

                    Text {
                      visible: {
                        if (!modelData) return false
                        if (modelData.kind === "toy" && modelData.play) return true
                        if (modelData.kind === "gear" && modelData.auto) return true
                        return false
                      }
                      width: parent.width
                      text: {
                        if (!modelData) return ""
                        if (modelData.kind === "gear")
                          return root.livePet ? root.livePet.gearAutoLabel(modelData.auto) : ""
                        return modelData.play || ""
                      }
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                    }

                    CoinAmount {
                      visible: !!(modelData && modelData.cost > 0)
                      anchors.horizontalCenter: parent.horizontalCenter
                      copper: modelData && modelData.cost > 0 ? modelData.cost : 0
                      emptyCopper: false
                      foreground: Qt.darker(root.contentForeground, 1.5)
                      fontFamily: root.contentFontFamily
                      fontSize: Style.font.caption
                      iconSize: Style.font.caption
                    }

                    Text {
                      visible: !(modelData && modelData.cost > 0)
                      width: parent.width
                      text: "—"
                      color: Qt.darker(root.contentForeground, 1.5)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                    }

                    Button {
                      width: parent.width
                      text: (root.shopRev, root.points, root.shopButtonLabel(modelData))
                      bordered: true
                      enabled: (root.shopRev, root.shopCanBuy(modelData))
                      foreground: root.contentForeground
                      fontFamily: root.contentFontFamily
                      onClicked: if (root.livePet && modelData) root.livePet.buyItem(modelData.kind, modelData.id)
                    }
                  }
                }
              }
            }

            Button {
              width: parent.width
              text: "Back"
              bordered: true
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.view = "care"
            }
          }
        }
      }
    }
  }
}
