import QtQuick
import qs.Commons
import "Model.js" as Model

// Theme-colored pixel pet. Overlay uses a larger scale; the bar uses a
// compact one that fits the icon slot.
Item {
  id: root

  property string pose: "idle"
  property int frame: 0
  property bool facingLeft: false
  property int pixelSize: 4
  property color bodyColor: Color.accent
  property color lineColor: Qt.darker(bodyColor, 1.35)
  property color eyeColor: Color.foreground
  property color pupilColor: Color.background
  property var genome: null
  property bool hatched: false

  readonly property int cols: Model.SPRITE_COLS
  readonly property int rows: Model.SPRITE_ROWS
  readonly property int spriteWidth: cols * pixelSize
  readonly property int spriteHeight: rows * pixelSize

  implicitWidth: spriteWidth
  implicitHeight: spriteHeight

  onPoseChanged: canvas.requestPaint()
  onFrameChanged: canvas.requestPaint()
  onFacingLeftChanged: canvas.requestPaint()
  onBodyColorChanged: canvas.requestPaint()
  onLineColorChanged: canvas.requestPaint()
  onEyeColorChanged: canvas.requestPaint()
  onPupilColorChanged: canvas.requestPaint()
  onPixelSizeChanged: canvas.requestPaint()
  onGenomeChanged: canvas.requestPaint()
  onHatchedChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: false
    renderStrategy: Canvas.Immediate

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var pixels = Model.framePixels(root.pose, root.frame, root.genome, root.hatched)
      var scale = root.pixelSize
      var cheek = Qt.rgba(0.95, 0.42, 0.48, 0.9)
      var mouth = Qt.darker(root.lineColor, 1.15)
      var cups = Qt.darker(root.lineColor, 1.8)
      var gold = Qt.rgba(0.95, 0.82, 0.22, 1)

      for (var y = 0; y < pixels.length; y++) {
        var row = String(pixels[y] || "")
        for (var x = 0; x < row.length; x++) {
          var ch = row.charAt(x)
          if (ch === "." || ch === " ") continue
          var color = root.bodyColor
          if (ch === "D") color = root.lineColor
          else if (ch === "E") color = root.eyeColor
          else if (ch === "P") color = root.pupilColor
          else if (ch === "C") color = cheek
          else if (ch === "M" || ch === "W") color = mouth
          else if (ch === "H") color = cups
          else if (ch === "Y") color = gold
          else if (ch === "T") color = Qt.darker(root.bodyColor, 1.15)
          else if (ch === "S") color = Qt.darker(root.lineColor, 1.1)
          else if (ch === "F") color = root.lineColor
          var dx = root.facingLeft ? (root.cols - 1 - x) : x
          ctx.fillStyle = color
          ctx.fillRect(dx * scale, y * scale, scale, scale)
        }
      }
    }
  }
}
