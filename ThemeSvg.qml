import QtQuick
import QtQuick.Effects
import qs.Commons

// Theme-tinted SVG. White fills colorize; black ones stay black.
Image {
  id: root

  property color tint: Color.foreground

  fillMode: Image.PreserveAspectFit
  asynchronous: true
  layer.enabled: true
  layer.smooth: true
  layer.effect: MultiEffect {
    colorization: 1.0
    colorizationColor: root.tint
  }
}
