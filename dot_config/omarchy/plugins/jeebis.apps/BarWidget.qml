import "../jeebis.bar/AnimationTiming.js" as Timing
import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "../jeebis.bar/AgentModel.js" as AgentModel

Ui.BarWidget {
  id: root
  moduleName: "jeebis.apps"
  property real selectionEntryProgress: 1
  property bool forceTopEntry: false
  readonly property real centeringWidth: selectedGroup.centeringWidth
  readonly property bool centerRepositioning: selectedGroup.recentering
  readonly property bool entryExiting: !selectedGroup.presentationRequested
  property bool detachedEntry: false
  property bool selectedFloating: false
  property bool initialized: false
  property int trackedWorkspace: 0
  property bool hoverHeld: false
  readonly property real padding: Style.space(8)
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool wantedFloating: {
    var client = Hyprland.activeToplevel
    if (!client || AgentModel.kind(client) || !client.workspace || client.workspace.id !== workspaceId) return selectedFloating
    return !!((client.lastIpcObject || ({})).floating)
  }
  readonly property bool hasApplications: selectedGroup.appItems.length > 0
  readonly property var selectedGroup: selectedFloating ? floatingSurface.group : tiledSurface.group
  // Each surface owns its capsule; keep the host background disabled.
  readonly property real mainIslandWidth: 0
  readonly property real mainIslandOffsetX: 0
  readonly property real islandRevealProgress: Math.min(selectedGroup.presentationProgress, selectionEntryProgress)
  readonly property int revealSerial: selectedGroup.revealSerial
  readonly property real hoverTargetWidth: selectedGroup.hoverTargetWidth
  visible: selectedGroup.implicitWidth > 0
  implicitWidth: selectedGroup.implicitWidth
  implicitHeight: visible ? barSize : 0

  function setHoverHeld(held) {
    hoverHeld = held
    tiledSurface.group.setHoverHeld(!selectedFloating && held)
    floatingSurface.group.setHoverHeld(selectedFloating && held)
  }
  function reveal(durationMs) { selectedGroup.reveal(durationMs) }
  function syncLayer() {
    if (!initialized || trackedWorkspace !== workspaceId) {
      selectedFloating = wantedFloating
      trackedWorkspace = workspaceId
      initialized = true
      setHoverHeld(hoverHeld)
      return
    }
    if (wantedFloating === selectedFloating) return
    var previous = selectedGroup
    var next = wantedFloating ? floatingSurface.group : tiledSurface.group
    // The list still swaps immediately; present the selected surface from above.
    selectionEntrance.stop()
    forceTopEntry = true
    selectionEntryProgress = 0
    next.beginPresentation()
    previous.finishPresentation(false)
    selectedFloating = wantedFloating
    next.finishPresentation(true)
    setHoverHeld(hoverHeld)
    selectionEntrance.start()
  }
  NumberAnimation {
    id: selectionEntrance
    target: root
    property: "selectionEntryProgress"
    to: 1
    duration: Timing.appIsland.enteringMs
    easing.type: Easing.OutCubic
    onFinished: {
      root.forceTopEntry = false
      root.selectedGroup.reveal(Timing.appIsland.presentMs)
    }
  }
  onWantedFloatingChanged: Qt.callLater(root.syncLayer)
  onWorkspaceIdChanged: Qt.callLater(root.syncLayer)
  Component.onCompleted: Qt.callLater(root.syncLayer)
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "changefloatingmode") Hyprland.refreshToplevels()
    }
  }
  Item {
    x: -root.padding
    width: root.implicitWidth + 2 * root.padding
    height: root.barSize
    anchors.verticalCenter: parent.verticalCenter
    clip: true
    GroupSurface { id: tiledSurface; floatingLayer: false }
    GroupSurface { id: floatingSurface; floatingLayer: true }
  }
  component GroupSurface: Item {
    id: surface
    required property bool floatingLayer
    property alias group: member
    x: root.padding
    width: member.implicitWidth
    height: root.barSize
    visible: floatingLayer === root.selectedFloating
    Rectangle {
      enabled: false
      visible: member.mainIslandWidth > 0
      opacity: member.islandRevealProgress
      x: member.mainIslandOffsetX - root.padding * member.islandRevealProgress
      y: (parent.height - height) / 2
      width: member.mainIslandWidth + 2 * root.padding * member.islandRevealProgress
      height: root.barSize * (0.84 + 0.16 * member.islandRevealProgress)
      radius: height / 2
      color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.94) : Color.background
      border.width: 1
      border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
    }
    AppGroup {
      id: member
      floatingGroup: surface.floatingLayer
      detachedEntry: root.detachedEntry
      bar: root.bar
      settings: root.settings
      width: implicitWidth
      height: root.barSize
    }
  }
}
