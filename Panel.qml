import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.nerddotdad.tamomarchy"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var pet: null
  readonly property var livePet: pet || (bar && bar.shell ? bar.shell.serviceFor("io.github.nerddotdad.tamomarchy") : null)
  readonly property bool isEgg: livePet ? livePet.hatched === false : true

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
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
      if (open && root.isEgg)
        Qt.callLater(function() { nameField.forceActiveFocus() })
    }
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
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
              text: root.isEgg ? "An egg" : (root.livePet ? root.livePet.petName : "tamOmarchy")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              text: root.livePet ? (root.livePet.moodLabel + " · " + root.livePet.ageLabel) : ""
              color: Qt.darker(root.contentForeground, 1.5)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Item {
            width: parent.width
            height: skinSprite.height

            PetSprite {
              id: skinSprite
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              pixelSize: 6
              hatched: root.livePet ? root.livePet.hatched : false
              genome: root.livePet ? root.livePet.genome : null
              pose: root.isEgg ? "walk" : (root.livePet ? (root.livePet.sleeping ? "sleep" : (root.livePet.mood === "sad" ? "sad" : "idle")) : "idle")
              frame: eggWobble.frame
              bodyColor: Color.accent
            }

            Timer {
              id: eggWobble
              property int frame: 0
              interval: 560
              repeat: true
              running: root.opened && root.isEgg
              onTriggered: frame = (frame + 1) % 2
            }
          }

          Column {
            visible: root.isEgg
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
            visible: !root.isEgg
            width: parent.width
            spacing: Style.space(8)

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

          Toggle {
            width: parent.width
            label: "Maintenance"
            description: "Hunger, mood, energy, and mess. Off lets him wander with full stats."
            checked: root.livePet ? root.livePet.maintenance !== false : true
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: if (root.livePet) root.livePet.toggleMaintenance()
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
        }
      }
    }
  }
}
