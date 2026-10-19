import "../jeebis.bar/AnimationTiming.js" as Timing
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import qs.Ui as Ui
import "../jeebis.bar/AgentModel.js" as AgentModel

Ui.BarWidget {
  id: root
  moduleName: "jeebis.apps"
  property bool detachedEntry: false
  required property bool floatingGroup
  property bool switchHeld: false
  property bool compositionHeld: false
  property bool recentering: false
  property real compositionBaseWidth: 0
  property int pendingHoldMs: Timing.appArrival.settledMs
  function cancelComposition() {
    recenterTimer.stop()
    recentering = false
    compositionHeld = false
  }
  function holdComposition(holdMs) {
    pendingHoldMs = holdMs
    if (compositionHeld) return
    compositionBaseWidth = islandRevealProgress > 0
      ? centeringWidth / islandRevealProgress
      : displayedApps.length * Style.bar.iconSlot + Math.max(0, displayedApps.length - 1) * iconSpacing
    recenterTimer.stop()
    recentering = false
    compositionHeld = true
    hideTimer.stop()
    revealActive = true
  }
  function settleComposition(holdMs) {
    pendingHoldMs = holdMs
    if (arrivals.count > 0 || departures.count > 0 || !compositionHeld) return
    hideTimer.stop()
    revealActive = true
    recentering = true
    compositionHeld = false
    recenterTimer.restart()
  }
  Timer {
    id: recenterTimer
    interval: Timing.centerCompanions.movingMs
    onTriggered: {
      root.recentering = false
      root.reveal(root.pendingHoldMs)
    }
  }
  function isFloating(client) { return !!((client.lastIpcObject || ({})).floating) }
  function beginPresentation() {
    cancelComposition()
    switchHeld = true
    directHandoff = true
    syncApplications()
    arrivals.clear(); arrivalRevision++
    departures.clear(); departureRevision++
    closedCandidates = []
    awaitingApplications = ({})
    displayedApps = appItems.slice()
    hideTimer.stop()
    Qt.callLater(function() { root.directHandoff = false })
  }
  function finishPresentation(present) {
    hoverHeld = false
    hoverExitTimer.stop()
    hoverExitGrace = false
    switchHeld = false
    syncApplications()
    if (present) reveal(Timing.appIsland.presentMs)
    else { hideTimer.stop(); revealActive = false }
  }

  readonly property real iconSpacing: Style.space(5)
  readonly property var appItems: collectOpenApps()
  property var displayedApps: []
  onDisplayedAppsChanged: syncIconModel()
  // Preserve delegates across reorders, rather than recreating a JS-array model.
  ListModel { id: appIcons }
  function syncIconModel() {
    var changed = false
    var wanted = ({})
    for (var i = 0; i < displayedApps.length; i++)
      wanted[displayedApps[i].identity.toLowerCase()] = true
    for (var j = appIcons.count - 1; j >= 0; j--) {
      if (!wanted[appIcons.get(j).appKey]) { appIcons.remove(j); changed = true }
    }
    for (var k = 0; k < displayedApps.length; k++) {
      var app = displayedApps[k]
      var key = app.identity.toLowerCase()
      var found = -1
      for (var n = k; n < appIcons.count; n++)
        if (appIcons.get(n).appKey === key) { found = n; break }
      if (found < 0) {
        appIcons.insert(k, { appKey: key, appIdentity: app.identity, appName: app.name, appIcon: app.icon })
        changed = true
      } else {
        if (found !== k) { appIcons.move(found, k, 1); changed = true }
        appIcons.setProperty(k, "appIdentity", app.identity)
        appIcons.setProperty(k, "appName", app.name)
        appIcons.setProperty(k, "appIcon", app.icon)
      }
    }
    // Let the positioner apply moves before any queued split captures its x.
    if (changed) departureLayoutTimer.restart()
  }
  Timer {
    id: departureLayoutTimer
    interval: Math.max(Timing.appDeparture.reorderingMs, Timing.appDeparture.separatingMs)
    onTriggered: Qt.callLater(root.tryStartDeparture)
  }
  function tryStartDeparture() {
    if (departureLayoutTimer.running) return
    // One split at a time; new closes can still reorder inside the main row.
    for (var i = 0; i < departures.count; i++)
      if (departures.get(i).phase > 0 && !departures.get(i).skipSplit) return
    for (var j = 0; j < departures.count; j++) {
      if (departures.get(j).phase !== 0) continue
      var item = departureRepeater.itemAt(j)
      if (item && item.prepared) item.startSplit()
      return
    }
  }
  onAppItemsChanged: Qt.callLater(root.syncApplications)

  property var focusOrder: ({})
  property int focusSerial: 0

  function clientIdentity(client) {
    return AgentModel.applicationIdentity(client)
  }

  function addressKey(address) {
    return String(address || "").toLowerCase().replace(/^0x/, "")
  }

  function focusApp(identity) {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return
    var clients = workspace.toplevels.values || []
    var selected = null
    var bestRank = -Infinity
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || isFloating(client) !== floatingGroup || clientIdentity(client).toLowerCase() !== String(identity).toLowerCase()) continue
      var ipc = client.lastIpcObject || ({})
      var remembered = focusOrder[addressKey(client.address)]
      var history = Number(ipc.focusHistoryID)
      var rank = remembered !== undefined ? remembered : -(isFinite(history) && history >= 0 ? history : 1000000)
      if (!selected || rank > bestRank) { selected = client; bestRank = rank }
    }
    if (!selected) return
    if (selected.wayland) {
      selected.wayland.activate()
    } else {
      var address = addressKey(selected.address)
      if (!/^[0-9a-f]+$/.test(address)) return
      Hyprland.dispatch(Hyprland.usingLua
        ? "hl.dsp.focus({ window = 'address:0x" + address + "' })"
        : "focuswindow address:0x" + address)
    }
  }

  property bool trackingReady: false
  property bool revealActive: false
  property bool hoverHeld: false
  property bool hoverExitGrace: false
  property int revealSerial: 0

  function setHoverHeld(held) {
    if (hoverHeld === held) return
    hoverHeld = held
    hideTimer.stop()
    revealActive = false
    if (held) {
      hoverExitTimer.stop()
      hoverExitGrace = false
    } else {
      hoverExitGrace = true
      hoverExitTimer.restart()
    }
  }

  Timer {
    id: hoverExitTimer
    interval: Timing.appIsland.releasingMs
    onTriggered: root.hoverExitGrace = false
  }

  // Track only non-Agent windows, matching the actual icon list. Another
  // window of a listed app restarts the timer; Agent-only changes do not.
  readonly property string windowSignature: {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return ""
    var clients = workspace.toplevels.values || []
    var addresses = []
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || AgentModel.kind(client) !== "" || !root.clientIdentity(client)) continue
      if (root.isFloating(client) !== root.floatingGroup) continue
      addresses.push(String(client.address))
    }
    addresses.sort()
    return String(workspace.id) + ":" + addresses.join(",")
  }

  function reveal(durationMs) {
    root.revealSerial++
    if (root.hoverHeld || root.hoverExitGrace) return
    root.revealActive = true
    hideTimer.interval = durationMs === undefined ? Timing.appIsland.presentMs : Math.max(1, Number(durationMs))
    hideTimer.restart()
  }

  property string previousWindowSignature: ""
  onWindowSignatureChanged: {
    var previous = previousWindowSignature.split(":")
    var current = windowSignature.split(":")
    previousWindowSignature = windowSignature
    var before = previous.length > 1 && previous[1] ? previous[1].split(",") : []
    var after = current.length > 1 && current[1] ? current[1].split(",") : []
    var added = after.some(function(address) { return before.indexOf(address) < 0 })
    var removed = before.filter(function(address) { return after.indexOf(address) < 0 })
    var agentConversionOnly = previous[0] === current[0] && !added && removed.length > 0
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < removed.length && agentConversionOnly; i++) {
      var converted = false
      for (var j = 0; j < clients.length; j++)
        if (root.addressKey(clients[j].address) === root.addressKey(removed[i]) && AgentModel.kind(clients[j])) converted = true
      if (!converted) agentConversionOnly = false
    }
    if (root.trackingReady && !agentConversionOnly) root.reveal()
    Qt.callLater(root.syncApplications)
  }
  Component.onCompleted: root.syncApplications()

  Timer {
    id: hideTimer
    interval: Timing.appIsland.presentMs
    onTriggered: root.revealActive = false
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "activewindowv2") {
        var address = root.addressKey(event.data)
        if (address) {
          var order = Object.assign({}, root.focusOrder)
          order[address] = ++root.focusSerial
          root.focusOrder = order
        }
      }
      if (event && event.name === "closewindow") {
        root.rememberClose(event.data)
        var order = Object.assign({}, root.focusOrder)
        delete order[root.addressKey(event.data)]
        root.focusOrder = order
      }
      // Workspace commands emit this even when the target is already focused.
      if (event && event.name === "custom" && String(event.data) === "jeebis.apps.reveal")
        root.reveal()
    }
  }

  // Stable ListModel entries preserve each arrival's independent phase timers.
  ListModel { id: arrivals }
  property int arrivalRevision: 0
  property bool directHandoff: false
  property int arrivalGeometryRevision: 0
  property var knownApplications: ({})
  property var awaitingApplications: ({})
  property int trackedWorkspaceId: 0
  readonly property var globalWindows: {
    var clients = Hyprland.toplevels.values
    var windows = []
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || AgentModel.kind(client)) continue
      windows.push({ floating: root.isFloating(client), address: root.addressKey(client.address), key: root.clientIdentity(client).toLowerCase(),
        workspaceId: client.workspace ? client.workspace.id : 0,
        workspaceName: client.workspace ? String(client.workspace.name || "") : "" })
    }
    return windows
  }
  onGlobalWindowsChanged: Qt.callLater(root.syncApplications)

  ListModel { id: departures }
  property int departureRevision: 0
  property int departureGeometryRevision: 0
  property var windowArchive: ({})
  property var appMetadataCache: ({})
  property var closedCandidates: []

  function departureIndex(key) {
    var revision = departureRevision
    for (var i = 0; i < departures.count; i++) if (departures.get(i).appKey === key) return i
    return -1
  }
  function rememberClose(address) {
    var record = windowArchive[root.addressKey(address)]
    if (switchHeld || !record || record.workspaceId !== currentWorkspaceId || record.floating !== floatingGroup) return
    var metadata = appMetadataCache[record.key]
    if (!metadata) return
    var candidates = closedCandidates.slice()
    candidates.push({ address: root.addressKey(address), appKey: record.key, identity: metadata.identity, appName: metadata.name, icon: metadata.icon })
    closedCandidates = candidates
    Qt.callLater(root.syncApplications)
  }
  function syncDepartures(liveKeys, applications) {
    for (var i = departures.count - 1; i >= 0; i--) {
      if (liveKeys[departures.get(i).appKey]) { departures.remove(i); departureRevision++ }
    }
    var candidates = closedCandidates
    var deferred = []
    var liveAddresses = ({})
    for (var w = 0; w < globalWindows.length; w++) liveAddresses[globalWindows[w].address] = true
    closedCandidates = []
    for (var j = 0; j < candidates.length; j++) {
      var candidate = candidates[j]
      var key = candidate.appKey
      // Wait for both compositor models to reflect the close event.
      if (liveAddresses[candidate.address]) { deferred.push(candidate); continue }
      // One application icon represents all its windows on this workspace.
      if (applications[String(currentWorkspaceId) + ":" + key] || departureIndex(key) >= 0) continue
      if (liveKeys[key]) { deferred.push(candidate); continue }
      var pendingIndex = arrivalIndex(key)
      var pendingItem = pendingIndex >= 0 ? arrivalRepeater.itemAt(pendingIndex) : null
      holdComposition(Timing.appDeparture.settledMs)
      departures.append({ appKey: key, identity: candidate.identity, appName: candidate.appName, icon: candidate.icon,
        phase: pendingIndex >= 0 ? 1 : 0, skipSplit: pendingIndex >= 0,
        initialX: pendingItem ? pendingItem.x : 0, initialOpacity: pendingItem ? pendingItem.entryProgress : 1 })
      departureRevision++
      root.reveal()
    }
    closedCandidates = deferred
  }
  function beginDeparture(key) {
    var index = departureIndex(key)
    if (index < 0) return
    departures.setProperty(index, "phase", 1)
    departureRevision++
    updateDisplayedApps()
  }
  function finishDeparture(key) {
    var index = departureIndex(key)
    if (index < 0) return
    departures.remove(index)
    departureRevision++
    updateDisplayedApps()
    root.settleComposition(Timing.appDeparture.settledMs)
    Qt.callLater(root.tryStartDeparture)
  }
  readonly property real departureExtent: {
    var revision = departureGeometryRevision
    var count = departureRepeater.count
    var extent = 0
    for (var i = 0; i < count; i++) {
      var item = departureRepeater.itemAt(i)
      if (item && item.phase > 0) extent = Math.max(extent, item.x + item.width)
    }
    return extent
  }

  function arrivalIndex(key) {
    var revision = arrivalRevision
    for (var i = 0; i < arrivals.count; i++) if (arrivals.get(i).appKey === key) return i
    return -1
  }
  function isPending(identity) { return arrivalIndex(String(identity).toLowerCase()) >= 0 }
  function updateDisplayedApps() {
    if (switchHeld) return
    var eligible = []
    for (var i = 0; i < appItems.length; i++) {
      var app = appItems[i]
      var index = arrivalIndex(app.identity.toLowerCase())
      if (index < 0 || arrivals.get(index).phase === 1) eligible.push(app)
    }
    // Retain a closed app in the row until its split animation starts.
    for (var d = 0; d < departures.count; d++) {
      var departing = departures.get(d)
      if (departing.phase === 0) eligible.push({ identity: departing.identity, name: departing.appName, icon: departing.icon })
    }
    var ordered = []
    var added = ({})
    for (var j = 0; j < displayedApps.length; j++) {
      var key = displayedApps[j].identity.toLowerCase()
      for (var k = 0; k < eligible.length; k++) {
        if (eligible[k].identity.toLowerCase() === key) {
          ordered.push(eligible[k]); added[key] = true; break
        }
      }
    }
    for (var n = 0; n < eligible.length; n++) {
      var key = eligible[n].identity.toLowerCase()
      if (!added[key]) ordered.push(eligible[n])
    }
    // Live icons stay on the left. Oldest queued close is at the far right,
    // so another close never takes its separation position away.
    var arranged = []
    for (var o = 0; o < ordered.length; o++)
      if (departureIndex(ordered[o].identity.toLowerCase()) < 0) arranged.push(ordered[o])
    for (var q = departures.count - 1; q >= 0; q--) {
      var queued = departures.get(q)
      if (queued.phase === 0)
        arranged.push({ identity: queued.identity, name: queued.appName, icon: queued.icon })
    }
    ordered = arranged
    // Preserve old icons through the normal final exit animation.
    if (ordered.length > 0 || arrivals.count > 0 || departures.count > 0 || trackedWorkspaceId !== currentWorkspaceId)
      displayedApps = ordered
  }
  readonly property int currentWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  function syncApplications() {
    var snapshot = globalWindows
    var nextApplications = ({})
    var archive = Object.assign({}, windowArchive)
    var newKeys = trackedWorkspaceId === currentWorkspaceId ? Object.assign({}, awaitingApplications) : ({})
    for (var i = 0; i < snapshot.length; i++) {
      var window = snapshot[i]
      if (!window.key) continue
      var previousWindow = archive[window.address]
      var parkedForDesktop = window.workspaceName === "special:desktop"
        || (window.workspaceId < 0 && window.workspaceName === "desktop")
      // Super+D temporarily parks windows; retain their real workspace membership.
      var membershipId = parkedForDesktop && previousWindow && previousWindow.workspaceId > 0
        ? previousWindow.workspaceId : window.workspaceId
      var restoredFromDesktop = !parkedForDesktop && previousWindow && previousWindow.parkedForDesktop === true
      var membershipFloating = parkedForDesktop && previousWindow ? previousWindow.floating : window.floating
      var changedLayer = previousWindow && previousWindow.floating !== membershipFloating
      // Group membership alone is not a launch. Both persistent groups cache
      // every address, so later snapshots cannot mistake a layer move for one.
      var enteredWorkspace = !previousWindow || previousWindow.workspaceId !== membershipId
        || previousWindow.key !== window.key
      if (changedLayer || restoredFromDesktop) delete newKeys[window.key]
      archive[window.address] = { floating: membershipFloating, address: window.address, key: window.key,
        workspaceId: membershipId, parkedForDesktop: parkedForDesktop, seenAt: Date.now() }
      // Presence is scoped to each workspace. Another workspace's copy does
      // not suppress the arrival of this workspace's first window of the app.
      if (membershipFloating !== floatingGroup) continue
      var scopedKey = String(membershipId) + ":" + window.key
      nextApplications[scopedKey] = true
      if (!switchHeld && trackingReady && enteredWorkspace && !changedLayer && !parkedForDesktop && !restoredFromDesktop
          && !knownApplications[scopedKey] && window.workspaceId === currentWorkspaceId)
        newKeys[window.key] = Date.now()
    }
    if (trackedWorkspaceId !== currentWorkspaceId) {
      cancelComposition()
      arrivals.clear()
      arrivalRevision++
      departures.clear()
      departureRevision++
      closedCandidates = []
      displayedApps = []
    }
    var liveKeys = ({})
    for (var j = 0; j < appItems.length; j++) liveKeys[appItems[j].identity.toLowerCase()] = true
    root.syncDepartures(liveKeys, nextApplications)
    for (var k = arrivals.count - 1; k >= 0; k--) {
      if (!liveKeys[arrivals.get(k).appKey]) { arrivals.remove(k); arrivalRevision++ }
    }
    for (var n = 0; n < appItems.length; n++) {
      var app = appItems[n]
      var key = app.identity.toLowerCase()
      if (!switchHeld && newKeys[key] && Date.now() - newKeys[key] < 2000 && arrivalIndex(key) < 0) {
        holdComposition(Timing.appArrival.settledMs)
        arrivals.append({ appKey: key, identity: app.identity, appName: app.name, icon: app.icon, phase: 0 })
        arrivalRevision++
        delete newKeys[key]
      }
    }
    for (var pendingKey in newKeys)
      if (!nextApplications[String(currentWorkspaceId) + ":" + pendingKey] || Date.now() - newKeys[pendingKey] >= 2000) delete newKeys[pendingKey]
    awaitingApplications = newKeys
    for (var archivedAddress in archive)
      if (Date.now() - Number(archive[archivedAddress].seenAt || 0) > 3000) delete archive[archivedAddress]
    windowArchive = archive
    var metadata = Object.assign({}, appMetadataCache)
    for (var m = 0; m < appItems.length; m++) metadata[appItems[m].identity.toLowerCase()] = appItems[m]
    appMetadataCache = metadata
    knownApplications = nextApplications
    updateDisplayedApps()
    trackedWorkspaceId = currentWorkspaceId
    trackingReady = true
    if (compositionHeld && arrivals.count === 0 && departures.count === 0)
      Qt.callLater(function() {
        if (root.arrivalsEmpty()) root.settleComposition(root.pendingHoldMs)
      })
  }
  function arrivalsEmpty() { return arrivals.count === 0 && departures.count === 0 }
  function beginMerge(key) {
    var index = arrivalIndex(key)
    if (index < 0) return false
    // Let an empty workspace's first capsule reach its resting place before
    // another incoming capsule tries to join it.
    for (var i = 0; i < arrivals.count; i++)
      if (i !== index && arrivals.get(i).phase === 2) return false
    arrivals.setProperty(index, "phase", displayedApps.length > 0 ? 1 : 2)
    arrivalRevision++
    updateDisplayedApps()
    return true
  }
  function finishMerge(key) {
    var index = arrivalIndex(key)
    if (index < 0) return
    var relocated = arrivals.get(index).phase === 2
    // A relocating capsule becomes the main capsule at the same position,
    // without showing or fading into an empty receiver.
    if (relocated) root.directHandoff = true
    arrivals.remove(index)
    arrivalRevision++
    updateDisplayedApps()
    if (relocated) Qt.callLater(function() { root.directHandoff = false })
    root.settleComposition(Timing.appArrival.settledMs)
  }
  function renderedIconX(key) {
    for (var i = 0; i < appIcons.count; i++) {
      if (appIcons.get(i).appKey !== key) continue
      var item = iconRepeater.itemAt(i)
      if (item) return item.mapToItem(root, 0, 0).x
    }
    return targetX(key)
  }
  function targetX(key) {
    for (var i = 0; i < displayedApps.length; i++)
      if (displayedApps[i].identity.toLowerCase() === key) return i * (Style.bar.iconSlot + iconSpacing)
    return mainIslandWidth
  }

  readonly property int mainAppCount: {
    var revision = arrivalRevision
    var count = 0
    for (var i = 0; i < appItems.length; i++) {
      var index = arrivalIndex(appItems[i].identity.toLowerCase())
      if (index < 0 || arrivals.get(index).phase === 1) count++
    }
    for (var d = 0; d < departures.count; d++) if (departures.get(d).phase === 0) count++
    return count
  }
  readonly property bool islandRequested: !vertical
    && (switchHeld || compositionHeld || recentering || revealActive || hoverHeld || hoverExitGrace || arrivals.count > 0 || departures.count > 0) && mainAppCount > 0
  property real islandRevealProgress: islandRequested ? 1 : 0
  // An empty app list has no receiver capsule; the first arrival moves alone.
  property real contentWidth: displayedApps.length * Style.bar.iconSlot
    + Math.max(0, displayedApps.length - 1) * iconSpacing
  readonly property real mainIslandWidth: contentWidth * islandRevealProgress
  readonly property bool presentationRequested: islandRequested || arrivals.count > 0 || departures.count > 0
  readonly property real desiredCenteringWidth: {
    if (!compositionHeld) return mainIslandWidth
    if (compositionBaseWidth > 0) return compositionBaseWidth * islandRevealProgress
    // First-ever app: center its painted capsule, without inventing a receiver.
    if (arrivals.count > 0) {
      var first = arrivalRepeater.itemAt(0)
      if (first) return 2 * first.x + first.width
    }
    return mainIslandWidth
  }
  property real centeringWidth: desiredCenteringWidth
  Behavior on centeringWidth {
    enabled: root.recentering && !root.directHandoff && !root.switchHeld
    NumberAnimation { duration: Timing.centerCompanions.movingMs; easing.type: Easing.InOutCubic }
  }
  readonly property real mainIslandOffsetX: detachedEntry ? 0 : -Style.space(16) * (1 - islandRevealProgress)
  readonly property real arrivalExtent: {
    var revision = arrivalGeometryRevision
    var count = arrivalRepeater.count
    var extent = 0
    for (var i = 0; i < count; i++) {
      var item = arrivalRepeater.itemAt(i)
      if (item) extent = Math.max(extent, item.x + item.width)
    }
    return extent
  }
  // Include standalone capsules so the host animates real painted content,
  // even before the first app has a receiver capsule.
  readonly property real presentationProgress: {
    var revision = arrivalGeometryRevision + departureGeometryRevision
    var progress = islandRevealProgress
    for (var a = 0; a < arrivalRepeater.count; a++) {
      var arriving = arrivalRepeater.itemAt(a)
      if (arriving) progress = Math.max(progress, arriving.entryProgress)
    }
    for (var d = 0; d < departureRepeater.count; d++) {
      var departing = departureRepeater.itemAt(d)
      if (departing && departing.phase > 0) progress = Math.max(progress, departing.lifeOpacity)
    }
    return progress
  }
  // The invisible hit target retains the final icon-row width while hidden.
  readonly property real hoverTargetWidth: appItems.length > 0 || departures.count > 0
    ? Math.max(appItems.length * Style.bar.iconSlot + Math.max(0, appItems.length - 1) * iconSpacing,
        arrivalExtent, departureExtent, mainIslandWidth) : 0

  visible: islandRevealProgress > 0 || arrivals.count > 0 || departures.count > 0
  clip: false
  implicitWidth: Math.max(mainIslandWidth, arrivalExtent, departureExtent)
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    enabled: !root.directHandoff && !root.switchHeld
    NumberAnimation { duration: root.islandRequested ? Timing.appIsland.enteringMs : Timing.appIsland.leavingMs; easing.type: Easing.InOutCubic }
  }
  Behavior on contentWidth {
    enabled: !root.directHandoff && !root.switchHeld
    NumberAnimation { duration: arrivals.count > 0 ? Timing.appArrival.joiningMs
        : departures.count > 0 ? Timing.appDeparture.separatingMs : Timing.appIsland.resizingMs; easing.type: Easing.InOutCubic }
  }

  // Omarchy --app windows expose a Chromium URL-derived class, rather than
  // the launcher name. Match that stable class even when a document is renamed.
  readonly property var webAppEntries: [
    { pattern: /^(?:chrome|chromium|helium|brave|msedge)-calendar\.google\.com(?:__|[\/_-]|$)/, desktopId: "Calendar", name: "Google Calendar", icon: "calendar" },
    { pattern: /^(?:chrome|chromium|helium|brave|msedge)-docs\.google\.com__document(?:[\/_-]|$)/, desktopId: "Document", name: "Google Docs", icon: "document" },
    { pattern: /^(?:chrome|chromium|helium|brave|msedge)-docs\.google\.com__presentation(?:[\/_-]|$)/, desktopId: "Presentation", name: "Google Slides", icon: "presentation" },
    { pattern: /^(?:chrome|chromium|helium|brave|msedge)-docs\.google\.com__spreadsheets(?:[\/_-]|$)/, desktopId: "Sheets", name: "Google Sheets", icon: "sheets" },
    { pattern: /^(?:chrome|chromium|helium|brave|msedge)-teams\.(?:microsoft\.com|cloud\.microsoft)(?:__|[\/_-]|$)/, desktopId: "Teams", name: "Microsoft Teams", icon: "teams" }
  ]
  function webAppUrlKey(url) {
    var match = /^https?:\/\/([^\/?#]+)([^?#]*)/i.exec(String(url || ""))
    if (!match) return ""
    var host = match[1].replace(/^.*@/, "").replace(/:[0-9]+$/, "").toLowerCase()
    var path = match[2] || "/"
    // Chromium's URL app name is host + "_" + path; Linux classes replace
    // path separators with underscores and append a browser profile suffix.
    return (host + "_" + path.replace(/\//g, "_")).toLowerCase()
  }
  readonly property var discoveredWebApps: {
    var entries = DesktopEntries.applications.values || []
    var result = []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (!entry || !entry.icon) continue
      var command = entry.command || []
      var url = ""
      for (var j = 0; j < command.length; j++) {
        var arg = String(command[j])
        if (arg.replace(/^.*\//, "") === "omarchy-launch-webapp" && j + 1 < command.length) {
          url = String(command[j + 1]); break
        }
        if (arg.indexOf("--app=") === 0) { url = arg.slice(6); break }
        if (arg === "--app" && j + 1 < command.length) { url = String(command[j + 1]); break }
      }
      var key = root.webAppUrlKey(url)
      if (key) result.push({ key: key, entry: entry })
    }
    result.sort(function(a, b) { return b.key.length - a.key.length })
    return result
  }
  function desktopEntryForClient(identity, title) {
    var webId = String(identity || "").toLowerCase()
    for (var w = 0; w < webAppEntries.length; w++) {
      var app = webAppEntries[w]
      if (!app.pattern.test(webId)) continue
      var desktop = DesktopEntries.byId(app.desktopId)
      var dataHome = Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")
      return { name: desktop ? desktop.name : app.name,
        icon: "file://" + dataHome + "/icons/hicolor/256x256/apps/" + app.icon + ".png" }
    }
    // New desktop registrations are watched by DesktopEntries. Read their
    // already-tokenized command and Icon field, without running any command.
    var appClass = webId.replace(/^(?:chrome|chromium|helium|brave|msedge|microsoft-edge|opera|vivaldi)-/, "")
    if (appClass !== webId) {
      for (var d = 0; d < discoveredWebApps.length; d++) {
        var candidate = discoveredWebApps[d]
        if (appClass.indexOf(candidate.key + "-") === 0) return candidate.entry
      }
    }
    var entries = DesktopEntries.applications.values || []
    var cleanTitle = String(title || "").trim().toLowerCase()

    // Chromium WebApps often report the browser's app id as their identity,
    // while their generated desktop entry is named after the WebApp.
    if (cleanTitle) {
      for (var i = 0; i < entries.length; i++) {
        var candidate = entries[i]
        var name = String((candidate && candidate.name) || "").trim().toLowerCase()
        if (name && (cleanTitle === name || cleanTitle.indexOf(name + " - ") === 0 || cleanTitle.indexOf(name + " — ") === 0))
          return candidate
      }
    }

    var entry = DesktopEntries.byId(identity)
    if (!entry) entry = DesktopEntries.heuristicLookup(identity)
    if (!entry && cleanTitle) entry = DesktopEntries.heuristicLookup(title)
    return entry
  }

  function collectOpenApps() {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return []

    var clients = workspace.toplevels.values || []
    var seen = ({})
    var result = []

    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || root.isFloating(client) !== root.floatingGroup) continue

      var identity = root.clientIdentity(client)
      if (!identity) continue

      var key = identity.toLowerCase()
      // Dedicated Agent apps are represented by the separate Agent capsule.
      if (AgentModel.kind(client) !== "") continue
      if (seen[key]) continue
      seen[key] = true

      var terminalApp = AgentModel.terminalApplication(client)
      var entry = terminalApp ? null : root.desktopEntryForClient(identity, client.title)
      var terminalIcons = { nvim: "nvim", yazi: "yazi" }
      var terminalNames = { nvim: "Neovim", yazi: "Yazi" }
      var icon = terminalApp ? terminalIcons[terminalApp] : entry && entry.icon ? String(entry.icon) : identity
      var name = terminalApp ? terminalNames[terminalApp] : entry && entry.name ? String(entry.name) : String(client.title || identity)

      result.push({
        identity: identity,
        name: name,
        icon: icon
      })
    }

    return result
  }

  function iconSource(icon) {
    var value = String(icon || "application-x-executable")
    return value.indexOf("file:") === 0 || value.charAt(0) === "/" ? value : Quickshell.iconPath(value, true)
  }

  // Reveal only the main row from the workspace-facing edge. Incoming and
  // departing standalone capsules stay outside this clipped viewport.
  Item {
    id: appViewport
    x: root.mainIslandOffsetX
    anchors.verticalCenter: parent.verticalCenter
    width: root.mainIslandWidth
    height: root.barSize
    clip: true
    Row {
      id: iconRow
      // Keep icon coordinates fixed while the receiver's width is animated.
      // Right anchoring displaced the entire row during merges and splits.
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.iconSpacing
      opacity: root.islandRevealProgress
      move: Transition {
        enabled: root.islandRevealProgress > 0.99
        NumberAnimation { properties: "x,y"; duration: Timing.appDeparture.reorderingMs; easing.type: Easing.InOutCubic }
      }
      Repeater {
        id: iconRepeater
        model: appIcons
        WidgetButton {
          required property string appIdentity
          required property string appName
          required property string appIcon
          readonly property bool pending: root.isPending(appIdentity)
          bar: root.bar
          text: ""
          labelVisible: false
          hasVisualContent: true
          interactive: !root.switchHeld && !pending && root.departureIndex(appIdentity.toLowerCase()) < 0
          tooltipText: appName
          onPressed: function(button) {
            if (button === Qt.LeftButton) root.focusApp(appIdentity)
          }
          fixedWidth: Style.bar.iconSlot
          fixedHeight: root.barSize
          horizontalMargin: 0
          verticalPadding: 0
          Image {
            anchors.centerIn: parent
            width: Style.bar.iconCanvas
            height: Style.bar.iconCanvas
            source: root.iconSource(appIcon)
            visible: !parent.pending
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }
        }
      }
    }
  }

  Repeater {
    id: arrivalRepeater
    model: arrivals
    onItemAdded: root.arrivalGeometryRevision++
    onItemRemoved: root.arrivalGeometryRevision++
    delegate: Item {
      id: arrival
      required property int index
      required property string appKey
      required property string identity
      required property string appName
      required property string icon
      required property int phase
      property real mergeProgress: 0
      property real entryProgress: 0
      property real mergeStartX: 0
      readonly property real restingX: (root.mainIslandWidth > 0 ? root.mainIslandWidth + Style.space(16) : Style.space(16))
        + index * (Style.bar.iconSlot + Style.space(16))
      x: phase > 0 ? mergeStartX + ((phase === 2 ? 0 : root.targetX(appKey)) - mergeStartX) * mergeProgress
        : restingX + Style.space(8) * (1 - entryProgress)
      width: Style.bar.iconSlot
      height: root.barSize
      anchors.verticalCenter: parent.verticalCenter
      opacity: entryProgress
      z: 5
      Component.onCompleted: {
        if (root.displayedApps.length > 0) showBaseFirst.start()
        else entryAnimation.start()
      }
      Timer {
        id: showBaseFirst
        interval: Timing.appArrival.preparingMs
        onTriggered: entryAnimation.start()
      }
      NumberAnimation {
        id: entryAnimation
        target: arrival
        property: "entryProgress"
        to: 1
        duration: Timing.appArrival.enteringMs
        easing.type: Easing.OutCubic
        onFinished: dwell.start()
      }
      Timer {
        id: dwell
        interval: Timing.appArrival.presentMs
        onTriggered: {
          arrival.mergeStartX = arrival.x
          if (root.beginMerge(arrival.appKey)) mergeAnimation.start()
          else dwell.restart()
        }
      }
      NumberAnimation {
        id: mergeAnimation
        target: arrival
        property: "mergeProgress"
        to: 1
        duration: Timing.appArrival.joiningMs
        easing.type: Easing.InOutCubic
        onFinished: root.finishMerge(arrival.appKey)
      }
      Rectangle {
        x: -Style.space(8)
        width: parent.width + Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        height: root.barSize * (0.84 + 0.16 * arrival.entryProgress)
        radius: height / 2
        color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.94) : Color.background
        border.width: 1
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        opacity: arrival.phase === 2 ? 1 : 1 - arrival.mergeProgress
      }
      WidgetButton {
        anchors.fill: parent
        bar: root.bar
        text: ""
        labelVisible: false
        hasVisualContent: true
        tooltipText: arrival.appName
        fixedWidth: Style.bar.iconSlot
        fixedHeight: root.barSize
        horizontalMargin: 0
        verticalPadding: 0
        onPressed: function(button) {
          if (button === Qt.LeftButton) root.focusApp(arrival.identity)
        }
        Image {
          anchors.centerIn: parent
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          source: root.iconSource(arrival.icon)
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
        }
      }
    }
  }
  Repeater {
    id: departureRepeater
    model: departures
    onItemAdded: root.departureGeometryRevision++
    onItemRemoved: root.departureGeometryRevision++
    delegate: Item {
      id: departure
      required property int index
      required property string appKey
      required property string appName
      required property string icon
      required property int phase
      required property bool skipSplit
      required property real initialX
      required property real initialOpacity
      property bool prepared: false
      function startSplit() {
        if (phase !== 0) return
        // Capture the rendered position before removing the original delegate.
        startX = root.renderedIconX(appKey)
        root.beginDeparture(appKey)
        var remainingWidth = root.displayedApps.length * Style.bar.iconSlot
          + Math.max(0, root.displayedApps.length - 1) * root.iconSpacing
        endX = Math.max(remainingWidth, root.arrivalExtent) + Style.space(16)
        splitAnimation.start()
      }
      property real splitProgress: 0
      property real lifeOpacity: initialOpacity
      property real startX: initialX
      property real endX: initialX
      x: skipSplit ? initialX : startX + (endX - startX) * splitProgress
      width: Style.bar.iconSlot
      height: root.barSize
      anchors.verticalCenter: parent.verticalCenter
      visible: phase > 0
      opacity: lifeOpacity
      scale: 0.86 + 0.14 * lifeOpacity
      z: 6
      Component.onCompleted: {
        if (skipSplit) fadeOut.start()
        else showBeforeSplit.start()
      }
      Timer {
        id: showBeforeSplit
        interval: Timing.appDeparture.preparingMs
        onTriggered: {
          departure.prepared = true
          root.tryStartDeparture()
        }
      }
      NumberAnimation {
        id: splitAnimation
        target: departure
        property: "splitProgress"
        to: 1
        duration: Timing.appDeparture.separatingMs
        easing.type: Easing.InOutCubic
        onFinished: fadeOut.start()
      }
      NumberAnimation {
        id: fadeOut
        target: departure
        property: "lifeOpacity"
        to: 0
        duration: Timing.appDeparture.leavingMs
        easing.type: Easing.InCubic
        onFinished: {
          var key = departure.appKey
          Qt.callLater(root.finishDeparture, key)
        }
      }
      Rectangle {
        x: -Style.space(8)
        width: parent.width + Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        height: root.barSize
        radius: height / 2
        color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.94) : Color.background
        border.width: 1
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        opacity: departure.skipSplit ? 1 : departure.splitProgress
      }
      Image {
        anchors.centerIn: parent
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        source: root.iconSource(departure.icon)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }
  }

}
