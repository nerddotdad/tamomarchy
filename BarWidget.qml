import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.nerddotdad.tamomarchy"

  readonly property var pet: bar && bar.shell ? bar.shell.serviceFor("io.github.nerddotdad.tamomarchy") : null
  readonly property string pose: pet ? Model.poseFor(pet.snapshot(), false, pet.scene) : "idle"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function qmlPath(name) {
    return String(Qt.resolvedUrl(name)).replace(/^file:\/\//, "")
  }

  function remountPanel() {
    panelLoader.active = false
    Qt.callLater(function() { panelLoader.active = true })
  }

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
    panelLoader.item.pet = root.pet
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onPetChanged: injectPanel()

  FileView {
    path: root.qmlPath("Panel.qml")
    watchChanges: true
    printErrors: false
    onFileChanged: root.remountPanel()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
    onStatusChanged: {
      if (status === Loader.Error)
        console.warn("tamagotchi Panel.qml failed to load")
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: pet
      ? (pet.hatched ? (pet.petName + " · " + pet.moodLabel) : "An egg · tap to hatch")
      : "tamOmarchy"
    hasVisualContent: true
    keepSpace: true
    fixedWidth: root.vertical ? -1 : sprite.implicitWidth + Style.space(16)
    fixedHeight: root.vertical ? sprite.implicitHeight + Style.space(8) : -1

    PetSprite {
      id: sprite
      anchors.centerIn: parent
      pixelSize: 2
      pose: root.pose
      hatched: pet ? pet.hatched : false
      genome: pet ? pet.genome : null
      bodyColor: root.bar ? root.bar.barForeground : Color.accent
      lineColor: root.bar ? Qt.darker(root.bar.barForeground, 1.25) : Qt.darker(Color.accent, 1.35)
      eyeColor: root.bar ? root.bar.background : Color.background
      pupilColor: root.bar ? root.bar.barForeground : Color.foreground
    }

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (root.pet) root.pet.toggleShown()
      } else if (buttonCode === Qt.MiddleButton) {
        if (root.pet) root.pet.toggleSleep()
      } else {
        root.toggle()
      }
    }
  }
}
