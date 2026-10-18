import "../jeebis.bar/AnimationTiming.js" as Timing
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "../jeebis.bar/AgentModel.js" as AgentModel

BarWidget {
  id: root
  moduleName: "jeebis.agent-launchers"
  property bool expanded: false
  property bool pointerHeld: false
  property bool activitySequence: false
  property int activityPhase: 0
  property var transitionFromRunning: ({})

  function updateExpansion() {
    expanded = pointerHeld || (activitySequence && activityPhase < 2)
  }
  function playTransition(kind, opening) {
    var starts = activitySequence && activityPhase === 0 ? Object.assign({}, transitionFromRunning) : ({})
    // Opening starts muted, closing starts lit; phase 1 uses actual state.
    starts[kind] = !opening
    transitionFromRunning = starts
    activityPlayback.stop()
    exitTimer.stop()
    activitySequence = true
    activityPhase = 0
    updateExpansion()
    activityPlayback.start()
  }
  function playOpen(kind) { playTransition(kind, true) }
  function playExit(kind) { playTransition(kind, false) }
  SequentialAnimation {
    id: activityPlayback
    PauseAnimation { duration: Timing.agentActivity.preparingMs }
    ScriptAction { script: root.activityPhase = 1 }
    PauseAnimation { duration: Timing.agentActivity.changingMs + Timing.agentActivity.presentMs }
    ScriptAction { script: { root.activityPhase = 2; root.updateExpansion() } }
    // 収納が完了してから、Agentアイコンだけの表示を保つ。
    PauseAnimation { duration: Timing.agentActivity.collapsingMs + Timing.agentActivity.settledMs }
    ScriptAction {
      script: {
        root.activitySequence = false
        root.transitionFromRunning = ({})
        root.updateExpansion()
      }
    }
  }
  property real islandRevealProgress: expanded && !vertical ? 1 : 0
  readonly property var runningKinds: {
    var kinds = ({})
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < clients.length; i++) {
      var kind = AgentModel.kind(clients[i])
      if (kind) kinds[kind] = true
    }
    return kinds
  }
  visible: islandRevealProgress > 0
  clip: true
  implicitWidth: (buttons.implicitWidth + Style.space(3)) * islandRevealProgress
  // Measure the fully expanded row even while its visual width is zero.
  readonly property real hoverTargetWidth: Math.max(buttons.implicitWidth,
    chatgptMetrics.advanceWidth + codexMetrics.advanceWidth + 4 * Style.spaceReal(6) + Style.space(3)) + Style.space(3)
  TextMetrics {
    id: chatgptMetrics
    text: "ChatGPT"
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
  TextMetrics {
    id: codexMetrics
    text: "Codex"
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.bodySmall
  }
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    NumberAnimation { duration: root.expanded ? Timing.agentActivity.expandingMs : Timing.agentActivity.collapsingMs; easing.type: Easing.InOutCubic }
  }
  function setExpanded(held) {
    if (pointerHeld === held) return
    pointerHeld = held
    if (held) {
      exitTimer.stop()
      root.updateExpansion()
    } else exitTimer.restart()
  }
  Timer { id: exitTimer; interval: Timing.agentActivity.releasingMs; onTriggered: root.updateExpansion() }

  function focusOrLaunch(kind) {
    var clients = Hyprland.toplevels.values
    var chosen = null
    var bestRank = Infinity
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (AgentModel.kind(client) !== kind) continue
      var ipc = client.lastIpcObject || ({})
      var history = Number(ipc.focusHistoryID)
      var rank = isFinite(history) && history >= 0 ? history : 1000000
      if (!chosen || rank < bestRank) { chosen = client; bestRank = rank }
    }
    if (chosen && chosen.wayland) {
      chosen.wayland.activate()
    } else if (chosen) {
      var address = String(chosen.address || "").toLowerCase().replace(/^0x/, "")
      if (!/^[0-9a-f]+$/.test(address)) return
      Hyprland.dispatch(Hyprland.usingLua
        ? "hl.dsp.focus({ window = 'address:0x" + address + "' })"
        : "focuswindow address:0x" + address)
    } else if (root.bar) {
      root.bar.run("\"$HOME/.local/bin/jeebis-bar-action\" " + kind)
    }
  }

  Row {
    id: buttons
    anchors.right: parent.right
    anchors.rightMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(3)
    opacity: root.islandRevealProgress

    Repeater {
      model: [ { kind: "chatgpt", name: "ChatGPT" }, { kind: "codex", name: "Codex" } ]
      WidgetButton {
        id: agentButton
        required property var modelData
        readonly property bool running: root.runningKinds[modelData.kind] === true
        readonly property bool shownRunning: root.activitySequence && root.activityPhase === 0
          && root.transitionFromRunning[modelData.kind] !== undefined
          ? root.transitionFromRunning[modelData.kind] : running
        bar: root.bar
        text: modelData.name
        fontSize: Style.font.bodySmall
        foreground: shownRunning ? (root.bar ? root.bar.barForeground : Color.bar.text) : Color.muted
        // Own the painted label so the shared WidgetButton's 160 ms color
        // animation does not add a second transition after this one.
        labelVisible: false
        fixedWidth: agentLabel.implicitWidth + scaledHorizontalMargin * 2
        Behavior on foreground {
          ColorAnimation { duration: Timing.agentActivity.changingMs }
        }
        Text {
          id: agentLabel
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: agentButton.text
          font.family: agentButton.fontFamily
          font.pixelSize: agentButton.fontSize
          color: agentButton.foreground
          renderType: Text.NativeRendering
        }
        tooltipText: modelData.name + (running ? "にフォーカス" : "を起動")
        fixedHeight: root.barSize
        horizontalMargin: 6
        verticalPadding: 0
        onPressed: function(button) {
          if (button === Qt.LeftButton) root.focusOrLaunch(modelData.kind)
        }
      }
    }
  }
}
