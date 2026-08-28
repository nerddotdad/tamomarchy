import QtQuick
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property string kind: "poop"
  property int pixelSize: 3

  readonly property int cols: 6
  readonly property int rows: 6

  implicitWidth: cols * pixelSize
  implicitHeight: rows * pixelSize

  onKindChanged: canvas.requestPaint()
  onPixelSizeChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: false
    renderStrategy: Canvas.Immediate

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var pixels = Model.messPixels(root.kind)
      var scale = root.pixelSize
      var poop = Qt.rgba(0.42, 0.24, 0.08, 1)
      var poopHi = Qt.rgba(0.55, 0.34, 0.12, 1)
      var pee = Qt.rgba(0.92, 0.78, 0.18, 0.92)

      for (var y = 0; y < pixels.length; y++) {
        var row = String(pixels[y] || "")
        for (var x = 0; x < row.length; x++) {
          var ch = row.charAt(x)
          if (ch === "." || ch === " ") continue
          var color = pee
          if (ch === "D") color = poop
          else if (ch === "B") color = poopHi
          else if (ch === "Y") color = pee
          ctx.fillStyle = color
          ctx.fillRect(x * scale, y * scale, scale, scale)
        }
      }
    }
  }
}
