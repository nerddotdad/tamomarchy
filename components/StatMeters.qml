import QtQuick
import qs.Commons

// Compact meters. Hunger/mood/energy want to be full; dirty/potty want to be empty.
Item {
  id: root

  property var pet: null
  property string focusStat: ""

  readonly property real hunger: pet ? pet.hunger : 0
  readonly property real happiness: pet ? pet.happiness : 0
  readonly property real energy: pet ? pet.energy : 0
  readonly property real dirty: pet ? pet.dirty : 0
  readonly property real potty: pet ? pet.pottyPct : 0

  implicitHeight: 72
  height: implicitHeight

  function meterColor(value, key) {
    var invert = key === "dirty" || key === "potty"
    if (invert ? value > 75 : value < 25) return Color.urgent
    if (root.focusStat && root.focusStat === key) return Color.accent
    return Color.foreground
  }

  Column {
    anchors.fill: parent
    spacing: 8

    Row {
      id: careRow
      width: parent.width
      spacing: 10
      height: 32

      Repeater {
        model: [
          { key: "hunger", label: "HUNGER", value: root.hunger },
          { key: "mood", label: "MOOD", value: root.happiness },
          { key: "energy", label: "ENERGY", value: root.energy }
        ]

        Column {
          required property var modelData
          width: (careRow.width - 20) / 3
          spacing: 4
          opacity: root.focusStat && root.focusStat !== modelData.key ? 0.45 : 1

          Item {
            width: parent.width
            height: Math.max(tag.implicitHeight, pct.implicitHeight)

            Text {
              id: tag
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: Qt.darker(Color.foreground, 1.35)
              font.family: Style.font.family
              font.pixelSize: 9
              font.letterSpacing: 0.6
              font.bold: true
            }

            Text {
              id: pct
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round(modelData.value) + "%"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)

            Rectangle {
              width: Math.round(parent.width * Math.max(0, Math.min(1, modelData.value / 100)))
              height: parent.height
              radius: parent.radius
              color: root.meterColor(modelData.value, modelData.key)
              Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
          }
        }
      }
    }

    Row {
      id: cleanRow
      width: parent.width
      spacing: 10
      height: 32

      Repeater {
        model: [
          { key: "dirty", label: "DIRTY", value: root.dirty },
          { key: "potty", label: "POTTY", value: root.potty }
        ]

        Column {
          required property var modelData
          width: (cleanRow.width - 10) / 2
          spacing: 4
          opacity: root.focusStat && root.focusStat !== modelData.key ? 0.45 : 1

          Item {
            width: parent.width
            height: Math.max(dtag.implicitHeight, dpct.implicitHeight)

            Text {
              id: dtag
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.label
              color: Qt.darker(Color.foreground, 1.35)
              font.family: Style.font.family
              font.pixelSize: 9
              font.letterSpacing: 0.6
              font.bold: true
            }

            Text {
              id: dpct
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round(modelData.value) + "%"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.16)

            Rectangle {
              width: Math.round(parent.width * Math.max(0, Math.min(1, modelData.value / 100)))
              height: parent.height
              radius: parent.radius
              color: root.meterColor(modelData.value, modelData.key)
              Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
          }
        }
      }
    }
  }
}
