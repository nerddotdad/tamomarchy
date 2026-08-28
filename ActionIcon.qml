import QtQuick
import qs.Commons

Item {
  id: root

  property string glyph: ""
  property string label: ""
  property bool lit: false
  property int discSize: 48

  width: discSize + 8
  height: discSize + 22

  Rectangle {
    id: disc
    width: root.discSize
    height: root.discSize
    radius: root.discSize / 2
    anchors.horizontalCenter: parent.horizontalCenter
    color: root.lit ? Color.accent : Color.popups.background
    border.width: 2
    border.color: root.lit ? Color.accent : Color.popups.border
    scale: root.lit ? 1.1 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Behavior on color { ColorAnimation { duration: 90 } }

    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: root.lit ? Color.background : Color.foreground
      font.family: Style.font.family
      font.pixelSize: Math.round(root.discSize * 0.5)
    }
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: disc.bottom
    anchors.topMargin: 4
    text: root.label
    color: root.lit ? Color.accent : Color.foreground
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    font.bold: true
  }
}
