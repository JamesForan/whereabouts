// Test harness: a stand-in for the Omarchy shell that loads Overlay.qml the
// way the shell does and feeds it one fixture's window-list output (see
// tests/qml/run). The overlay is never opened, so nothing appears on screen.
//
// Checks that the list builds and that typing filters it. Results are printed
// as RESULT lines; any QML warning from the plugin fails the run.
import QtQuick
import Quickshell

ShellRoot {
  id: harness

  property var overlay: null

  function fail(message) {
    console.error("RESULT FAIL " + message)
    Qt.quit()
  }

  Component.onCompleted: {
    const component = Qt.createComponent(Quickshell.env("PLUGIN_ENTRY"), Component.PreferSynchronous)
    if (component.status !== Component.Ready) {
      harness.fail("load: " + component.errorString())
      return
    }
    harness.overlay = component.createObject(null, {})
    if (!harness.overlay) {
      harness.fail("createObject returned null")
      return
    }

    const raw = Quickshell.env("WINDOW_LIST_JSON")
    const groups = JSON.parse(raw).groups || []
    const windows = [].concat.apply([], groups.map(function(g) { return g.windows || [] }))
    harness.overlay.load(raw)
    if (harness.overlay.opened) {
      harness.fail("overlay opened itself")
      return
    }
    if (harness.overlay.groups.length !== groups.length) {
      harness.fail("loaded " + harness.overlay.groups.length + " groups, fixture has " + groups.length)
      return
    }
    if (windows.length > 0 && harness.overlay.selectedIndex < 0) {
      harness.fail("no window selected after loading " + windows.length + " windows")
      return
    }
    const named = windows.filter(function(w) { return w.app })[0]
    if (named) {
      harness.overlay.setQuery(String(named.app).split(/\s+/)[0])
      if (harness.overlay.selectedIndex < 0) {
        harness.fail("typing \"" + named.app + "\" matched nothing")
        return
      }
    }
    harness.overlay.setQuery("zz-no-such-window-zz")
    if (harness.overlay.selectedIndex !== -1) {
      harness.fail("a query matching nothing still selected a row")
      return
    }
    harness.overlay.setQuery("")
    console.info("RESULT OK " + groups.length + " groups, " + windows.length + " windows")
    quitTimer.start()
  }

  // Let any delayed callbacks (Qt.callLater) run so their errors show up.
  Timer {
    id: quitTimer
    interval: 300
    onTriggered: Qt.quit()
  }
}
