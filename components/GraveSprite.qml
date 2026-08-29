import QtQuick
import qs.Commons
import "../Model.js" as Model

Item {
  id: root

  property string petName: ""
  property string appearance: "blob"
  property string cause: "starved"
  property double bornAt: 0
  property double diedAt: 0
  property int pixelSize: 4
  property int graveIndex: 0
  property real tilt: 0
  property int lean: 0

  readonly property string kind: Model.graveKind(graveIndex, diedAt)
  readonly property var pixels: Model.gravePixels(kind)
  readonly property int cols: String(pixels[0] || "").length
  readonly property int rows: pixels.length
  readonly property int stoneW: cols * pixelSize
  readonly property int stoneH: rows * pixelSize

  implicitWidth: stoneW + Math.abs(lean) * pixelSize * 2
  implicitHeight: stoneH

  rotation: root.tilt
  transformOrigin: Item.Bottom

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: false
    renderStrategy: Canvas.Immediate

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var pixels = root.pixels
      var scale = root.pixelSize
      var lean = root.lean
      var rows = pixels.length
      var pad = Math.abs(lean) * scale
      var wood = Qt.rgba(0.62, 0.42, 0.22, 1)
      var dark = Qt.rgba(0.38, 0.24, 0.12, 1)
      var dirt = Qt.rgba(0.42, 0.32, 0.18, 1)
      var grass = Qt.rgba(0.32, 0.52, 0.22, 1)
      var bloom = Qt.rgba(0.86, 0.38, 0.48, 1)
      var leaf = Qt.rgba(0.28, 0.58, 0.28, 1)

      for (var y = 0; y < pixels.length; y++) {
        var row = String(pixels[y] || "")
        var shear = rows > 1 ? Math.round((rows - 1 - y) * lean / (rows - 1)) : 0
        for (var x = 0; x < row.length; x++) {
          var ch = row.charAt(x)
          if (ch === "." || ch === " ") continue
          var color = dirt
          if (ch === "D") color = dark
          else if (ch === "Y") color = wood
          else if (ch === "G") color = grass
          else if (ch === "C") color = bloom
          else if (ch === "F") color = leaf
          else if (ch === "B") color = dirt
          ctx.fillStyle = color
          ctx.fillRect(pad + (x + shear) * scale, y * scale, scale, scale)
        }
      }
    }
  }

  Component.onCompleted: canvas.requestPaint()
  onPixelSizeChanged: canvas.requestPaint()
  onKindChanged: canvas.requestPaint()
  onLeanChanged: canvas.requestPaint()
  onPixelsChanged: canvas.requestPaint()
}
