import QtQuick
import qs.Commons
import qs.Ui

// Bar entry for Workspace Switcher: a chip icon. Left click opens the
// Setup > Workspace Switcher settings menu, right click opens the switcher
// itself — swap them with the widget's `click` setting ("menu" | "switcher").
// Show/hide the icon from the settings menu (Show in bar) or
// `switcher-config bar on|off`.
BarWidget {
  id: root
  moduleName: "io.github.woogy7.workspaces"

  readonly property bool primaryIsMenu: !(root.settings && String(root.settings.click || "menu") === "switcher")
  readonly property string menuCommand: "omarchy menu summon setup.workspace-switcher"
  readonly property string switcherCommand: "omarchy-shell shell toggle io.github.woogy7.workspaces"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰕰"   // 󰕰 view-grid
    tooltipText: root.primaryIsMenu ? "Workspace Switcher settings" : "Workspace Switcher"
    onPressed: function(b) {
      if (!root.bar) return
      var secondary = b === Qt.RightButton || b === Qt.MiddleButton
      var openMenu = root.primaryIsMenu !== secondary
      root.bar.run(openMenu ? root.menuCommand : root.switcherCommand)
    }
  }
}
