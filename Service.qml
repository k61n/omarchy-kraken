import QtQuick
import Quickshell.Io

// Keeps `krakenctl watch` running for as long as the plugin is enabled, so saved
// settings come back at login and after resume. The shell creates this when the
// plugin is enabled and destroys it, stopping the watcher, when it's disabled.
Item {
  readonly property string ctl: decodeURIComponent(Qt.resolvedUrl("bin/krakenctl").toString().replace("file://", ""))

  Process {
    id: watcher
    command: [ctl, "watch"]
    running: true
  }

  Timer {
    interval: 5000
    running: !watcher.running
    onTriggered: watcher.running = true
  }
}
