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
    return root.shopTab === "toys" ? (root.livePet.shopToys || []) : (root.livePet.shopHats || [])
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
    if (!root.livePet || root.livePet.score < item.cost) return "Need more pts"
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

  function meterColor(value) {
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
    contentWidth: panel.fittedContentWidth(Style.space(root.inShop ? 360 : 320))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: nameField.activeFocus
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

            Text {
              text: root.livePet ? (root.points + " pts · " + root.livePet.moodLabel + " · " + root.livePet.ageLabel) : ""
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
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
              pose: {
                if (root.isEgg) return "walk"
                if (!root.livePet) return "idle"
                if (root.livePet.sleeping) return "sleep"
                if (root.livePet.toyPose === "dance") return "dance"
                if (root.livePet.toyPose === "walk") return "walk"
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
                { label: "HUNGER", value: root.livePet ? root.livePet.hunger : 0 },
                { label: "MOOD", value: root.livePet ? root.livePet.happiness : 0 },
                { label: "ENERGY", value: root.livePet ? root.livePet.energy : 0 }
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
                    color: root.meterColor(modelData.value)
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                  }
                }
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
              description: "Freeze stats and points where they are. Turn off to resume care."
              checked: root.livePet ? root.livePet.carePaused : false
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: if (root.livePet) root.livePet.toggleMaintenance()
            }

            Toggle {
              width: parent.width
              label: "No Death"
              description: "Starve and lonely put them to sleep instead of dying. The Kill mini-game still works."
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
              spacing: Style.space(8)

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Hats"
                bordered: root.shopTab !== "hats"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.shopTab = "hats"
              }

              Button {
                width: (parent.width - parent.spacing) / 2
                text: "Toys"
                bordered: root.shopTab !== "toys"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.shopTab = "toys"
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
                      genome: root.livePet ? root.livePet.genome : null
                      parts: root.livePet ? root.livePet.partSet : null
                      shopHat: {
                        if (modelData && modelData.kind === "hat") return modelData
                        return root.livePet ? root.livePet.hatItem : null
                      }
                      shopToy: (modelData && modelData.kind === "toy") ? modelData : null
                      pose: {
                        if (!modelData || modelData.kind !== "toy") return "idle"
                        if (modelData.pose === "dance" || modelData.pose === "walk") return modelData.pose
                        return "idle"
                      }
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
                      width: parent.width
                      text: modelData && modelData.cost > 0 ? (modelData.cost + " pts") : "—"
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
