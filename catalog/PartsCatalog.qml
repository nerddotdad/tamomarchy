import QtQuick
import "../Looks/parts/Parse.js" as Parts

// Reads Looks/parts/{bodies,heads,hats,arms,legs,tails}/*.md and optional
// user copies under ~/.config/omarchy/tamomarchy/parts/. template.md is skipped.
Item {
  id: root

  property string home: ""
  property var partSet: Parts.emptySet()
  readonly property var slots: ["bodies", "heads", "hats", "arms", "legs", "tails"]

  function userFolder(slot) {
    if (!root.home) return ""
    return "file://" + root.home + "/.config/omarchy/tamomarchy/parts/" + slot
  }

  function dump() {
    var blob = ""
    for (var i = 0; i < folders.count; i++) {
      var folder = folders.itemAt(i)
      var paths = []
      for (var key in folder.entries) {
        if (folder.entries.hasOwnProperty(key)) paths.push(key)
      }
      paths.sort()
      for (var j = 0; j < paths.length; j++) {
        blob += "___TAM_PART___ " + folder.tag + " " + paths[j] + "\n"
        blob += folder.entries[paths[j]] + "\n"
      }
    }
    return blob
  }

  function rebuild() {
    root.partSet = Parts.parseBundle(root.dump())
  }

  function reload() {
    for (var i = 0; i < folders.count; i++)
      folders.itemAt(i).refresh()
  }

  Timer {
    id: debounce
    interval: 20
    repeat: false
    onTriggered: root.rebuild()
  }

  function schedule() { debounce.restart() }

  Repeater {
    id: folders
    model: {
      var rows = []
      for (var i = 0; i < root.slots.length; i++) {
        var slot = root.slots[i]
        rows.push({ tag: slot, folder: Qt.resolvedUrl("../Looks/parts/" + slot) })
        rows.push({ tag: slot, folder: root.userFolder(slot) })
      }
      return rows
    }

    MdFolder {
      required property var modelData
      tag: modelData.tag
      folder: modelData.folder
      onUpdated: root.schedule()
    }
  }
}
