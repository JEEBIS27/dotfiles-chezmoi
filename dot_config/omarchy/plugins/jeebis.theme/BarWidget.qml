import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jeebis.theme"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰸌"
    tooltipText: "クリック: テーマ選択 · ダブルクリック: Aether"
    fixedWidth: Style.bar.iconSlot
    fixedHeight: root.barSize
    horizontalMargin: 0
    verticalPadding: 0
    onPressed: function() {
      if (root.bar) root.bar.run("omarchy menu summon style.theme")
    }
  }
}
