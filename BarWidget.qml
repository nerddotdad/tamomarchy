import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

BarWidget {
  id: root
  moduleName: "io.github.nerddotdad.tamomarchy"

  readonly property var pet: bar && bar.shell ? bar.shell.serviceFor("io.github.nerddotdad.tamomarchy") : null
  readonly property string pose: {
    if (!pet) return "idle"
    return Model.poseFor(pet.snapshot(), false, pet.scene)
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

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
    tooltipText: "tamOmarchy"
    hasVisualContent: true
    keepSpace: true
    fixedWidth: root.vertical ? -1 : spriteBox.width + Style.space(16)
    fixedHeight: root.vertical ? spriteBox.height + Style.space(8) : -1

    Item {
      id: spriteBox
      width: Model.SPRITE_COLS * 2
      height: Model.SPRITE_ROWS * 2
      anchors.centerIn: parent
      clip: true

      PetSprite {
        id: sprite
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        pixelSize: 2
        pose: root.pose
        frame: (root.pose === "walk" || root.pose === "dance") ? barShopTick.frame % 2 : 0
        hatched: pet ? pet.hatched : false
        genome: pet ? pet.genome : null
        parts: pet ? pet.partSet : null
        dirty: pet ? pet.dirty : 0
        bodyColor: root.bar ? root.bar.barForeground : Color.accent
        lineColor: root.bar ? Qt.darker(root.bar.barForeground, 1.25) : Qt.darker(Color.accent, 1.35)
        eyeColor: root.bar ? root.bar.background : Color.background
        pupilColor: root.bar ? root.bar.barForeground : Color.foreground
      }
    }

    Timer {
      id: barShopTick
      property int frame: 0
      interval: 280
      repeat: true
      running: !!pet && pet.hatched
      onTriggered: frame = (frame + 1) % 5
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
