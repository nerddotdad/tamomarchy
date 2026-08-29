import QtQuick
import qs.Commons

Item {
  id: root

  property string nextKey: ""
  property int hits: 0
  property var keys: []

  signal tapped(string letter)

  readonly property int keySize: 42
  readonly property int keyGap: 6
  readonly property int clusterW: keySize * 3 + keyGap * 2
  readonly property int clusterH: keySize * 2 + keyGap

  width: clusterW
  height: clusterH + 28

  function keyCap(letter) {
    return letter === "W" ? "↑" : letter === "A" ? "←" : letter === "S" ? "↓" : "→"
  }

  component LullabyKey: Rectangle {
    id: cap
    required property string letter
    readonly property bool lit: root.nextKey === letter

    width: root.keySize
    height: root.keySize
    radius: 10
    color: cap.lit ? Color.accent : Color.popups.background
    border.width: 2
    border.color: cap.lit ? Color.accent : Color.popups.border
    scale: cap.lit ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: 90 } }

    Column {
      anchors.centerIn: parent
      spacing: 0

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.keyCap(cap.letter)
        color: cap.lit ? Color.background : Color.foreground
        font.pixelSize: Style.font.body
        font.bold: true
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: cap.letter
        color: cap.lit ? Color.background : Qt.darker(Color.foreground, 1.25)
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.tapped(cap.letter)
    }
  }

  Item {
    id: cluster
    width: root.clusterW
    height: root.clusterH

    LullabyKey {
      letter: "W"
      x: root.keySize + root.keyGap
      y: 0
    }
    LullabyKey {
      letter: "A"
      x: 0
      y: root.keySize + root.keyGap
    }
    LullabyKey {
      letter: "S"
      x: root.keySize + root.keyGap
      y: root.keySize + root.keyGap
    }
    LullabyKey {
      letter: "D"
      x: (root.keySize + root.keyGap) * 2
      y: root.keySize + root.keyGap
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: cluster.bottom
    anchors.topMargin: 8
    spacing: 4

    Repeater {
      model: 8
      Rectangle {
        required property int index
        width: 8
        height: 8
        radius: 4
        color: index < root.hits
          ? Color.accent
          : (index === root.hits ? Color.foreground : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.28))
      }
    }
  }
}
