import QtQuick
import qs.Commons
import "../Model.js" as Model

// Number plus a copper, silver, or gold coin. Hides empty denominations.
Row {
  id: root

  property int copper: 0
  property int iconSize: 12
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int fontSize: Style.font.caption
  property bool emptyCopper: true

  readonly property var coins: Model.coinsFromCopper(root.copper)
  readonly property bool showGold: coins.gold > 0
  readonly property bool showSilver: coins.silver > 0
  readonly property bool showCopper: coins.copper > 0 || (!showGold && !showSilver && root.emptyCopper)

  spacing: Style.space(6)
  height: Math.max(iconSize, fontSize + 2)

  Row {
    visible: root.showGold
    spacing: Style.space(3)
    height: root.height

    Text {
      text: String(root.coins.gold)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      anchors.verticalCenter: parent.verticalCenter
    }

    Image {
      width: root.iconSize
      height: root.iconSize
      anchors.verticalCenter: parent.verticalCenter
      source: Qt.resolvedUrl("../icons/coin-gold.svg")
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
    }
  }

  Row {
    visible: root.showSilver
    spacing: Style.space(3)
    height: root.height

    Text {
      text: String(root.coins.silver)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      anchors.verticalCenter: parent.verticalCenter
    }

    Image {
      width: root.iconSize
      height: root.iconSize
      anchors.verticalCenter: parent.verticalCenter
      source: Qt.resolvedUrl("../icons/coin-silver.svg")
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
    }
  }

  Row {
    visible: root.showCopper
    spacing: Style.space(3)
    height: root.height

    Text {
      text: String(root.coins.copper)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      anchors.verticalCenter: parent.verticalCenter
    }

    Image {
      width: root.iconSize
      height: root.iconSize
      anchors.verticalCenter: parent.verticalCenter
      source: Qt.resolvedUrl("../icons/coin-copper.svg")
      fillMode: Image.PreserveAspectFit
      smooth: true
      asynchronous: true
    }
  }
}
