import "../jeebis.bar/AnimationTiming.js" as Timing
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jeebis.notifications"

  readonly property string helper: Quickshell.env("HOME") + "/.config/omarchy/plugins/jeebis.notifications/notifications.py"
  readonly property string notificationDir: Quickshell.env("HOME") + "/.local/state/omarchy/notifications"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/notification-island"
  property int unreadCount: 0
  property double latestTimestamp: 0
  property var unreadItems: []
  property var historyItems: []
  property bool showingHistory: false
  // The host underline follows the selected button, not the whole island.
  readonly property real openPanelIndicatorWidth: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property real openPanelIndicatorCenterX: showingHistory
    ? historyButton.x + historyButton.width / 2
    : bellButton.x + bellButton.width / 2 + root.bellOpticalOffsetX
  // Keep a stable reading session even if a popup expires or history is trimmed.
  property var displayedItems: []
  property bool refreshPending: false
  property bool opened: false
  readonly property bool islandRequested: !vertical && (unreadCount > 0 || opened)
  property real islandRevealProgress: islandRequested ? 1 : 0
  readonly property bool clearRequested: islandHover.hovered || opened
  property real clearProgress: clearRequested ? 1 : 0
  property real historyProgress: opened ? 1 : 0
  Behavior on historyProgress {
    NumberAnimation { duration: root.opened ? Timing.notificationHistory.enteringMs : Timing.notificationHistory.leavingMs; easing.type: Easing.OutCubic }
  }
  readonly property color foreground: bar ? bar.barForeground : Color.bar.text
  readonly property color mutedForeground: Color.muted
  // A small optical correction balances this bell glyph inside the capsule.
  readonly property real bellOpticalOffsetX: -Style.spaceReal(0)

  visible: islandRevealProgress > 0
  clip: true
  implicitWidth: (Style.bar.iconSlot + (Style.bar.iconSlot + Style.space(3)) * (clearProgress + historyProgress)) * islandRevealProgress
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    NumberAnimation { duration: root.islandRequested ? Timing.notificationIsland.enteringMs : Timing.notificationIsland.leavingMs; easing.type: Easing.InOutCubic }
  }
  Behavior on clearProgress {
    NumberAnimation { duration: root.clearRequested ? Timing.notificationClear.enteringMs : Timing.notificationClear.leavingMs; easing.type: Easing.OutCubic }
  }

  HoverHandler { id: islandHover }

  function acceptSnapshot(output) {
    try {
      var snapshot = JSON.parse(String(output))
      root.unreadItems = Array.isArray(snapshot.unreadItems) ? snapshot.unreadItems : []
      root.historyItems = Array.isArray(snapshot.historyItems) ? snapshot.historyItems : []
      root.unreadCount = root.unreadItems.length
      root.latestTimestamp = Number(snapshot.latestTimestamp) || 0
      if (root.opened) {
        var kept = root.displayedItems.slice()
        var byKey = ({})
        for (var i = 0; i < kept.length; i++) byKey[kept[i].key] = i
        var incoming = root.showingHistory ? root.historyItems : root.unreadItems
        for (var j = 0; j < incoming.length; j++) {
          var entry = incoming[j]
          if (byKey[entry.key] !== undefined) kept[byKey[entry.key]] = entry
          else { byKey[entry.key] = kept.length; kept.push(entry) }
        }
        kept.sort(function(a, b) { return Number(b.timestamp) - Number(a.timestamp) })
        // Avoid rebuilding the reading list when only popup file locations change.
        if (JSON.stringify(kept) !== JSON.stringify(root.displayedItems)) root.displayedItems = kept
      }
      return true
    } catch (error) {
      console.warn("notification island: invalid snapshot", error)
      return false
    }
  }

  function refresh() {
    if (snapshotProcess.running) { root.refreshPending = true; return }
    root.refreshPending = false
    snapshotProcess.running = true
  }

  function showPanel(history) {
    if (root.opened && root.showingHistory === history) return
    root.showingHistory = history
    root.displayedItems = (history ? root.historyItems : root.unreadItems).slice()
    root.opened = true
    notificationScroll.contentY = 0
    root.refresh()
  }
  function open() { root.showPanel(false) }
  function openHistory() { root.showPanel(true) }
  function close() { root.opened = false }
  function toggle() { if (root.opened && !root.showingHistory) root.close(); else root.open() }
  function toggleHistory() { if (root.opened && root.showingHistory) root.close(); else root.openHistory() }
  function closeForPopoutSwitch() { root.close() }

  function markAllRead() {
    if (markReadProcess.running) return
    var cutoff = root.latestTimestamp
    for (var i = 0; i < root.displayedItems.length; i++)
      cutoff = Math.max(cutoff, Number(root.displayedItems[i].timestamp) || 0)
    // A notification newer than this snapshot must remain unread.
    markReadProcess.command = ["/usr/bin/python3", root.helper, "--mark-read", String(cutoff)]
    markReadProcess.running = true
  }

  Process {
    id: snapshotProcess
    command: ["/usr/bin/python3", root.helper]
    stdout: StdioCollector { onStreamFinished: root.acceptSnapshot(text) }
    onExited: if (root.refreshPending) refreshDebounce.restart()
  }
  Process {
    id: markReadProcess
    stdout: StdioCollector {
      onStreamFinished: if (root.acceptSnapshot(text)) root.close()
    }
    onExited: refreshDebounce.restart()
  }

  FileView { path: root.notificationDir; watchChanges: true; printErrors: false; onFileChanged: refreshDebounce.restart() }
  FileView { path: root.notificationDir + "/history"; watchChanges: true; printErrors: false; onFileChanged: refreshDebounce.restart() }
  FileView { path: root.stateDir; watchChanges: true; printErrors: false; onFileChanged: refreshDebounce.restart() }

  Timer { id: refreshDebounce; interval: 80; onTriggered: root.refresh() }
  Timer {
    interval: 10000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "jeebis.notifications"
    function open(): void { root.open() }
    function openHistory(): void { root.openHistory() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function markAllRead(): void { root.markAllRead() }
    function refresh(): void { root.broadcast("refresh") }
    function state(): string {
      return JSON.stringify({ unreadCount: root.unreadCount, latestTimestamp: root.latestTimestamp,
        opened: root.opened, view: root.showingHistory ? "history" : "unread", displayedKeys: root.displayedItems.map(function(item) { return item.key }),
        visible: root.visible, progress: root.islandRevealProgress,
        clearVisible: clearButton.visible, historyVisible: historyButton.visible,
        clearProgress: root.clearProgress })
    }
  }

  WidgetButton {
    id: clearButton
    anchors.right: historyButton.left
    anchors.rightMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "×"
    fontSize: Style.bar.iconFont
    foreground: root.foreground
    tooltipText: "すべての通知を既読にする"
    visible: root.clearProgress > 0
    interactive: root.clearRequested && !markReadProcess.running
    fixedWidth: Style.bar.iconSlot
    fixedHeight: root.barSize
    horizontalMargin: 0
    verticalPadding: 0
    opacity: root.islandRevealProgress * root.clearProgress
    onPressed: function() { root.markAllRead() }
  }

  WidgetButton {
    id: historyButton
    // Center the visible glyph, matching the bell's optical alignment.
    labelVisible: false
    TextMetrics {
      id: historyMetrics
      font.family: historyButton.fontFamily
      font.pixelSize: historyButton.fontSize
      text: historyButton.text
    }
    Text {
      anchors.centerIn: parent
      anchors.horizontalCenterOffset: implicitWidth / 2 - (historyMetrics.tightBoundingRect.x + historyMetrics.tightBoundingRect.width / 2)
      anchors.verticalCenterOffset: implicitHeight / 2 - (baselineOffset + historyMetrics.tightBoundingRect.y + historyMetrics.tightBoundingRect.height / 2)
      text: historyButton.text
      font.family: historyButton.fontFamily
      font.pixelSize: historyButton.fontSize
      color: historyButton.foreground
      renderType: Text.NativeRendering
    }
    anchors.right: bellButton.left
    anchors.rightMargin: Style.space(3) * root.historyProgress
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "󰋚"
    fontSize: Style.bar.iconFont
    foreground: root.foreground
    tooltipText: "通知履歴を表示"
    visible: root.historyProgress > 0
    interactive: root.opened
    fixedWidth: Style.bar.iconSlot
    width: Style.bar.iconSlot * root.historyProgress
    fixedHeight: root.barSize
    horizontalMargin: 0
    verticalPadding: 0
    opacity: root.islandRevealProgress * root.historyProgress
    onPressed: function() { root.toggleHistory() }
  }

  WidgetButton {
    id: bellButton
    // Center the bell's actual ink, rather than the font's line box.
    labelVisible: false
    fontSize: Style.bar.iconFont

    TextMetrics {
      id: bellMetrics
      font.family: bellButton.fontFamily
      font.pixelSize: bellButton.fontSize
      text: bellButton.text
    }
    Text {
      id: bellGlyph
      anchors.centerIn: parent
      anchors.alignWhenCentered: false
      anchors.horizontalCenterOffset: implicitWidth / 2 - (bellMetrics.tightBoundingRect.x + bellMetrics.tightBoundingRect.width / 2) + root.bellOpticalOffsetX
      anchors.verticalCenterOffset: implicitHeight / 2 - (baselineOffset + bellMetrics.tightBoundingRect.y + bellMetrics.tightBoundingRect.height / 2)
      text: bellButton.text
      font.family: bellButton.fontFamily
      font.pixelSize: bellButton.fontSize
      color: bellButton.foreground
      renderType: Text.NativeRendering
    }
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    bar: root.bar
    text: "󰂚"
    foreground: root.foreground
    tooltipText: "未読通知 " + root.unreadCount + "件 · クリックして表示"
    fixedWidth: Style.bar.iconSlot
    fixedHeight: root.barSize
    horizontalMargin: 0
    verticalPadding: 0
    opacity: root.islandRevealProgress
    onPressed: function() { root.toggle() }
  }

  KeyboardPanel {
    id: notificationPanel
    anchorItem: bellButton
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: notificationPanel.fittedContentWidth(Style.space(450))
    contentHeight: notificationPanel.fittedContentHeight(panelContent.implicitHeight, Math.min(Style.space(600), notificationPanel.screenH * 0.75))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onDeleteRequested: root.markAllRead()
      onMoveRequested: function(dx, dy) {
        notificationScroll.contentY = Math.max(0, Math.min(notificationScroll.contentHeight - notificationScroll.height,
          notificationScroll.contentY + dy * Style.space(45)))
      }
      onTabRequested: function(direction) {
        if (root.bar) root.bar.switchPanelFrom(root, direction)
      }

      Flickable {
        id: notificationScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelContent.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: panelContent
          width: notificationScroll.width
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              text: root.showingHistory ? "通知履歴" : "未読通知"
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.body
              font.bold: true
            }
            Text {
              text: root.displayedItems.length + "件"
              color: root.mutedForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.bodySmall
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            visible: root.displayedItems.length === 0
            text: root.showingHistory ? "通知履歴はありません" : "未読の通知はありません"
            color: root.mutedForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
          }

          Repeater {
            model: root.displayedItems
            delegate: Rectangle {
              id: notificationCard
              required property var modelData
              width: panelContent.width
              height: cardContent.implicitHeight + Style.space(20)
              radius: Style.cornerRadius
              color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.045)
              border.width: 1
              border.color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.12)

              Column {
                id: cardContent
                x: Style.space(10)
                y: Style.space(10)
                width: parent.width - Style.space(20)
                spacing: Style.space(6)

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Text {
                    width: parent.width - receivedAt.implicitWidth - parent.spacing
                    text: (root.showingHistory && notificationCard.modelData.unread ? "● " : "") + notificationCard.modelData.app
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: root.mutedForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                  Text {
                    id: receivedAt
                    text: Qt.formatDateTime(new Date(Number(notificationCard.modelData.timestamp)), "MM/dd HH:mm")
                    color: root.mutedForeground
                    font.family: root.bar ? root.bar.fontFamily : Style.font.family
                    font.pixelSize: Style.font.bodySmall
                  }
                }
                Text {
                  width: parent.width
                  text: notificationCard.modelData.summary
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  color: root.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  width: parent.width
                  visible: text !== ""
                  text: notificationCard.modelData.body
                  textFormat: Text.PlainText
                  wrapMode: Text.Wrap
                  color: root.foreground
                  font.family: root.bar ? root.bar.fontFamily : Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }
        }
      }
    }
  }
}
