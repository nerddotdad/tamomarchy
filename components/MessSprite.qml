import QtQuick
import qs.Commons
import "../Model.js" as Model

Item {
  id: root

  property string kind: "poop"
  property int pixelSize: Model.MESS_PIXEL
  property int frame: 0

  readonly property int cols: Model.MESS_COLS
  readonly property int rows: Model.MESS_ROWS

  implicitWidth: cols * pixelSize
  implicitHeight: rows * pixelSize

  onKindChanged: canvas.requestPaint()
  onPixelSizeChanged: canvas.requestPaint()
  onFrameChanged: canvas.requestPaint()

  Timer {
    interval: 900
    repeat: true
    running: true
    onTriggered: root.frame = (root.frame + 1) % 2
  }

  SequentialAnimation on opacity {
    running: true
    loops: Animation.Infinite
    NumberAnimation { from: 1; to: 0.58; duration: 1100; easing.type: Easing.InOutSine }
    NumberAnimation { from: 0.58; to: 1; duration: 1100; easing.type: Easing.InOutSine }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: false
    renderStrategy: Canvas.Immediate

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var pixels = Model.messPixels(root.kind, root.frame)
      var scale = root.pixelSize
      var poop = Qt.rgba(0.42, 0.24, 0.08, 1)
      var poopHi = Qt.rgba(0.55, 0.34, 0.12, 1)
      var pee = Qt.rgba(0.92, 0.78, 0.18, 0.92)
      var stink = Qt.rgba(0.45, 0.58, 0.28, 0.85)
      var drip = Qt.rgba(0.95, 0.84, 0.28, 0.8)

      for (var y = 0; y < pixels.length; y++) {
        var row = String(pixels[y] || "")
        for (var x = 0; x < row.length; x++) {
          var ch = row.charAt(x)
          if (ch === "." || ch === " ") continue
          var color = pee
          if (ch === "D") color = poop
          else if (ch === "B") color = poopHi
          else if (ch === "Y") color = pee
          else if (ch === "G") color = stink
          else if (ch === "L") color = drip
          ctx.fillStyle = color
          ctx.fillRect(x * scale, y * scale, scale, scale)
        }
      }
    }
  }
}
