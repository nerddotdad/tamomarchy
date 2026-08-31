import QtQuick
import qs.Commons
import "../Model.js" as Model

// Theme-colored pixel pet. Overlay uses a larger scale; the bar uses a
// compact one that fits the icon slot.
// Theme letters follow the shell: B body, D line, T shade, H deep, E eye, P pupil, M mouth.
// Paint letters stay put: R O Y G U V N C K W A.
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
  property var shopHat: null
  property var shopToy: null
  property int shopFrame: 0
  property var parts: null
  property var shopGear: null
  property bool itemOnly: false
  property real dirty: 0

  readonly property int cols: Model.SPRITE_COLS
  readonly property int rows: Model.SPRITE_ROWS
  readonly property var pixels: Model.framePixels(root.pose, root.frame, root.genome, root.hatched, root.shopHat, root.shopToy, root.shopFrame, root.parts, root.itemOnly, root.shopGear)
  readonly property int pixelRows: root.pixels && root.pixels.length ? root.pixels.length : root.rows
  readonly property int bodyOrigin: Math.max(0, root.pixelRows - root.rows)
  readonly property int hatLift: bodyOrigin * pixelSize
  readonly property int spriteWidth: cols * pixelSize
  readonly property int spriteHeight: pixelRows * pixelSize

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
  onShopHatChanged: canvas.requestPaint()
  onShopToyChanged: canvas.requestPaint()
  onShopFrameChanged: canvas.requestPaint()
  onPartsChanged: canvas.requestPaint()
  onItemOnlyChanged: canvas.requestPaint()
  onShopGearChanged: canvas.requestPaint()
  onDirtyChanged: canvas.requestPaint()
  onPixelsChanged: canvas.requestPaint()

  function pixelColor(ch) {
    if (ch === "F" || ch === "S") ch = "D"
    if (ch === "B") return root.bodyColor
    if (ch === "D") return root.lineColor
    if (ch === "T") return Qt.darker(root.bodyColor, 1.15)
    if (ch === "H") return Qt.darker(root.lineColor, 1.8)
    if (ch === "E") return root.eyeColor
    if (ch === "P") return root.pupilColor
    if (ch === "M") return Qt.darker(root.lineColor, 1.15)
    if (ch === "R") return "#e24b4b"
    if (ch === "O") return "#e8883a"
    if (ch === "Y") return "#f2d138"
    if (ch === "G") return "#3dbb6b"
    if (ch === "U") return "#4a8fe7"
    if (ch === "V") return "#9b6bde"
    if (ch === "N") return "#8a5a32"
    if (ch === "C") return "#f26b7a"
    if (ch === "K") return "#1a1a1a"
    if (ch === "W") return "#f5f5f5"
    if (ch === "A") return "#8b8b8b"
    return null
  }

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
      for (var y = 0; y < pixels.length; y++) {
        var row = String(pixels[y] || "")
        for (var x = 0; x < row.length; x++) {
          var color = root.pixelColor(row.charAt(x))
          if (!color) continue
          var dx = root.facingLeft ? (root.cols - 1 - x) : x
          ctx.fillStyle = color
          ctx.fillRect(dx * scale, y * scale, scale, scale)
        }
      }
      if (!root.itemOnly && root.hatched && root.dirty > 0.5) {
        var spots = Model.DIRT_SPOTS
        var show = Math.round((root.dirty / 100) * spots.length)
        var origin = root.bodyOrigin
        for (var i = 0; i < show && i < spots.length; i++) {
          var spot = spots[i]
          var sx = spot[0]
          var sy = spot[1] + origin
          var body = String(pixels[sy] || "").charAt(sx)
          if (!body || body === "." || body === " ") continue
          var px = root.facingLeft ? (root.cols - 1 - sx) : sx
          ctx.fillStyle = Model.dirtShade(spot[2])
          ctx.fillRect(px * scale, sy * scale, scale, scale)
        }
      }
    }
  }
}
