import "../jeebis.bar/AnimationTiming.js" as Timing
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as WorkspaceModel

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // Attribute CPU activity to the workspace that owns each window's process
  // tree instead of assigning system-wide load to whichever workspace is focused.
  property real workspaceCpuBusyThreshold: 10
  property real workspaceCpuResetThreshold: 5
  property var workspaceCpuTicks: ({})
  property var busySamplesByWorkspace: ({})
  property var busyWorkspaces: ({})
  property var workspaceCpuUsage: ({})
  property bool systemBusy: false
  readonly property int fallbackBusyWorkspaceId: {
    if (!systemBusy) return 0
    var ids = root.activeWorkspaceIds
    // Already attributed busy workspaces keep their own spinners.
    for (var i = 0; i < ids.length; i++)
      if (root.busyWorkspaces[String(ids[i])] === true) return 0
    var bestId = 0
    var bestUsage = 0
    for (var j = 0; j < ids.length; j++) {
      var usage = Number(root.workspaceCpuUsage[String(ids[j])]) || 0
      if (usage > bestUsage) { bestUsage = usage; bestId = ids[j] }
    }
    if (bestId > 0) return bestId
    var focused = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    return ids.indexOf(focused) >= 0 ? focused : (ids.length > 0 ? ids[0] : 0)
  }
  property var launchingWorkspaces: ({})
  property double previousWorkspaceSampleAt: -1
  property int spinnerFrame: 0
  readonly property string spinnerFrames: "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  readonly property color inactiveDotColor: Color.muted
  readonly property color focusedDotColor: bar ? bar.barForeground : Color.bar.text

  // Start hidden. Resolve the model before beginning any reveal animation.
  property bool initialized: false
  readonly property var activeWorkspaceIds: WorkspaceModel.activeIds(
    Hyprland.workspaces.values, Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0)
  readonly property bool islandRequested: initialized && (WorkspaceModel.shouldShow(activeWorkspaceIds)
    || (root.systemBusy && activeWorkspaceIds.length > 0))
  property real islandRevealProgress: 0
  property var displayedWorkspaceIds: []
  property real contentWidth: displayedWorkspaceIds.length > 0 ? grid.implicitWidth + trailingGap : 0
  property real contentHeight: displayedWorkspaceIds.length > 0 ? grid.implicitHeight : 0

  function syncDisplayedWorkspaces() {
    if (!root.initialized) return
    if (root.islandRequested && root.activeWorkspaceIds.length > 0) {
      // Populate the Repeater first; revealing an empty model paints a thin pill.
      var next = root.activeWorkspaceIds.slice()
      if (JSON.stringify(next) !== JSON.stringify(root.displayedWorkspaceIds))
        root.displayedWorkspaceIds = next
      root.islandRevealProgress = 1
    } else {
      // Retain outgoing dots while the exit animation runs.
      var wasRevealed = root.islandRevealProgress > 0
      root.islandRevealProgress = 0
      if (!wasRevealed && root.displayedWorkspaceIds.length > 0) root.displayedWorkspaceIds = []
    }
  }

  // Bindings can settle in a different order during reload. Defer and observe
  // both the actual ID list and visibility request, not just the first signal.
  onActiveWorkspaceIdsChanged: Qt.callLater(root.syncDisplayedWorkspaces)
  onIslandRequestedChanged: Qt.callLater(root.syncDisplayedWorkspaces)
  onIslandRevealProgressChanged: {
    if (islandRevealProgress === 0 && !islandRequested && displayedWorkspaceIds.length > 0)
      displayedWorkspaceIds = []
  }
  Component.onCompleted: {
    root.initialized = true
    Qt.callLater(root.syncDisplayedWorkspaces)
  }

  visible: islandRevealProgress > 0 && displayedWorkspaceIds.length > 0
  clip: true
  // Keep the capsule's full shape while sliding; only remove its slot after exit.
  implicitWidth: visible ? (vertical ? barSize : contentWidth) : 0
  implicitHeight: visible ? (vertical ? contentHeight * islandRevealProgress : barSize) : 0

  Behavior on islandRevealProgress {
    NumberAnimation { duration: root.islandRequested ? Timing.workspaceIsland.enteringMs : Timing.workspaceIsland.leavingMs; easing.type: Easing.InOutCubic }
  }
  Behavior on contentWidth {
    enabled: root.visible && root.islandRevealProgress === 1
    NumberAnimation { duration: Timing.workspaceIsland.resizingMs; easing.type: Easing.OutCubic }
  }
  Behavior on contentHeight {
    NumberAnimation { duration: Timing.workspaceIsland.resizingMs; easing.type: Easing.OutCubic }
  }

  function updateWorkspaceCpu(output) {
    var snapshot
    try { snapshot = JSON.parse(String(output)) } catch (error) { return }
    if (!snapshot || !snapshot.workspaces) return

    var now = Date.now()
    var elapsed = root.previousWorkspaceSampleAt > 0
      ? Math.max(0.1, (now - root.previousWorkspaceSampleAt) / 1000)
      : 0
    var tickRate = Number(snapshot.tickRate) || 100
    var nextTicks = ({})
    var nextSamples = ({})
    var nextBusy = ({})
    var nextUsage = ({})
    var ids = root.activeWorkspaceIds

    for (var i = 0; i < ids.length; i++) {
      var key = String(ids[i])
      var ticks = Number(snapshot.workspaces[key]) || 0
      var previousTicks = Number(root.workspaceCpuTicks[key]) || 0
      var samples = Number(root.busySamplesByWorkspace[key]) || 0
      var busy = root.busyWorkspaces[key] === true

      if (elapsed > 0) {
        var cpuPercent = Math.max(0, (ticks - previousTicks) / tickRate / elapsed * 100)
        nextUsage[key] = cpuPercent
        if (cpuPercent >= root.workspaceCpuBusyThreshold) {
          samples = Math.min(samples + 1, 2)
          if (samples >= 2) busy = true
        } else if (cpuPercent < root.workspaceCpuResetThreshold) {
          samples = 0
          busy = false
        }
      }

      nextTicks[key] = ticks
      nextSamples[key] = samples
      nextBusy[key] = busy
    }

    root.workspaceCpuTicks = nextTicks
    root.busySamplesByWorkspace = nextSamples
    root.busyWorkspaces = nextBusy
    root.workspaceCpuUsage = nextUsage
    root.previousWorkspaceSampleAt = now
  }

  function setLaunchPulse(workspaceId, active) {
    var key = String(workspaceId)
    var next = Object.assign({}, root.launchingWorkspaces)
    if (active) next[key] = true
    else delete next[key]
    root.launchingWorkspaces = next
  }

  function hasActiveSpinner() {
    if (root.systemBusy) return true
    var busyIds = Object.keys(root.busyWorkspaces)
    for (var i = 0; i < busyIds.length; i++) if (root.busyWorkspaces[busyIds[i]]) return true
    var launchingIds = Object.keys(root.launchingWorkspaces)
    for (var j = 0; j < launchingIds.length; j++) if (root.launchingWorkspaces[launchingIds[j]]) return true
    return false
  }

  function handleHyprlandEvent(event) {
    if (!event || event.name !== "openwindow") return

    var parts = event.parse ? event.parse(4) : String(event.data || "").split(",")
    // Hyprland's openwindow payload is address, workspace, class, title.
    var openedWorkspace = parseInt(parts[1], 10)
    if (!isFinite(openedWorkspace)) return
    for (var i = 0; i < workspaceRepeater.count; i++) {
      var button = workspaceRepeater.itemAt(i)
      if (button && button.modelData === openedWorkspace) {
        button.pulseLaunch()
        return
      }
    }
  }

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    return root.displayedWorkspaceIds
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl --batch " + Util.shellQuote(
      "dispatch hl.dsp.focus({ workspace = \"" + id + "\" }); "
      + "dispatch hl.dsp.event(\"jeebis.apps.reveal\")"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  Process {
    id: workspaceCpuProcess
    command: ["python3", Quickshell.env("HOME") + "/.config/omarchy/plugins/jeebis.workspaces/workspace-cpu.py"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateWorkspaceCpu(text)
    }
  }

  Timer {
    interval: 1500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!workspaceCpuProcess.running) workspaceCpuProcess.running = true
  }

  Timer {
    interval: Timing.workspaceActivity.cyclingMs
    running: root.visible && root.hasActiveSpinner()
    repeat: true
    onTriggered: root.spinnerFrame = (root.spinnerFrame + 1) % root.spinnerFrames.length
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.handleHyprlandEvent(event) }
  }

  GridLayout {
    id: grid
    anchors.centerIn: parent
    width: implicitWidth
    height: implicitHeight
    columns: root.vertical ? 1 : Math.max(2, root.displayedWorkspaceIds.length)
    opacity: root.bar && root.bar.position === "top" ? 1 : root.islandRevealProgress
    scale: root.bar && root.bar.position === "top" ? 1 : 0.9 + 0.1 * root.islandRevealProgress
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      id: workspaceRepeater
      model: root.workspaceIds()

      WidgetButton {
        id: workspaceButton
        required property int modelData
        property bool launchPulse: false
        Component.onDestruction: if (launchPulse) root.setLaunchPulse(modelData, false)

        function pulseLaunch() {
          launchPulse = true
          root.setLaunchPulse(modelData, true)
          launchPulseTimer.restart()
        }

        Timer {
          id: launchPulseTimer
          interval: Timing.workspaceActivity.settlingMs
          onTriggered: {
            workspaceButton.launchPulse = false
            root.setLaunchPulse(workspaceButton.modelData, false)
          }
        }

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property bool workspaceBusy: root.busyWorkspaces[String(modelData)] === true
          || (root.systemBusy && root.fallbackBusyWorkspaceId === modelData)

        bar: root.bar
        text: workspaceBusy || launchPulse
          ? root.spinnerFrames.charAt(root.spinnerFrame)
          : focused || occupied ? "\u25CF" : "\u25CB"
        foreground: root.inactiveDotColor
        active: focused
        activeColor: root.focusedDotColor
        fontSize: Style.bar.iconFont
        opacity: focused || occupied ? 1 : 0.55
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
