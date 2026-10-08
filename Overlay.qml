import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Get Lost: every open window grouped by workspace, in the Omarchy menu style.
// Toggle with `omarchy-shell shell toggle <plugin id>` (see README for a key
// binding). Data comes from the bundled `window-list` script (JSON);
// Enter/click focuses via `window-list focus`.
// Keys: 1-9 show one workspace, 0/Backspace show all, ↑↓ (or j/k, Tab) move,
// Enter go, Esc clears the workspace filter and then closes.
// Updates live while open: re-reads on any Hyprland event, plus a 1s poll
// because a workspace layout switch (dwindle/scrolling) may not emit one.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool loaded: false
  property string loadError: ""
  property var groups: []
  property string filterKey: ""
  property int selectedIndex: -1
  property string lastRaw: ""
  property bool refreshPending: false
  // The data script ships next to this file in the plugin folder.
  property string scriptPath: decodeURIComponent(Qt.resolvedUrl("window-list").toString().replace(/^file:\/\//, ""))

  // Same surface tokens as the Omarchy menu, so themes style both alike.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  property int headerRowHeight: Math.max(Style.space(38), Style.font.title + Style.space(16))
  property int windowRowHeight: Math.max(Style.space(40), Style.font.body + Style.spacing.rowPaddingX * 2)
  property int footerHeight: Style.font.caption + Style.space(8)
  property int listHeight: 0
  property int cardWidth: Math.min(Style.space(620), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(listHeight + footerHeight + contentSpacing + contentMargin * 2 + Style.space(8),
                                    panel.height - Style.gapsOut * 2)

  function open(payloadJson) {
    root.opened = true
    root.loaded = false
    root.loadError = ""
    root.filterKey = ""
    root.lastRaw = ""
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "jamesforan.getlost")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function refresh() {
    if (loader.running) {
      root.refreshPending = true
      return
    }
    loader.collected = ""
    loader.running = true
  }

  function load(raw) {
    if (raw === root.lastRaw) return
    root.lastRaw = raw
    try {
      root.groups = JSON.parse(raw).groups || []
    } catch (e) {
      root.groups = []
      root.loadError = "Couldn't list windows"
    }
    root.rebuild()
    root.loaded = true
  }

  // Keeps the cursor on the same window across live refreshes.
  function rebuild() {
    var keepAddress = ""
    if (root.selectedIndex >= 0 && root.selectedIndex < displayModel.count)
      keepAddress = displayModel.get(root.selectedIndex).address
    var keptIndex = -1
    displayModel.clear()
    var height = 0
    var firstWindow = -1
    var currentWindow = -1
    for (var g = 0; g < root.groups.length; g++) {
      var group = root.groups[g]
      if (root.filterKey && group.key !== root.filterKey) continue
      displayModel.append({
        kind: "header", key: group.key || "", shortcut: group.shortcut || "", title: group.title || "",
        monitor: group.monitor || "", layout: group.layout || "", current: !!group.current,
        empty: !!group.empty, onScreen: true,
        icon: "", app: "", windowTitle: "", winState: "", address: ""
      })
      height += root.headerRowHeight
      var windows = group.windows || []
      for (var w = 0; w < windows.length; w++) {
        var win = windows[w]
        if (firstWindow < 0) firstWindow = displayModel.count
        if (group.current && currentWindow < 0) currentWindow = displayModel.count
        if (keepAddress && win.address === keepAddress) keptIndex = displayModel.count
        displayModel.append({
          kind: "window", key: "", shortcut: "", title: "", monitor: "", layout: "", current: false, empty: false,
          onScreen: win.onScreen !== false,
          icon: win.icon || "", app: win.app || "", windowTitle: win.title || "",
          winState: win.state || "", address: win.address || ""
        })
        height += root.windowRowHeight
      }
    }
    if (displayModel.count === 0) height = root.windowRowHeight * 2
    root.listHeight = height
    var kept = keptIndex >= 0
    root.selectedIndex = kept ? keptIndex : (currentWindow >= 0 ? currentWindow : firstWindow)
    if (kept) return
    Qt.callLater(function() {
      if (root.selectedIndex >= 0) list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      else list.positionViewAtBeginning()
    })
  }

  function setFilter(key) {
    root.filterKey = key
    root.rebuild()
  }

  function move(delta) {
    var count = displayModel.count
    if (count === 0) return
    var i = root.selectedIndex
    for (var step = 0; step < count; step++) {
      i = (i + delta + count) % count
      if (displayModel.get(i).kind === "window") {
        root.selectedIndex = i
        list.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  function activate(index) {
    if (index < 0 || index >= displayModel.count) return
    var row = displayModel.get(index)
    if (row.kind !== "window" || !row.address) return
    root.dismiss()
    Quickshell.execDetached([root.scriptPath, "focus", row.address])
  }

  ListModel { id: displayModel }

  Process {
    id: loader
    property string collected: ""
    command: [root.scriptPath]
    stdout: SplitParser {
      onRead: function(data) { loader.collected += data + "\n" }
    }
    onExited: function(exitCode) {
      if (root.refreshPending) {
        root.refreshPending = false
        Qt.callLater(root.refresh)
      }
      if (exitCode !== 0) {
        root.groups = []
        root.loadError = "window-list failed (exit " + exitCode + ")"
        root.rebuild()
        root.loaded = true
      } else {
        root.load(loader.collected)
      }
    }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.opened) debounce.restart()
    }
  }

  Timer {
    id: debounce
    interval: 60
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened && root.loaded
    onTriggered: root.refresh()
  }

  PanelWindow {
    id: panel
    visible: root.opened && root.loaded
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "getlost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    onVisibleChanged: if (visible) keyCatcher.forceActiveFocus()

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var k = event.key
          if (k === Qt.Key_Escape) {
            if (root.filterKey) root.setFilter("")
            else root.dismiss()
          } else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
            root.setFilter(String(k - Qt.Key_0))
          } else if (k === Qt.Key_0 || k === Qt.Key_Backspace) {
            root.setFilter("")
          } else if (k === Qt.Key_Down || k === Qt.Key_J || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))) {
            root.move(1)
          } else if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) {
            root.move(-1)
          } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            root.activate(root.selectedIndex)
          } else {
            return
          }
          event.accepted = true
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: parent.height - root.footerHeight - root.contentSpacing

          ListView {
            id: list
            anchors.fill: parent
            model: displayModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
              id: row
              required property int index
              required property string kind
              required property string key
              required property string shortcut
              required property string title
              required property string monitor
              required property string layout
              required property bool onScreen
              required property bool current
              required property bool empty
              required property string icon
              required property string app
              required property string windowTitle
              required property string winState
              required property string address

              readonly property bool isHeader: kind === "header"
              readonly property bool hasCursor: !isHeader && index === root.selectedIndex

              width: ListView.view.width
              height: isHeader ? root.headerRowHeight : root.windowRowHeight

              // Workspace header: "Workspace 4 · Laptop · scrolling · current", its shortcut on the right.
              Item {
                visible: row.isHeader
                anchors.fill: parent
                opacity: row.empty ? 0.45 : 1

                Text {
                  id: headerTitle
                  textFormat: Text.PlainText
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(8)
                  anchors.bottom: parent.bottom
                  anchors.bottomMargin: Style.space(6)
                  text: row.title
                  color: row.current ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.left: headerTitle.right
                  anchors.baseline: headerTitle.baseline
                  text: [row.monitor, row.layout, row.empty ? "empty" : "", row.current ? "current" : ""].filter(function(s) { return s }).map(function(s) { return "  ·  " + s }).join("")
                  color: root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.baseline: headerTitle.baseline
                  text: row.shortcut
                  color: root.foreground
                  opacity: 0.45
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }

              // Window row: icon, "App · title", state on the right. Dimmed when the
              // window isn't visible (behind a full-width window or scrolled off-screen).
              BorderSurface {
                visible: !row.isHeader
                opacity: row.onScreen || row.hasCursor ? 1 : 0.45
                anchors.fill: parent
                radius: root.cornerRadius
                color: row.hasCursor ? root.selectedBackground : "transparent"
                borderSpec: Border.none()

                Text {
                  id: iconText
                  textFormat: Text.PlainText
                  text: row.icon
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.iconLarge
                  width: Style.space(36)
                  horizontalAlignment: Text.AlignHCenter
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(22)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: stateText
                  textFormat: Text.PlainText
                  text: row.winState
                  color: row.hasCursor ? root.selectedText : root.foreground
                  opacity: 0.55
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  textFormat: Text.PlainText
                  text: row.windowTitle ? row.app + "  ·  " + row.windowTitle : row.app
                  color: row.hasCursor ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  anchors.left: iconText.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: stateText.left
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  // Only real mouse movement moves the cursor; a live refresh that
                  // redraws a row under a resting pointer must not steal it.
                  onPositionChanged: root.selectedIndex = row.index
                  onClicked: root.activate(row.index)
                }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            visible: displayModel.count === 0
            text: root.loadError || (root.filterKey ? "Workspace " + root.filterKey + " is empty" : "No open windows")
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          height: root.footerHeight
          horizontalAlignment: Text.AlignHCenter
          text: root.filterKey
            ? "0 or Esc show all   ·   ↑↓ move   ·   Enter go"
            : "1–9 filter workspace   ·   ↑↓ move   ·   Enter go   ·   Esc close"
          color: root.foreground
          opacity: 0.45
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
