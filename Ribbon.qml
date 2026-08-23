import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// Workspace ribbon: a calm strip of live workspace previews.
//
// Each card composites the workspace's windows from their real geometry using
// ScreencopyView (hyprland-toplevel-export), so previews reflect the actual
// window contents — including workspaces that are not currently visible.
//
// Summoned through the shell host:
//   omarchy-shell shell toggle io.github.woogy7.workspaces
//
// Settings live inline on the plugin's entry in ~/.config/omarchy/shell.json
// (`plugins[]`); see README.md for the keys and defaults.
Item {
  id: root

  // Injected by the shell host on load.
  property var shell: null
  property var manifest: null

  property bool opened: false        // logical state (drives the fade)
  property bool presented: false     // window mapped (stays true through fade-out)
  property int selectedIndex: 0
  property var entries: []
  // Hover-to-select only reacts to real pointer motion: cards sliding under a
  // resting cursor (carousel recentring) must not steal the selection.
  property real lastPointerX: -1
  property real lastPointerY: -1
  property bool syncCenter: true
  // Hold-to-switch (alt-tab style): opened by a held modifier; a "commit"
  // action (sent by the keybind when the modifier is released) switches.
  property bool holdMode: false
  property bool holdSession: false
  property real pendingCommitAt: 0
  property real openedAt: 0
  property int cycleCount: 0
  property string holdModifier: "super"   // name shown in the hint; from payload "modifier"

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "io.github.woogy7.workspaces"
  readonly property string stateHome: Quickshell.env("HOME") + "/.local/state"
  readonly property string backgroundPath: stateHome + "/omarchy/current/background"

  // ------------------------------------------------------------ settings

  readonly property var settings: {
    var cfg = root.shell && root.shell.shellConfig ? root.shell.shellConfig : null
    var list = cfg && Array.isArray(cfg.plugins) ? cfg.plugins : []
    for (var i = 0; i < list.length; i++) {
      if (list[i] && String(list[i].id) === root.pluginId) return list[i]
    }
    return ({})
  }

  function setting(key, fallback) {
    var v = root.settings[key]
    return (v === undefined || v === null) ? fallback : v
  }
  function settingNumber(key, fallback, min, max) {
    var n = Number(setting(key, fallback))
    if (!isFinite(n)) n = fallback
    if (min !== undefined) n = Math.max(min, n)
    if (max !== undefined) n = Math.min(max, n)
    return n
  }
  function settingBool(key, fallback) {
    var v = setting(key, fallback)
    return v === true || v === "true"
  }

  // "ribbon": cards shrink to fit, selection is kept in view.
  // "carousel": fixed-size cards, the selected card always sits in the middle.
  readonly property string layout: String(setting("layout", "ribbon")) === "carousel" ? "carousel" : "ribbon"
  readonly property bool carousel: layout === "carousel"
  readonly property int previewWidthSetting: settingNumber("previewWidth", 320, 120, 1200)
  readonly property int minPreviewWidthSetting: settingNumber("minPreviewWidth", 200, 80, 1200)
  readonly property int gapSetting: settingNumber("gap", 28, 0, 200)
  readonly property string monitorsSetting: String(setting("monitors", "all")) === "focused" ? "focused" : "all"
  readonly property int minWorkspaces: settingNumber("minWorkspaces", 5, 0, 20)
  readonly property int maxWorkspaces: settingNumber("maxWorkspaces", 10, 1, 50)
  readonly property bool showWallpaper: settingBool("showWallpaper", true)
  readonly property bool showLabels: settingBool("showLabels", true)
  readonly property bool showHints: settingBool("showHints", true)
  readonly property bool hoverSelects: settingBool("hoverSelects", true)
  // What a lone Super+Tab tap (release without cycling further) does:
  // "browse" keeps the switcher open for arrows/Enter; "switch" jumps to the
  // pre-selected next workspace, pure alt-tab style.
  readonly property string tapAction: String(setting("tapAction", "browse")) === "switch" ? "switch" : "browse"
  readonly property bool animations: settingBool("animations", true)
  readonly property int animationDuration: animations ? settingNumber("animationDuration", 160, 0, 2000) : 0
  readonly property int fadeDuration: animations ? settingNumber("fadeDuration", 140, 0, 2000) : 0
  readonly property real selectedScale: settingNumber("selectedScale", 1.0, 0.5, 2.0)
  readonly property real unselectedOpacity: settingNumber("unselectedOpacity", 1.0, 0.1, 1.0)
  readonly property real unselectedScale: settingNumber("unselectedScale", 1.0, 0.5, 1.0)

  // ------------------------------------------------------------ theme

  // Shares the image-picker surface so themes that style the theme/background
  // picker style the ribbon too.
  property color scrim: Color.imagePicker.scrim
  property color foreground: Color.imagePicker.text
  property color selectedBorder: Color.imagePicker.selectedBorder
  property color unselectedBorder: Color.imagePicker.unselectedBorder
  property color cardBackground: Color.background
  property color windowFallback: Util.alpha(Color.foreground, 0.10)
  property string fontFamily: Style.font.menuFamily

  // ------------------------------------------------------------ geometry

  readonly property var focusedMonitor: Hyprland.focusedMonitor
  readonly property real monitorWidth: focusedMonitor ? focusedMonitor.width / Math.max(0.1, focusedMonitor.scale) : 1440
  readonly property real monitorHeight: focusedMonitor ? focusedMonitor.height / Math.max(0.1, focusedMonitor.scale) : 900
  readonly property int preferredCardWidth: Style.space(previewWidthSetting)
  readonly property int minCardWidth: Math.min(preferredCardWidth, Style.space(minPreviewWidthSetting))
  readonly property int cardGap: Style.space(gapSetting)
  readonly property int edgeMargin: Style.space(64)
  readonly property int availableWidth: Math.max(1, panel.width - edgeMargin * 2)
  // Ribbon: shrink cards to keep every workspace on screen, and only scroll
  // once cards would drop below minCardWidth. Carousel: fixed size.
  readonly property int cardWidth: {
    if (root.carousel) return preferredCardWidth
    var n = root.entries.length
    if (n <= 0) return preferredCardWidth
    var fit = Math.floor((availableWidth - (n - 1) * cardGap) / n)
    return Math.max(minCardWidth, Math.min(preferredCardWidth, fit))
  }
  readonly property int cardHeight: Math.round(cardWidth * monitorHeight / Math.max(1, monitorWidth))
  readonly property int cardRadius: Style.cornerRadius
  readonly property int borderWidth: Math.max(2, Style.space(2))
  readonly property int labelSpacing: Style.spacing.sm
  readonly property int labelHeight: showLabels ? Style.font.body + Style.font.caption + labelSpacing * 2 : 0
  // Room for a scaled-up selected card so it is not clipped by the list.
  readonly property int scalePad: Math.ceil(Math.max(cardWidth, cardHeight) * Math.max(0, selectedScale - 1) / 2) + 2

  // ------------------------------------------------------------ model

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }
    return null
  }

  function buildEntries() {
    var focusedMon = Hyprland.focusedMonitor
    var onlyFocused = root.monitorsSetting === "focused" && focusedMon !== null
    var values = Hyprland.workspaces.values
    var existing = {}
    for (var i = 0; i < values.length; i++) existing[values[i].id] = values[i]

    var ids = []
    for (var n = 1; n <= root.minWorkspaces; n++) {
      var ws0 = existing[n]
      // A not-yet-created workspace would land on the focused monitor.
      if (!onlyFocused || !ws0 || ws0.monitor === focusedMon) ids.push(n)
    }
    for (var j = 0; j < values.length; j++) {
      var ws = values[j]
      if (ws.id <= 0 || ws.id > root.maxWorkspaces || ids.indexOf(ws.id) !== -1) continue
      if (onlyFocused && ws.monitor !== focusedMon) continue
      ids.push(ws.id)
    }
    ids.sort(function(a, b) { return a - b })

    var list = []
    for (var k = 0; k < ids.length; k++) list.push({ id: ids[k], workspace: existing[ids[k]] || null })
    root.entries = list

    var focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    var sel = 0
    for (var s = 0; s < list.length; s++) {
      if (list[s].id === focusedId) { sel = s; break }
    }
    root.selectedIndex = sel
  }

  // ------------------------------------------------------------ lifecycle

  // Payload actions (JSON `{"action": ...}`):
  //   (none)      plain open
  //   open-next / open-prev   hold-mode open, pre-selecting the next/prev workspace
  //   next / prev             cycle the selection (opens in hold mode if closed)
  //   commit                  hold mode: switch to the selection (modifier released)
  function open(payloadJson) {
    var args = {}
    if (payloadJson) {
      try { args = JSON.parse(payloadJson) || {} } catch (e) { args = {} }
    }
    var action = String(args.action || "")
    if (args.modifier) {
      // IPC-supplied and only ever displayed; restrict to known modifier names.
      var mod = String(args.modifier).toLowerCase()
      root.holdModifier = ["super", "alt", "ctrl", "shift", "meta", "hyper"].indexOf(mod) !== -1 ? mod : "super"
    }
    var step = (action === "next" || action === "open-next") ? 1
             : (action === "prev" || action === "open-prev") ? -1 : 0
    var hold = action !== "" && action !== "commit"

    if (action === "commit") {
      if (root.opened && root.holdMode) {
        root.holdSession = false
        if (root.tapAction === "browse" && root.cycleCount === 0) {
          // A lone tap: stay open as a plain picker (arrows / Enter / Esc).
          root.holdMode = false
          return
        }
        var quickTap = Date.now() - root.openedAt < 200
        root.activateSelected()
        if (quickTap) { closeTimer.stop(); root.finishClose() }   // no fade flash on a quick tap
        return
      }
      if (root.holdSession) { root.holdSession = false; return }   // user already closed/switched
      root.pendingCommitAt = Date.now()                             // commit raced ahead of open
      return
    }

    if (root.opened) {
      if (step !== 0) {
        // Super+Tab again while open (re)enters hold mode: release will switch.
        if (hold) { root.holdMode = true; root.holdSession = true }
        root.cycleCount += 1
        root.cycleSelection(step)
      }
      return
    }

    // A quick tap whose release beat the open: switch straight away, no UI.
    if (hold && root.tapAction === "switch" && root.pendingCommitAt > 0 && Date.now() - root.pendingCommitAt < 300) {
      root.pendingCommitAt = 0
      root.switchRelative(step)
      return
    }
    root.pendingCommitAt = 0

    closeTimer.stop()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.buildEntries()
    root.lastPointerX = -1
    root.lastPointerY = -1
    root.holdMode = hold
    root.holdSession = hold
    root.openedAt = Date.now()
    root.cycleCount = 0
    if (step !== 0) root.cycleSelection(step)
    root.presented = true
    root.opened = true
    Qt.callLater(function() {
      ribbon.currentIndex = root.selectedIndex
      ribbon.positionViewAtIndex(root.selectedIndex, ListView.Center)
      keyCatcher.forceActiveFocus()
    })
  }

  // Switch relative to the current workspace without showing the ribbon.
  function switchRelative(step) {
    root.buildEntries()
    if (root.entries.length === 0) return
    var n = root.entries.length
    var idx = ((root.selectedIndex + step) % n + n) % n
    var id = root.entries[idx].id
    root.entries = []
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
  }

  function close() {
    if (!root.opened && !root.presented) return
    root.opened = false
    root.holdMode = false
    if (root.fadeDuration > 0) closeTimer.restart()
    else root.finishClose()
  }

  function finishClose() {
    root.presented = false
    root.entries = []
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  Timer {
    id: closeTimer
    interval: root.fadeDuration + 20
    repeat: false
    onTriggered: if (!root.opened) root.finishClose()
  }

  // ------------------------------------------------------------ actions

  function moveSelection(delta) {
    if (root.entries.length === 0) return
    var next = root.selectedIndex + delta
    if (next < 0) next = 0
    if (next >= root.entries.length) next = root.entries.length - 1
    root.selectedIndex = next
  }

  // Wrapping selection move (Tab cycling); arrows use clamping moveSelection.
  function cycleSelection(step) {
    var n = root.entries.length
    if (n === 0) return
    root.selectedIndex = ((root.selectedIndex + step) % n + n) % n
  }

  function selectWorkspaceId(id) {
    for (var i = 0; i < root.entries.length; i++) {
      if (root.entries[i].id === id) { root.selectedIndex = i; return true }
    }
    return false
  }

  function activateSelected() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.entries.length) return
    var id = root.entries[root.selectedIndex].id
    root.close()
    // Hyprland.dispatch() does not speak the Lua-config dispatcher syntax on
    // this Hyprland; shell out like the bar's workspace widget does.
    Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
  }

  // Called from a card on pointer motion (scene coords). Selects without
  // recentring the carousel, so the card stays put under the cursor.
  function pointerMoved(index, sceneX, sceneY) {
    if (!root.opened || !root.hoverSelects) return
    var first = root.lastPointerX < 0
    var moved = Math.abs(sceneX - root.lastPointerX) > 2 || Math.abs(sceneY - root.lastPointerY) > 2
    root.lastPointerX = sceneX
    root.lastPointerY = sceneY
    if (first || !moved || index === root.selectedIndex) return
    root.syncCenter = false
    root.selectedIndex = index
    root.syncCenter = true
  }

  onSelectedIndexChanged: if (root.syncCenter && ribbon.currentIndex !== root.selectedIndex) ribbon.currentIndex = root.selectedIndex

  // Keep window geometry fresh while the ribbon is open: Hyprland only
  // pushes lastIpcObject on refresh, so re-query on layout-affecting events.
  Connections {
    target: Hyprland
    enabled: root.presented
    function onRawEvent(event) {
      var n = event.name
      if (n === "movewindow" || n === "movewindowv2" || n === "changefloatingmode" ||
          n === "fullscreen" || n === "openwindow" || n === "closewindow" ||
          n === "windowtitle" || n === "windowtitlev2") {
        Hyprland.refreshToplevels()
      }
    }
  }

  // ------------------------------------------------------------ window

  PanelWindow {
    id: panel
    visible: root.presented
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-workspace-ribbon"
    WlrLayershell.layer: WlrLayer.Overlay
    // Constant: flipping interactivity to None on close makes Hyprland refocus
    // its last window, which can yank the workspace back after we switched.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: content
      anchors.fill: parent
      opacity: root.opened ? 1 : 0
      Behavior on opacity {
        enabled: root.fadeDuration > 0
        NumberAnimation { duration: root.fadeDuration; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        color: root.scrim
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
        onWheel: function(wheel) {
          var delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x
          if (delta === 0) return
          if (!root.carousel && ribbon.scrollable) ribbon.scrollBy(delta > 0 ? -1 : 1)
          else root.moveSelection(delta > 0 ? -1 : 1)
          wheel.accepted = true
        }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var key = event.key
          if (key === Qt.Key_Escape) {
            root.close()
          } else if ((key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) || key === Qt.Key_Backtab) {
            root.cycleSelection(-1)
          } else if (key === Qt.Key_Tab) {
            root.cycleSelection(1)
          } else if (key === Qt.Key_Left || key === Qt.Key_H) {
            root.moveSelection(-1)
          } else if (key === Qt.Key_Right || key === Qt.Key_L || key === Qt.Key_Space) {
            root.moveSelection(1)
          } else if (key === Qt.Key_Home) {
            root.selectedIndex = 0
          } else if (key === Qt.Key_End) {
            root.selectedIndex = Math.max(0, root.entries.length - 1)
          } else if (key === Qt.Key_Return || key === Qt.Key_Enter) {
            root.activateSelected()
          } else if (key >= Qt.Key_0 && key <= Qt.Key_9) {
            var id = key === Qt.Key_0 ? 10 : (key - Qt.Key_0)
            if (root.selectWorkspaceId(id)) root.activateSelected()
          } else {
            return
          }
          event.accepted = true
        }
      }

      ListView {
        id: ribbon

        readonly property int contentTotal: count * root.cardWidth + Math.max(0, count - 1) * root.cardGap
        readonly property bool scrollable: root.carousel || contentTotal > root.availableWidth
        readonly property int sidePad: root.carousel ? Math.max(0, Math.round((width - root.cardWidth) / 2)) : 0

        width: scrollable ? root.availableWidth : contentTotal
        height: root.scalePad * 2 + root.cardHeight + (root.showLabels ? root.labelSpacing + root.labelHeight : 0)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Math.round(root.labelHeight / 2)

        orientation: ListView.Horizontal
        spacing: root.cardGap
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: scrollable
        flickDeceleration: 4000
        maximumFlickVelocity: 3000
        cacheBuffer: root.cardWidth * 12

        // Carousel: pad both ends so the first/last card can sit in the centre.
        header: Item { width: ribbon.sidePad; height: 1 }
        footer: Item { width: ribbon.sidePad; height: 1 }

        model: root.entries
        highlightRangeMode: root.carousel ? ListView.StrictlyEnforceRange : ListView.ApplyRange
        preferredHighlightBegin: Math.max(0, (width - root.cardWidth) / 2)
        preferredHighlightEnd: preferredHighlightBegin + root.cardWidth
        highlightMoveDuration: root.animationDuration
        highlightMoveVelocity: -1
        highlightFollowsCurrentItem: true
        snapMode: root.carousel ? ListView.SnapOneItem : ListView.NoSnap

        // Flicking the carousel moves the selection with it.
        onCurrentIndexChanged: {
          if (root.carousel && currentIndex >= 0 && currentIndex !== root.selectedIndex) root.selectedIndex = currentIndex
        }

        function scrollBy(direction) {
          if (!scrollable) return
          var step = root.cardWidth + root.cardGap
          var target = contentX + direction * step
          var max = Math.max(0, contentWidth - width)
          scrollAnim.to = Math.max(0, Math.min(max, target))
          scrollAnim.restart()
        }

        NumberAnimation {
          id: scrollAnim
          target: ribbon
          property: "contentX"
          duration: root.animationDuration
          easing.type: Easing.OutCubic
        }

        delegate: Item {
          id: card

          required property var modelData
          required property int index

          readonly property int workspaceId: modelData.id
          readonly property var workspace: modelData.workspace
          readonly property var monitor: workspace && workspace.monitor ? workspace.monitor : Hyprland.focusedMonitor
          readonly property real monX: monitor ? monitor.x : 0
          readonly property real monY: monitor ? monitor.y : 0
          readonly property real monW: monitor ? monitor.width / Math.max(0.1, monitor.scale) : root.monitorWidth
          readonly property real monH: monitor ? monitor.height / Math.max(0.1, monitor.scale) : root.monitorHeight
          readonly property real k: Math.min(root.cardWidth / Math.max(1, monW), root.cardHeight / Math.max(1, monH))
          readonly property bool selected: index === root.selectedIndex
          readonly property bool current: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === workspaceId
          readonly property var toplevels: workspace ? workspace.toplevels.values : []
          readonly property string lastTitle: workspace && workspace.lastIpcObject && workspace.lastIpcObject.lastwindowtitle ? String(workspace.lastIpcObject.lastwindowtitle) : ""

          width: root.cardWidth
          height: ribbon.height
          z: selected ? 1 : 0

          Item {
            id: preview
            width: root.cardWidth
            height: root.cardHeight
            y: root.scalePad
            scale: card.selected ? root.selectedScale : root.unselectedScale
            opacity: card.selected ? 1 : root.unselectedOpacity
            // Flatten the card before opacity/scale apply; otherwise QML fades
            // each child separately and the wallpaper bleeds through windows.
            layer.enabled: true
            layer.smooth: true
            Behavior on scale { enabled: root.animationDuration > 0; NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic } }
            Behavior on opacity { enabled: root.animationDuration > 0; NumberAnimation { duration: root.animationDuration } }

            Rectangle {
              id: maskShape
              anchors.fill: parent
              radius: root.cardRadius
              color: "black"
              visible: false
              layer.enabled: true
            }

            Item {
              id: surface
              anchors.fill: parent
              layer.enabled: root.cardRadius > 0
              layer.smooth: true
              layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskShape
                maskThresholdMin: 0.3
                maskSpreadAtMin: 0.3
              }

              Rectangle {
                anchors.fill: parent
                color: root.cardBackground
              }

              Image {
                anchors.fill: parent
                visible: root.showWallpaper
                source: root.presented && root.showWallpaper ? "file://" + root.backgroundPath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: root.cardWidth * 2
                sourceSize.height: root.cardHeight * 2
                opacity: card.toplevels.length > 0 ? 0.85 : 0.55
              }

              Item {
                id: windows
                width: Math.round(card.monW * card.k)
                height: Math.round(card.monH * card.k)
                anchors.centerIn: parent

                Repeater {
                  model: card.toplevels

                  Item {
                    id: win

                    required property var modelData

                    readonly property var ipc: modelData.lastIpcObject || ({})
                    readonly property bool hasGeometry: ipc.at !== undefined && ipc.size !== undefined
                    readonly property bool floating: ipc.floating === true
                    readonly property bool fullscreen: !!ipc.fullscreen
                    readonly property int focusOrder: ipc.focusHistoryID !== undefined ? Number(ipc.focusHistoryID) : 99

                    visible: hasGeometry && !(ipc.hidden === true)
                    x: hasGeometry ? Math.round((ipc.at[0] - card.monX) * card.k) : 0
                    y: hasGeometry ? Math.round((ipc.at[1] - card.monY) * card.k) : 0
                    width: hasGeometry ? Math.max(2, Math.round(ipc.size[0] * card.k)) : 0
                    height: hasGeometry ? Math.max(2, Math.round(ipc.size[1] * card.k)) : 0
                    z: (fullscreen ? 2000 : floating ? 1000 : 0) + (500 - Math.min(499, focusOrder))

                    ScreencopyView {
                      id: capture
                      anchors.fill: parent
                      captureSource: win.modelData.wayland
                      live: root.presented
                      paintCursor: false
                      constraintSize: Qt.size(width * 2, height * 2)
                    }

                    Rectangle {
                      anchors.fill: parent
                      visible: !capture.hasContent
                      color: root.windowFallback
                      border.width: 1
                      border.color: Util.alpha(root.foreground, 0.25)

                      Text {
                                                  textFormat: Text.PlainText
anchors.centerIn: parent
                        width: parent.width - Style.space(8)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: win.modelData.title || ""
                        color: Util.alpha(root.foreground, 0.7)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        visible: parent.width > Style.space(48)
                      }
                    }
                  }
                }
              }
            }

            // Border drawn above the masked surface so it stays crisp.
            Rectangle {
              anchors.fill: parent
              radius: root.cardRadius
              color: "transparent"
              border.width: root.borderWidth
              border.color: card.selected ? root.selectedBorder
                          : cardHover.containsMouse ? Util.alpha(root.selectedBorder, 0.55)
                          : root.unselectedBorder
              Behavior on border.color { enabled: root.animationDuration > 0; ColorAnimation { duration: 120 } }
            }

            MouseArea {
              id: cardHover
              anchors.fill: parent
              hoverEnabled: true
              onPositionChanged: function(mouse) {
                var p = mapToItem(null, mouse.x, mouse.y)
                root.pointerMoved(card.index, p.x, p.y)
              }
              onClicked: {
                root.selectedIndex = card.index
                root.activateSelected()
              }
            }
          }

          Column {
            visible: root.showLabels
            anchors.top: preview.bottom
            anchors.topMargin: root.labelSpacing + root.scalePad
            anchors.horizontalCenter: preview.horizontalCenter
            width: preview.width
            spacing: Math.round(root.labelSpacing / 2)
            opacity: card.selected ? 1 : root.unselectedOpacity

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(6)

              Rectangle {
                width: Style.space(6)
                height: width
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: root.selectedBorder
                visible: card.current
              }

              Text {
                                  textFormat: Text.PlainText
text: String(card.workspaceId)
                color: card.selected ? root.foreground : Util.alpha(root.foreground, 0.7)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.weight: card.selected ? Font.DemiBold : Font.Normal
              }
            }

            Text {
                              textFormat: Text.PlainText
width: parent.width
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideMiddle
              text: card.toplevels.length === 0 ? "Empty"
                  : card.lastTitle !== "" ? card.lastTitle
                  : (card.toplevels.length === 1 ? "1 window" : card.toplevels.length + " windows")
              color: Util.alpha(root.foreground, card.selected ? 0.75 : 0.45)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }

      Text {
                  textFormat: Text.PlainText
visible: root.showHints
        anchors.horizontalCenter: ribbon.horizontalCenter
        anchors.top: ribbon.bottom
        anchors.topMargin: Style.space(18)
        text: root.holdMode
            ? (root.tapAction === "browse" && root.cycleCount === 0
                ? "tab cycle   release " + root.holdModifier + " to browse   esc cancel"
                : "tab cycle   release " + root.holdModifier + " to switch   esc cancel")
            : "\u2190 \u2192 select   \u21B5 switch   1\u20139 jump   esc close"
        color: Util.alpha(root.foreground, 0.4)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      // Soft fades at the ribbon edges while there is more to scroll.
      Rectangle {
        anchors.left: ribbon.left
        anchors.top: ribbon.top
        anchors.topMargin: root.scalePad
        height: root.cardHeight
        width: root.edgeMargin
        visible: ribbon.scrollable
        opacity: ribbon.contentX > 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: root.scrim }
          GradientStop { position: 1.0; color: Util.alpha(root.scrim, 0) }
        }
      }

      Rectangle {
        anchors.right: ribbon.right
        anchors.top: ribbon.top
        anchors.topMargin: root.scalePad
        height: root.cardHeight
        width: root.edgeMargin
        visible: ribbon.scrollable
        opacity: ribbon.contentX < ribbon.contentWidth - ribbon.width - 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: Util.alpha(root.scrim, 0) }
          GradientStop { position: 1.0; color: root.scrim }
        }
      }
    }
  }
}
