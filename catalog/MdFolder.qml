import QtQuick
import Qt.labs.folderlistmodel
import Quickshell.Io

// One directory of markdown files. Skips template.md. Emits updated()
// when a file appears, changes, or goes away.
Item {
  id: root

  property string tag: ""
  property url folder
  property var entries: ({})

  signal updated()

  function skipName(name) {
    var n = String(name || "").toLowerCase()
    return n === "template.md" || n === "_template.md"
  }

  function setEntry(path, text) {
    var next = {}
    for (var key in root.entries) {
      if (root.entries.hasOwnProperty(key) && key !== path)
        next[key] = root.entries[key]
    }
    if (text !== null && text !== undefined)
      next[path] = text
    root.entries = next
    root.updated()
  }

  function refresh() {
    var current = root.folder
    root.folder = ""
    root.folder = current
  }

  FolderListModel {
    id: files
    folder: root.folder
    nameFilters: ["*.md"]
    showFiles: true
    showDirs: false
    showDotAndDotDot: false
    showHidden: false
  }

  Instantiator {
    model: files
    delegate: FileView {
      required property string filePath
      required property string fileName
      path: filePath
      watchChanges: true
      printErrors: false
      onLoaded: {
        if (root.skipName(fileName)) return
        root.setEntry(filePath, text() || "")
      }
      Component.onDestruction: root.setEntry(filePath, null)
    }
  }
}
