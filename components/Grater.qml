import QtQuick
import qs.Commons

// Chunky cheese grater. The body is the grate surface the pet must be
// dragged along.
Item {
  id: root

  property string petName: "Mochi"
  property real pulse: 0

  readonly property int holeCols: 4
  readonly property int holeRows: 8
  readonly property int holeW: 22
  readonly property int holeH: 12
  readonly property int holeGapX: 10
  readonly property int holeGapY: 10
  readonly property int padX: 18
  readonly property int padY: 22

  width: padX * 2 + holeCols * holeW + (holeCols - 1) * holeGapX
  height: 36 + padY * 2 + holeRows * holeH + (holeRows - 1) * holeGapY + 28

  readonly property real surfaceX: body.x
  readonly property real surfaceY: body.y
  readonly property real surfaceW: body.width
  readonly property real surfaceH: body.height

  Column {
    anchors.fill: parent
    spacing: 0

    Item {
      width: parent.width
      height: 36

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 28
        height: 36
        radius: 6
        color: Qt.rgba(0.55, 0.58, 0.64, 1)
        border.width: 2
        border.color: Qt.rgba(0.28, 0.30, 0.34, 1)
      }
    }

    Rectangle {
      id: body
      width: parent.width
      height: root.padY * 2 + root.holeRows * root.holeH + (root.holeRows - 1) * root.holeGapY
      radius: 14
      color: Qt.rgba(0.72, 0.74, 0.78, 1)
      border.width: 3
      border.color: Qt.rgba(0.32, 0.34, 0.38, 1)

      Repeater {
        model: root.holeCols * root.holeRows

        Rectangle {
          required property int index
          width: root.holeW
          height: root.holeH
          radius: 3
          color: Qt.rgba(0.10, 0.10, 0.12, 0.92)
          x: root.padX + (index % root.holeCols) * (root.holeW + root.holeGapX)
          y: root.padY + Math.floor(index / root.holeCols) * (root.holeH + root.holeGapY)
        }
      }
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    y: -52 + Math.round(Math.sin(root.pulse) * 10)
    text: "▼"
    color: Color.accent
    font.pixelSize: Style.font.displayLarge
    font.bold: true
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.top
    anchors.bottomMargin: 58
    width: Math.max(root.width, 220)
    horizontalAlignment: Text.AlignHCenter
    text: "Grate " + root.petName
    textFormat: Text.PlainText
    color: Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: 10
    width: Math.max(root.width, 240)
    horizontalAlignment: Text.AlignHCenter
    text: "Keep grating · up and down · right-click to cancel"
    color: Qt.darker(Color.foreground, 1.35)
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
