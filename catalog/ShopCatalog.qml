import QtQuick
import "../Looks/shop/Parse.js" as Shop

// Reads Looks/shop/{hats,toys}/*.md and optional user copies under
// ~/.config/omarchy/tamomarchy/shop/. template.md is skipped.
Item {
  id: root

  property string home: ""
  property var hats: []
  property var toys: []

  function itemById(kind, id) {
    return Shop.findById(kind === "toy" ? root.toys : root.hats, id)
  }

  function userFolder(kind) {
    if (!root.home) return ""
    return "file://" + root.home + "/.config/omarchy/tamomarchy/shop/" + kind
  }

  function dump() {
    var folders = [pluginHats, pluginToys, userHats, userToys]
    var blob = ""
    for (var i = 0; i < folders.length; i++) {
      var folder = folders[i]
      var paths = []
      for (var key in folder.entries) {
        if (folder.entries.hasOwnProperty(key)) paths.push(key)
      }
      paths.sort()
      for (var j = 0; j < paths.length; j++) {
        blob += "___TAM_ITEM___ " + folder.tag + " " + paths[j] + "\n"
        blob += folder.entries[paths[j]] + "\n"
      }
    }
    return blob
  }

  function rebuild() {
    var next = Shop.parseBundle(root.dump())
    root.hats = next.hats || []
    root.toys = next.toys || []
  }

  function reload() {
    pluginHats.refresh()
    pluginToys.refresh()
    userHats.refresh()
    userToys.refresh()
  }

  Timer {
    id: debounce
    interval: 20
    repeat: false
    onTriggered: root.rebuild()
  }

  function schedule() { debounce.restart() }

  MdFolder {
    id: pluginHats
    tag: "hats"
    folder: Qt.resolvedUrl("../Looks/shop/hats")
    onUpdated: root.schedule()
  }

  MdFolder {
    id: pluginToys
    tag: "toys"
    folder: Qt.resolvedUrl("../Looks/shop/toys")
    onUpdated: root.schedule()
  }

  MdFolder {
    id: userHats
    tag: "hats"
    folder: root.userFolder("hats")
    onUpdated: root.schedule()
  }

  MdFolder {
    id: userToys
    tag: "toys"
    folder: root.userFolder("toys")
    onUpdated: root.schedule()
  }
}
