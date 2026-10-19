import "AnimationTiming.js" as Timing
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel
import "BarActions.js" as BarActions
import "AgentModel.js" as AgentModel

Item {
  id: root

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Read-only registry view for third-party full bars; the built-in bar does
  // not otherwise need it, but declaring it keeps clone construction atomic.
  property var pluginRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar just renders whatever it's handed. The bar font follows the
  // OS-level fontconfig monospace binding — it is not stored in shell.json.
  property var barConfig: ({})
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  QtObject {
    id: fallbackBarWidgetRegistry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { return null }
  }
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  // without an exclusion zone; updated by the FileView watcher further down.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  // True while the pointer is over any bar, widgets included.
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  property string fontFamily: Style.font.family
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  property color themeForeground: Color.bar.text
  property color themeContrastForeground: Color.background
  property color transparentForeground: Color.bar.text
  property color foreground: themeForeground
  property color barForeground: useTransparentForeground ? transparentForeground : themeForeground
  property bool foregroundAnimationEnabled: true
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: Timing.themeTransition.changingMs; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: Timing.themeTransition.changingMs; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: Timing.themeTransition.changingMs; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0
  property var activePopout: null
  property var barDragSource: null
  property var barDragTarget: null
  property var barDragTargetGeometry: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragSceneX: 0
  property real barDragSceneY: 0
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var moduleSlots: []
  property var pluginBarApis: ({})
  property var pluginObjectOwners: []

  Component {
    id: pluginBarApiComponent
    PluginBarApi { }
  }

  function publicLayoutConfig() {
    return JSON.parse(JSON.stringify(root.layoutConfig || {}))
  }

  function bindPluginBarApi(api) {
    if (!api) return
    api.foreground = Qt.binding(function() { return root.foreground })
    api.barForeground = Qt.binding(function() { return root.barForeground })
    api.background = Qt.binding(function() { return root.background })
    api.urgent = Qt.binding(function() { return root.urgent })
    api.fontFamily = Qt.binding(function() { return root.fontFamily })
    api.position = Qt.binding(function() { return root.position })
    api.vertical = Qt.binding(function() { return root.vertical })
    api.barSize = Qt.binding(function() { return root.barSize })
    api.transparent = Qt.binding(function() { return root.transparent })
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
    api.centerSectionRevealHeld = Qt.binding(function() { return root.centerSectionRevealHeld })
    api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
    root.syncPluginBarApiObjects(api)
  }

  function syncPluginBarApiObjects(api) {
    if (!api) return
    api.activePopout = root.pluginOwnsBarObject(api.pluginId, root.activePopout)
      ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null)
    api.clickTargets = root.pluginClickTargets(api.pluginId)
    api.layoutConfig = root.publicLayoutConfig()
  }

  function pluginObjectRecord(target) {
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (record && record.target === target) return record
    }
    return null
  }

  function markPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    if (!key || !target) return false
    var record = root.pluginObjectRecord(target)
    if (record && record.pluginId !== key) return false
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var existing = pluginObjectOwners[i]
      if (!existing || existing.target !== target) next.push(existing)
    }
    var updated = record || { target: target, pluginId: key, clickTarget: false, popout: false }
    updated[role] = true
    next.push(updated)
    pluginObjectOwners = next
    return true
  }

  function unmarkPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (!record || record.target !== target || record.pluginId !== key) {
        next.push(record)
        continue
      }
      record[role] = false
      if (record.clickTarget || record.popout) next.push(record)
    }
    pluginObjectOwners = next
  }

  function pluginOwnsBarObject(pluginId, target) {
    var record = target ? root.pluginObjectRecord(target) : null
    return !!record && record.pluginId === String(pluginId || "")
  }

  function pluginClickTargets(pluginId) {
    var out = []
    for (var i = 0; i < root.clickTargets.length; i++) {
      var target = root.clickTargets[i]
      if (root.pluginOwnsBarObject(pluginId, target)) out.push(target)
    }
    return out
  }

  function syncAllPluginBarApiObjects() {
    for (var id in pluginBarApis) root.syncPluginBarApiObjects(pluginBarApis[id])
  }

  function registerPluginClickTarget(pluginId, target) {
    if (!root.markPluginObject(pluginId, target, "clickTarget")) return
    root.registerClickTarget(target)
  }

  function unregisterPluginClickTarget(pluginId, target) {
    if (!root.pluginOwnsBarObject(pluginId, target)) return
    root.unregisterClickTarget(target)
    root.unmarkPluginObject(pluginId, target, "clickTarget")
  }

  function requestPluginPopout(pluginId, owner) {
    if (!root.markPluginObject(pluginId, owner, "popout")) return
    root.requestPopout(owner)
  }

  function releasePluginPopout(pluginId, owner) {
    if (!root.pluginOwnsBarObject(pluginId, owner)) return
    root.releasePopout(owner)
    root.unmarkPluginObject(pluginId, owner, "popout")
  }

  function pluginBarApiFor(pluginId, moduleName, registered) {
    var key = String(pluginId || "")
    if (!key) return null

    var pluginShell = null
    if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
      // Only the trusted built-in bar receives ShellRoot and can request a
      // service-capable facade for the widget it is instantiating.
      pluginShell = root.shell.pluginShellForId(moduleName)
    } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
      // Replacement bars receive a service-less entry facade. Giving an
      // untrusted bar a generic facade factory would let it retrieve another
      // third-party plugin's live service object.
      pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
    }

    if (pluginBarApis[key]) {
      pluginBarApis[key].shell = pluginShell
      return pluginBarApis[key]
    }

    var api = pluginBarApiComponent.createObject(null, {
      pluginId: key,
      moduleName: String(moduleName || ""),
      shell: pluginShell,
      _showTooltip: function(target, text) { root.showTooltip(target, text) },
      _hideTooltip: function(target) { root.hideTooltip(target) },
      _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
      _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
      _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
      _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
      _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
      _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
      _moduleWidgets: function(requestedId) {
        return String(requestedId || "") === String(moduleName || "")
          ? root.moduleWidgets(moduleName) : []
      },
      _run: function(command) { root.run(command) },
      _setCenterHoverRevealSuppressed: function(value) {
        root.centerHoverRevealSuppressed = !!value
      }
    })
    if (!api) return null
    root.bindPluginBarApi(api)

    var next = ({})
    for (var id in pluginBarApis) next[id] = pluginBarApis[id]
    next[key] = api
    pluginBarApis = next
    return api
  }

  function pluginBarApiUsed(pluginId) {
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.pluginApiId === pluginId) return true
    }
    return false
  }

  function releasePluginObjects(pluginId) {
    var owned = pluginObjectOwners.slice()
    for (var i = 0; i < owned.length; i++) {
      var record = owned[i]
      if (!record || record.pluginId !== pluginId) continue
      if (record.clickTarget) root.unregisterClickTarget(record.target)
      if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
    }
    pluginObjectOwners = pluginObjectOwners.filter(function(record) {
      return record && record.pluginId !== pluginId
    })
  }

  function prunePluginBarApis() {
    var next = ({})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (root.pluginBarApiUsed(id)) {
        next[id] = api
        continue
      }
      root.releasePluginObjects(id)
      if (api && typeof api.destroy === "function") api.destroy()
    }
    pluginBarApis = next
  }

  onActivePopoutChanged: syncAllPluginBarApiObjects()
  onClickTargetsChanged: syncAllPluginBarApiObjects()
  onLayoutConfigChanged: syncAllPluginBarApiObjects()
  onModuleSlotsChanged: Qt.callLater(prunePluginBarApis)

  Component.onDestruction: {
    for (var id in pluginBarApis) {
      root.releasePluginObjects(id)
      if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
        pluginBarApis[id].destroy()
    }
    pluginBarApis = ({})
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragTargetGeometry = null
    barDragAfter = false
    barDragSceneX = 0
    barDragSceneY = 0
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  function dropMarkerRect(slot, after) {
    if (!slot) return null

    try {
      var slotPoint = slot.mapToItem(null, 0, 0)
      var screenPoint = barDragScreenPoint(slotPoint)
      var thickness = Style.spacing.xs
      if (vertical) {
        return {
          x: screenPoint.x,
          y: screenPoint.y + (after ? slot.height : 0) - thickness / 2,
          width: slot.width,
          height: thickness
        }
      }

      return {
        x: screenPoint.x + (after ? slot.width : 0) - thickness / 2,
        y: screenPoint.y,
        width: thickness,
        height: slot.height
      }
    } catch (e) {
      return null
    }
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Apply tray-pinning on top of the shared layout normalization so the
  // bar host and scriptable config helpers can't drift on entry shape.
  function normalizeLayout(layout) {
    var normalized = Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
    return {
      left:   pinTrayToInner(normalized.left,   "left"),
      center: pinTrayToInner(normalized.center, "center"),
      right:  pinTrayToInner(normalized.right,  "right")
    }
  }

  // The tray drawer reveals inward (away from the bar edge). Place it at the
  // section's inner edge: start of the right section, end of the left/center
  // sections. The drawer's reserved space then sits next to the bar center,
  // not stranded mid-section.
  function pinTrayToInner(entries, section) {
    return BarModel.pinTrayToInner(entries, section)
  }

  function applyBarConfig() {
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    // layoutEntries feeds plain JS arrays to the module Repeaters, and QML
    // cannot diff those: reassigning layoutConfig rebuilds every widget on
    // every monitor. When a shell.json write only changed inline widget
    // settings, patch the live layout and running widgets in place instead.
    var next = normalizeLayout(config.layout)
    var delta = BarModel.inlineSettingsDelta(layoutConfig, next)
    if (delta) {
      applySettingsDelta(delta)
      return
    }
    layoutConfig = next
    barConfigSerial++
  }

  function applySettingsDelta(delta) {
    for (var i = 0; i < delta.length; i++) {
      var change = delta[i]
      layoutConfig[change.region][change.index] = change.entry
      var settings = entrySettings(change.entry)
      for (var s = 0; s < moduleSlots.length; s++) {
        var slot = moduleSlots[s]
        if (!slot || slot.region !== change.region || slot.moduleName !== entryId(change.entry)) continue
        var item = slot.activeItem
        if (item && "settings" in item) item.settings = settings
      }
    }
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Keep the load widget in its own island beside the system island.
  function leftIslandEntries() {
    var entries = root.layoutEntries("left")
    return entries.filter(function(entry) { return root.entryId(entry) !== "jeebis.load" })
  }

  function leftLoadEntries() {
    var entries = root.layoutEntries("left")
    return entries.filter(function(entry) { return root.entryId(entry) === "jeebis.load" })
  }

  function rightIslandEntries() {
    return root.layoutEntries("right").filter(function(entry) {
      return root.entryId(entry) !== "jeebis.notifications"
    })
  }

  function rightNotificationEntries() {
    return root.layoutEntries("right").filter(function(entry) {
      return root.entryId(entry) === "jeebis.notifications"
    })
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = -1
    for (var j = 0; j < slots.length; j++) {
      if (slots[j] === currentSlot) {
        currentIndex = j
        break
      }
    }
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function moduleString(entry, key, fallback) {
    return BarModel.moduleString(entry, key, fallback)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }

  function entriesBefore(entries, name) {
    return BarModel.entriesBefore(entries, name)
  }

  function entriesAfter(entries, name) {
    return BarModel.entriesAfter(entries, name)
  }

  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function expandPath(path) {
    return BarModel.expandPath(path, home)
  }

  function customModuleSafeName(name) {
    return BarModel.customModuleSafeName(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: applyBarConfig()

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: Timing.barInteraction.releasingMs
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function performModuleDoubleClick(moduleName) {
    var action = BarActions.actionFor(moduleName)
    if (!action) return false
    if (root.activePopout && typeof root.activePopout.close === "function")
      root.activePopout.close()
    root.run(Util.shellQuote(root.home + "/.local/bin/jeebis-bar-action") + " " + action)
    return true
  }

  function performIslandDoubleClick(area, x, y) {
    var window = root.targetWindow(area)
    var point = area.mapToItem(null, x, y)
    for (var i = 0; i < root.moduleSlots.length; i++) {
      var slot = root.moduleSlots[i]
      if (!slot || slot.width <= 0 || slot.height <= 0
          || !root.sameWindow(window, root.targetWindow(slot))) continue
      if (!BarActions.actionFor(slot.moduleName)) continue
      var origin = slot.mapToItem(null, 0, 0)
      var padding = Style.space(8)
      if (point.x >= origin.x - padding && point.x <= origin.x + slot.width + padding
          && point.y >= origin.y - padding && point.y <= origin.y + slot.height + padding)
        return root.performModuleDoubleClick(slot.moduleName)
    }
    return false
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function rawEntryIndex(entries, name) {
    for (var i = 0; i < entries.length; i++) {
      if (root.entryId(entries[i]) === name) return i
    }

    return -1
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = rawEntryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? rawEntryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
    }

    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var slotPoint = { x: slot.x, y: slot.y }
      try {
        slotPoint = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }

      candidates.push({
        slot: slot,
        x: slotPoint.x,
        y: slotPoint.y,
        width: slot.width,
        height: slot.height
      })
    }

    return BarModel.nearestDropTarget(candidates, scenePoint, root.vertical)
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  function restoreForegroundAnimation() {
    Qt.callLater(function() {
      Qt.callLater(function() { root.foregroundAnimationEnabled = true })
    })
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: scheduleTransparentForegroundRefresh()
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: Timing.tooltip.preparingMs
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: Timing.tooltip.releasingMs
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // The directory watch can permanently stop delivering events after flag
  // changes land in quick succession, stranding the bar off screen until the
  // shell restarts. `omarchy-toggle-bar` nudges this after flipping the flag
  // so the probe re-reads it even when the watch has gone quiet.
  IpcHandler {
    target: "omarchy.bar"

    // Start rather than restart: a probe already in flight was launched by the
    // directory watch after the flag flipped, so its answer is current, and
    // killing it here can swallow the result entirely.
    function syncHidden(): void {
      barHiddenProbe.running = true
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    // Hiding parks the bar just past its screen edge instead of unmapping it.
    // Unmapping frees the layer surface and the whole scene graph, so every
    // reveal has to rebuild them — new surface, re-shaped glyphs, re-uploaded
    // textures — which measures ~150ms against ~20ms to tear down. Parking
    // keeps the surface alive, so showing is only a margin change.
    visible: !remapGuard.remapping
    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }

    margins {
      top: root.barHidden && root.position === "top" ? -(root.barSize + 2) : 0
      bottom: root.barHidden && root.position === "bottom" ? -root.barSize : (root.position === "bottom" ? 2 : 0)
      left: root.barHidden && root.position === "left" ? -root.barSize : (root.vertical && root.position === "left" ? 2 : 0)
      right: root.barHidden && root.position === "right" ? -root.barSize : (root.vertical && root.position === "right" ? 2 : 0)
    }

    anchors {
      top: root.position === "top" || root.vertical
      bottom: root.position === "bottom" || root.vertical
      left: root.position === "left" || !root.vertical
      right: root.position === "right" || !root.vertical
    }

    implicitWidth: root.vertical ? root.barSize : 0
    implicitHeight: root.vertical ? 0 : root.barSize + (root.position === "top" ? 2 : 0)
    color: "transparent"
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    Loader {
      anchors.fill: parent
      anchors.topMargin: root.position === "top" ? 2 : 0
      sourceComponent: root.vertical ? verticalBar : horizontalBar

      // A child of the loader, not a sibling of the sections: an ancestor stays
      // hovered while the pointer is over a widget, where a sibling would lose
      // hover to the section the pointer entered.
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        // Unplugging a monitor destroys its bar without a leave event, which
        // would strand this surface's tally and hold the peek open for good.
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var popupWidth = tooltipWindow.implicitWidth
          var popupHeight = tooltipWindow.implicitHeight
          var localX = target.width / 2 - popupWidth / 2
          var localY = target.height + 6

          if (root.position === "bottom") {
            localY = -popupHeight - 6
          } else if (root.position === "left") {
            localX = target.width + 6
            localY = target.height / 2 - popupHeight / 2
          } else if (root.position === "right") {
            localX = -popupWidth - 6
            localY = target.height / 2 - popupHeight / 2
          }

          var point = barWindow.contentItem.mapFromItem(target, localX, localY)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }

    Component {
      id: horizontalBar

      Item {
        anchors.fill: parent

        CenterModules { anchors.fill: parent }

        LeftModules {
          id: leftModules
          entries: root.leftIslandEntries()
          anchors.left: parent.left
          anchors.leftMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          z: 1
        }

        Rectangle {
          enabled: false
          z: 0
          x: leftModules.x - Style.space(8)
          y: Math.round((parent.height - height) / 2)
          width: leftModules.width + Style.space(16)
          height: root.barSize
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        ModuleList {
          id: leftLoadModules
          entries: root.leftLoadEntries()
          region: "left"
          anchors.left: leftModules.right
          anchors.leftMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          z: 1
        }

        Rectangle {
          enabled: false
          z: 0
          visible: leftLoadModules.width > 0
          opacity: leftLoadModules.islandRevealProgress
          x: leftLoadModules.x - Style.space(8) * leftLoadModules.islandRevealProgress
          y: Math.round((parent.height - height) / 2)
          width: leftLoadModules.width + Style.space(16) * leftLoadModules.islandRevealProgress
          height: root.barSize * (0.84 + 0.16 * leftLoadModules.islandRevealProgress)
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        ModuleList {
          id: rightNotificationModules
          entries: root.rightNotificationEntries()
          region: "right"
          anchors.right: rightModules.left
          anchors.rightMargin: Style.space(16)
          anchors.verticalCenter: parent.verticalCenter
          z: 1
        }

        Rectangle {
          enabled: false
          z: 0
          visible: rightNotificationModules.width > 0
          opacity: rightNotificationModules.islandRevealProgress
          x: rightNotificationModules.x - Style.space(8) * rightNotificationModules.islandRevealProgress
          y: Math.round((parent.height - height) / 2)
          width: rightNotificationModules.width + Style.space(16) * rightNotificationModules.islandRevealProgress
          height: root.barSize * (0.84 + 0.16 * rightNotificationModules.islandRevealProgress)
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        RightModules {
          id: rightModules
          entries: root.rightIslandEntries()
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          z: 1
        }

        Rectangle {
          enabled: false
          z: 0

          // The tray keeps its full drawer width for hit-testing while closed.
          // Shrink the capsule by that hidden portion, then let it grow with
          // the tray's own animated revealProgress as the icons slide out.
          readonly property var traySlot: {
            var slots = root.moduleSlots
            for (var i = 0; i < slots.length; i++) {
              var slot = slots[i]
              if (!slot || slot.region !== "right" || slot.moduleName !== "omarchy.tray") continue
              if (root.sameWindow(root.slotWindow(slot), barWindow)) return slot
            }
            return null
          }
          readonly property var trayWidget: traySlot ? traySlot.activeItem : null
          readonly property real hiddenTrayExtent: trayWidget && trayWidget.drawerExtent !== undefined
            ? trayWidget.drawerExtent * (1 - Number(trayWidget.revealProgress || 0))
            : 0

          x: rightModules.x - Style.space(8) + hiddenTrayExtent
          y: Math.round((parent.height - height) / 2)
          width: Math.max(Style.space(16), rightModules.width + Style.space(16) - hiddenTrayExtent)
          height: root.barSize
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }
      }
    }

    Component {
      id: verticalBar

      Item {
        anchors.fill: parent

        CenterModules { anchors.fill: parent }

        LeftModules {
          anchors.top: parent.top
          anchors.topMargin: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
        }

        RightModules {
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(8)
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }

  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: root.transparent ? 0.45 : 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }

    Rectangle {
      readonly property var targetRect: root.barDragTargetGeometry

      visible: ghostWindow.active && targetRect !== null
      x: targetRect ? Math.round(targetRect.x) : 0
      y: targetRect ? Math.round(targetRect.y) : 0
      width: targetRect ? targetRect.width : 0
      height: targetRect ? targetRect.height : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
    }
  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

        Behavior on opacity {
          NumberAnimation { duration: Timing.edgePreview.changingMs; easing.type: Easing.OutCubic }
        }
      }
    }
  }

  readonly property bool loadIslandVisible: {
    var slots = root.moduleSlots
    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      if (slot.moduleName === "jeebis.load" && slot.activeItem
          && slot.activeItem.visible && slot.activeItem.islandRevealProgress > 0) return true
    }
    return false
  }

  property string lastCompanion: "apps"
  readonly property bool appsHaveApplications: {
    var widgets = root.moduleWidgets("jeebis.apps")
    for (var i = 0; i < widgets.length; i++)
      if (widgets[i].hasApplications) return true
    return false
  }
  onAppsHaveApplicationsChanged: Qt.callLater(syncCompanionHover)
  property string centerHoverCompanion: "apps"
  property int centralCompanionHoverCount: 0
  onCentralCompanionHoverCountChanged: Qt.callLater(syncCompanionHover)
  readonly property int appsPresentationSerial: {
    var widgets = root.moduleWidgets("jeebis.apps")
    var serial = 0
    for (var i = 0; i < widgets.length; i++) serial += widgets[i].revealSerial
    return serial
  }
  onAppsPresentationSerialChanged: {
    if (companionTrackingReady && !AgentModel.kind(Hyprland.activeToplevel)) lastCompanion = "apps"
  }
  onAgentActivitySequenceActiveChanged: if (agentActivitySequenceActive) lastCompanion = "agent"
  property int agentHoverCount: 0
  property int workspaceHoverCount: 0
  property int appsHoverCount: 0
  property bool previousAgentPointerHeld: false
  property bool agentHoverHeld: false
  property bool agentLaunchPulse: false
  property bool companionTrackingReady: false
  property string previousAgentSignature: ""
  property var agentWindowArchive: ({})
  property var pendingAgentClosures: []
  readonly property bool agentActivitySequenceActive: {
    var slots = root.moduleSlots
    for (var i = 0; i < slots.length; i++) {
      var slot = slots[i]
      if (slot.moduleName === "jeebis.agent-launchers" && slot.activeItem && slot.activeItem.activitySequence) return true
    }
    return false
  }
  function agentAddressKey(address) { return String(address || "").toLowerCase().replace(/^0x/, "") }
  function archiveAgentWindows() {
    var archive = Object.assign({}, agentWindowArchive)
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < clients.length; i++) {
      var kind = AgentModel.kind(clients[i])
      if (kind) archive[agentAddressKey(clients[i].address)] = kind
    }
    agentWindowArchive = archive
  }
  function animateAgentOpens(kinds) {
    var running = ({})
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < clients.length; i++) {
      var kind = AgentModel.kind(clients[i])
      if (kind) running[kind] = true
    }
    var widgets = root.moduleWidgets("jeebis.agent-launchers")
    var played = false
    for (var j = 0; j < kinds.length; j++) {
      if (!running[kinds[j]]) continue
      for (var n = 0; n < widgets.length; n++) widgets[n].playOpen(kinds[j])
      played = true
    }
    if (played) {
      agentLaunchPulse = false
      agentLaunchTimer.stop()
    }
  }
  function rememberAgentClose(address) {
    var key = agentAddressKey(address)
    var kind = agentWindowArchive[key]
    if (!kind) return
    var pending = pendingAgentClosures.slice()
    pending.push({ address: key, kind: kind })
    pendingAgentClosures = pending
    var archive = Object.assign({}, agentWindowArchive)
    delete archive[key]
    agentWindowArchive = archive
    Qt.callLater(flushAgentClosures)
  }
  function flushAgentClosures() {
    var clients = Hyprland.toplevels.values
    var addresses = ({})
    var running = ({})
    for (var i = 0; i < clients.length; i++) {
      addresses[agentAddressKey(clients[i].address)] = AgentModel.kind(clients[i])
      var kind = AgentModel.kind(clients[i])
      if (kind) running[kind] = true
    }
    var deferred = []
    for (var j = 0; j < pendingAgentClosures.length; j++) {
      var closed = pendingAgentClosures[j]
      if (addresses[closed.address] === closed.kind) { deferred.push(closed); continue }
      if (running[closed.kind]) continue
      var widgets = root.moduleWidgets("jeebis.agent-launchers")
      for (var n = 0; n < widgets.length; n++) widgets[n].playExit(closed.kind)
      root.agentLaunchPulse = false
      agentLaunchTimer.stop()
    }
    pendingAgentClosures = deferred
    if (deferred.length > 0) agentCloseRetry.restart()
  }
  Timer { id: agentCloseRetry; interval: 40; onTriggered: root.flushAgentClosures() }

  readonly property string agentSignature: {
    var addresses = []
    var clients = Hyprland.toplevels.values
    for (var i = 0; i < clients.length; i++)
      if (AgentModel.kind(clients[i]) !== "") addresses.push(String(clients[i].address))
    addresses.sort()
    return addresses.join(",")
  }
  readonly property bool agentOnFocusedWorkspace: {
    var workspace = Hyprland.focusedWorkspace
    var clients = workspace && workspace.toplevels ? workspace.toplevels.values : []
    for (var i = 0; i < clients.length; i++)
      if (AgentModel.kind(clients[i]) !== "") return true
    return false
  }
  readonly property int focusedWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  onFocusedWorkspaceIdChanged: Qt.callLater(revealAgentForWorkspace)
  onAgentOnFocusedWorkspaceChanged: Qt.callLater(syncCompanionHover)
  onAgentHoverCountChanged: Qt.callLater(syncCompanionHover)
  onWorkspaceHoverCountChanged: Qt.callLater(syncCompanionHover)
  onAppsHoverCountChanged: Qt.callLater(syncCompanionHover)

  function syncCompanionHover() {
    var central = centralCompanionHoverCount > 0
    if (central && centerHoverCompanion === "apps" && !appsHaveApplications)
      centerHoverCompanion = "agent"
    var agentDirect = !central && agentHoverCount > 0
    var appsDirect = !central && appsHoverCount > 0
    if (agentDirect) lastCompanion = "agent"
    else if (appsDirect) lastCompanion = "apps"
    var agentHeld = agentDirect || (central && centerHoverCompanion === "agent")
      || (workspaceHoverCount > 0 && agentOnFocusedWorkspace)
    if (agentHeld) {
      agentExitTimer.stop()
      agentHoverHeld = true
    } else if (previousAgentPointerHeld) {
      agentExitTimer.restart()
    }
    previousAgentPointerHeld = agentHeld
    var launchers = root.moduleWidgets("jeebis.agent-launchers")
    for (var j = 0; j < launchers.length; j++) launchers[j].setExpanded(agentDirect || (central && centerHoverCompanion === "agent"))
    var widgets = root.moduleWidgets("jeebis.apps")
    for (var i = 0; i < widgets.length; i++)
      widgets[i].setHoverHeld(workspaceHoverCount > 0 || appsDirect || (central && centerHoverCompanion === "apps"))
  }

  function revealAgent() {
    lastCompanion = "agent"
    if (agentActivitySequenceActive) return
    agentLaunchPulse = true
    agentLaunchTimer.restart()
  }
  function revealAgentForWorkspace() {
    if (!companionTrackingReady) return
    if (agentOnFocusedWorkspace) revealAgent()
    else {
      agentLaunchPulse = false
      agentLaunchTimer.stop()
    }
  }

  onAgentSignatureChanged: {
    var previous = previousAgentSignature.split(",")
    var current = agentSignature ? agentSignature.split(",") : []
    var added = current.some(function(address) { return previous.indexOf(address) === -1 })
    previousAgentSignature = agentSignature
    // A Codex process may end while its WezTerm window stays open. Treat the
    // classification change like an Agent close, without waiting for closewindow.
    if (companionTrackingReady) {
      var clientsNow = Hyprland.toplevels.values
      for (var r = 0; r < previous.length; r++) {
        if (!previous[r] || current.indexOf(previous[r]) >= 0) continue
        for (var c = 0; c < clientsNow.length; c++) {
          if (agentAddressKey(clientsNow[c].address) === agentAddressKey(previous[r])
              && !AgentModel.kind(clientsNow[c])) root.rememberAgentClose(previous[r])
        }
      }
    }
    if (companionTrackingReady && added) {
      var alreadyRunning = ({})
      for (var i = 0; i < previous.length; i++) {
        var kind = agentWindowArchive[agentAddressKey(previous[i])]
        if (kind) alreadyRunning[kind] = true
      }
      var opens = []
      var clients = Hyprland.toplevels.values
      for (var j = 0; j < clients.length; j++) {
        var kind = AgentModel.kind(clients[j])
        if (kind && !alreadyRunning[kind] && opens.indexOf(kind) === -1) opens.push(kind)
      }
      if (opens.length > 0) Qt.callLater(root.animateAgentOpens, opens)
      else revealAgent()
    }
    Qt.callLater(root.archiveAgentWindows)
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "closewindow") root.rememberAgentClose(event.data)
      if (event && ((event.name === "custom" && String(event.data) === "jeebis.apps.reveal")
          || event.name === "workspacev2")) Qt.callLater(root.revealAgentForWorkspace)
    }
  }
  Timer {
    id: agentExitTimer
    interval: Timing.agentIsland.releasingMs
    onTriggered: {
      root.agentHoverHeld = false
      root.agentLaunchPulse = false
      agentLaunchTimer.stop()
    }
  }
  Timer { id: agentLaunchTimer; interval: Timing.agentIsland.presentMs; onTriggered: root.agentLaunchPulse = false }
  Timer { interval: 1; running: true; onTriggered: root.companionTrackingReady = true }

  function findCenterAnchorEntry() {
    var entries = root.layoutEntries("center")
    var idx = root.entryIndex(entries, root.centerAnchor)
    return idx === -1 ? null : entries[idx]
  }

  component LeftModules: ModuleList {
    entries: root.layoutEntries("left")
    region: "left"
  }

  component RightModules: ModuleList {
    entries: root.layoutEntries("right")
    region: "right"
  }

  component CenterModules: Item {
    id: centerRoot

    property var entries: root.layoutEntries("center")
    readonly property bool hasAnchor: root.entryIndex(entries, root.centerAnchor) !== -1
    readonly property var anchorEntry: root.findCenterAnchorEntry()

    Loader {
      anchors.fill: parent
      sourceComponent: root.vertical ? verticalCenterModules : horizontalCenterModules
    }

    Component {
      id: horizontalCenterModules

      Item {
        id: horizontalLayout
        anchors.fill: parent
        readonly property real workspacePresence: Math.max(0, Math.min(1, centerAnchorModule.islandRevealProgress))
        readonly property real packedGap: (centerBeforeModules.islandRevealProgress > 0 && centerAfterModules.islandRevealProgress > 0 ? Style.space(16) : 0) * Math.min(1,
          centerBeforeModules.width / Style.bar.iconSlot, centerAfterModules.width / Style.bar.iconSlot)
        // A shared balance keeps both capsule edges separated while they move.
        // One visible island has its own midpoint exactly on the screen center.
        readonly property bool bothCompanions: centerBeforeModules.width > 0 && centerAfterModules.width > 0 && centerBeforeModules.islandRevealProgress > 0 && centerAfterModules.islandRevealProgress > 0
        property bool agentWasPresent: false
        property bool appsWerePresent: false
        property bool agentEnteredBeside: false
        property bool appsEnteredBeside: false
        property bool agentBornAlone: false
        property bool appsBornAlone: false
        function noteEntry(agent) {
          var group = agent ? centerBeforeModules : centerAfterModules
          var other = agent ? centerAfterModules : centerBeforeModules
          if (!group) return
          var present = group.width > 0 && group.islandRevealProgress > 0
          var previous = agent ? agentWasPresent : appsWerePresent
          if (present && !previous) {
            var beside = other && other.islandRevealProgress > 0
            if (agent) {
              agentEnteredBeside = !!beside
              agentBornAlone = !beside
              if (beside) appsBornAlone = false
            } else {
              appsEnteredBeside = !!beside
              appsBornAlone = !beside
              if (beside) agentBornAlone = false
            }
          }
          if (agent) agentWasPresent = present
          else appsWerePresent = present
        }
        readonly property real agentEntryX: workspacePresence < 0.001 && agentEnteredBeside
          ? -Style.space(16) * (1 - centerBeforeModules.islandRevealProgress) : 0
        readonly property real appsEntryX: workspacePresence < 0.001 && appsEnteredBeside && !centerAfterModules.forceTopEntry && !centerAfterModules.entryExiting
          ? Style.space(16) * (1 - centerAfterModules.islandRevealProgress) : 0
        readonly property real agentEntryY: workspacePresence < 0.001 && !agentEnteredBeside
          ? -(root.barSize + Style.space(8)) * (1 - centerBeforeModules.islandRevealProgress) : 0
        readonly property real appsEntryY: (workspacePresence < 0.001 && (!appsEnteredBeside || centerAfterModules.entryExiting)) || centerAfterModules.forceTopEntry
          ? -(root.barSize + Style.space(8)) * (1 - centerAfterModules.islandRevealProgress) : 0
        property real packedBalance: bothCompanions ? 0 : (centerBeforeModules.width - centerAfterModules.centeringWidth) / 2
        readonly property real agentPackedBalance: bothCompanions ? Math.min(-Math.max(0, Style.space(8) - packedGap / 2), packedBalance) : (agentBornAlone ? centerBeforeModules.width / 2 : packedBalance)
        readonly property real appsPackedBalance: bothCompanions ? Math.max(Math.max(0, Style.space(8) - packedGap / 2), packedBalance) : ((appsBornAlone || centerAfterModules.centerRepositioning || centerAfterModules.entryExiting) ? -centerAfterModules.centeringWidth / 2 : packedBalance)
        Behavior on packedBalance {
          enabled: horizontalLayout.workspacePresence < 1 && !centerAfterModules.centerRepositioning
          NumberAnimation { duration: Timing.centerCompanions.movingMs; easing.type: Easing.InOutCubic }
        }
        function blend(packed, anchored) {
          return packed * (1 - workspacePresence) + anchored * workspacePresence
        }

        CenterGestureArea { anchors.fill: parent }

        // This fixed hotspot only starts when both islands are hidden. Latch
        // one owner until pointer exit, so moving hover bounds cannot open both.
        Item {
          x: (parent.width - width) / 2
          width: Style.bar.iconSlot
          height: root.barSize
          anchors.verticalCenter: parent.verticalCenter
          visible: centerRoot.hasAnchor && horizontalLayout.workspacePresence < 0.001
          HoverHandler {
            enabled: root.centralCompanionHoverCount > 0
              || (centerBeforeModules.width <= 0 && centerAfterModules.width <= 0)
            onHoveredChanged: {
              if (hovered) root.centerHoverCompanion = root.lastCompanion === "apps" && !root.appsHaveApplications
                ? "agent" : root.lastCompanion
              root.centralCompanionHoverCount = Math.max(0, root.centralCompanionHoverCount + (hovered ? 1 : -1))
            }
            Component.onDestruction: if (hovered)
              root.centralCompanionHoverCount = Math.max(0, root.centralCompanionHoverCount - 1)
          }
        }

        Rectangle {
          enabled: false
          z: -1
          visible: centerRoot.hasAnchor && root.position !== "top" && centerAnchorModule.width > 0
          opacity: centerAnchorModule.islandRevealProgress
          x: centerAnchorModule.x - Style.space(8) * centerAnchorModule.islandRevealProgress
          y: Math.round((parent.height - height) / 2)
          width: centerAnchorModule.width + Style.space(16) * centerAnchorModule.islandRevealProgress
          height: root.barSize * (0.84 + 0.16 * centerAnchorModule.islandRevealProgress)
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        Rectangle {
          id: workspaceBump
          enabled: false
          z: -1
          visible: centerRoot.hasAnchor && root.position === "top" && centerAnchorModule.width > 0 && centerAnchorModule.islandRevealProgress > 0
          opacity: 1
          x: centerAnchorModule.x - Style.space(8)
          y: Math.round((parent.height - height) / 2) - (root.barSize + 2) * (1 - centerAnchorModule.islandRevealProgress)
          width: centerAnchorModule.width + Style.space(16)
          height: root.barSize
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchors.centerIn: parent
        }

        ModuleList {
          id: centerBeforeModules
          onWidthChanged: horizontalLayout.noteEntry(true)
          onIslandRevealProgressChanged: horizontalLayout.noteEntry(true)
          transform: Translate { x: horizontalLayout.agentEntryX; y: horizontalLayout.agentEntryY }
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          x: horizontalLayout.blend(
            parent.width / 2 + horizontalLayout.agentPackedBalance - horizontalLayout.packedGap / 2 - width,
            centerAnchorModule.x - Style.space(16) * islandRevealProgress - width)
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }

        Rectangle {
          enabled: false
          z: -1
          visible: centerRoot.hasAnchor && centerBeforeModules.width > 0
          opacity: centerBeforeModules.islandRevealProgress
          x: centerBeforeModules.x + horizontalLayout.agentEntryX - Style.space(8) * centerBeforeModules.islandRevealProgress
          y: Math.round((parent.height - height) / 2) + horizontalLayout.agentEntryY
          width: centerBeforeModules.width + Style.space(16) * centerBeforeModules.islandRevealProgress
          height: root.barSize * (0.84 + 0.16 * centerBeforeModules.islandRevealProgress)
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }

        // Keep a hover target at the agent island's final position, even hidden.
        Item {
          visible: centerRoot.hasAnchor
          x: horizontalLayout.blend(
            parent.width / 2 + horizontalLayout.agentPackedBalance + Math.min(0, Style.space(8) - horizontalLayout.packedGap / 2)
              - (centerBeforeModules.width > 0 ? 0 : Style.space(16) - Style.space(8)),
            centerAnchorModule.x - Style.space(8)) - width
          anchors.verticalCenter: centerAnchorModule.verticalCenter
          width: Math.max(Style.bar.iconSlot, centerBeforeModules.hoverTargetWidth) + Style.space(16)
          height: root.barSize
          HoverHandler {
            onHoveredChanged: root.agentHoverCount = Math.max(0, root.agentHoverCount + (hovered ? 1 : -1))
            Component.onDestruction: if (hovered) root.agentHoverCount = Math.max(0, root.agentHoverCount - 1)
          }
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          anchors.centerIn: parent
          transform: Translate {
            y: root.position === "top" ? -(root.barSize + 2) * (1 - centerAnchorModule.islandRevealProgress) : 0
          }
          Item {
            anchors.fill: parent
            anchors.leftMargin: -Style.space(8)
            anchors.rightMargin: -Style.space(8)
            HoverHandler {
              onHoveredChanged: {
                root.workspaceHoverCount = Math.max(0, root.workspaceHoverCount + (hovered ? 1 : -1))
              }
              Component.onDestruction: if (hovered) root.workspaceHoverCount = Math.max(0, root.workspaceHoverCount - 1)
            }
          }
        }

        ModuleList {
          id: centerAfterModules
          onWidthChanged: horizontalLayout.noteEntry(false)
          onIslandRevealProgressChanged: horizontalLayout.noteEntry(false)
          transform: Translate { x: horizontalLayout.appsEntryX; y: horizontalLayout.appsEntryY }
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          x: horizontalLayout.blend(
            parent.width / 2 + horizontalLayout.appsPackedBalance + horizontalLayout.packedGap / 2,
            centerAnchorModule.x + centerAnchorModule.width + Style.space(16))
          anchors.verticalCenter: centerAnchorModule.verticalCenter
        }

        Item {
          visible: centerRoot.hasAnchor && centerAfterModules.hoverTargetWidth > 0
          // The hit target stays at the final resting position during motion.
          x: horizontalLayout.blend(
            parent.width / 2 + horizontalLayout.appsPackedBalance + Math.max(0, horizontalLayout.packedGap / 2 - Style.space(8))
              + (centerAfterModules.width > 0 ? 0 : Style.space(16) - Style.space(8)),
            centerAnchorModule.x + centerAnchorModule.width + Style.space(8))
          width: centerAfterModules.hoverTargetWidth + Style.space(16)
          height: root.barSize
          anchors.verticalCenter: centerAnchorModule.verticalCenter
          HoverHandler {
            onHoveredChanged: root.appsHoverCount = Math.max(0, root.appsHoverCount + (hovered ? 1 : -1))
            Component.onDestruction: if (hovered) root.appsHoverCount = Math.max(0, root.appsHoverCount - 1)
          }
        }

        Rectangle {
          enabled: false
          z: -1
          visible: centerRoot.hasAnchor && centerAfterModules.mainIslandWidth > 0
          opacity: centerAfterModules.islandRevealProgress
          x: centerAfterModules.x + horizontalLayout.appsEntryX + centerAfterModules.mainIslandOffsetX - Style.space(8) * centerAfterModules.islandRevealProgress
          y: Math.round((parent.height - height) / 2) + horizontalLayout.appsEntryY
          width: centerAfterModules.mainIslandWidth + Style.space(16) * centerAfterModules.islandRevealProgress
          height: root.barSize * (0.84 + 0.16 * centerAfterModules.islandRevealProgress)
          radius: height / 2
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.94)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        }
      }
    }

    Component {
      id: verticalCenterModules

      Item {
        anchors.fill: parent

        CenterGestureArea { anchors.fill: parent }

        HoverHandler {
          onHoveredChanged: root.setCenterSectionHovered(hovered)
        }

        ModuleList {
          visible: !centerRoot.hasAnchor
          entries: centerRoot.entries
          region: "center"
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesBefore(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.bottom: centerAnchorModule.top
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }

        ModuleSlot {
          id: centerAnchorModule
          visible: centerRoot.hasAnchor
          entry: centerRoot.anchorEntry
          region: "center"
          anchors.centerIn: parent
        }

        ModuleList {
          visible: centerRoot.hasAnchor
          entries: root.entriesAfter(centerRoot.entries, root.centerAnchor)
          region: "center"
          anchors.top: centerAnchorModule.bottom
          anchors.horizontalCenter: centerAnchorModule.horizontalCenter
        }
      }
    }
  }

  component CenterGestureArea: MouseArea {
    id: gestureArea

    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.ArrowCursor

    // Bar placement is fixed. Double-click opens Omarchy's existing preview
    // picker; presses, long presses, and pointer movement never move the bar.
    onDoubleClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) {
        mouse.accepted = root.performIslandDoubleClick(gestureArea, mouse.x, mouse.y)
      }
    }
  }

  component ModuleList: Loader {
    id: moduleListRoot

    property var entries: []
    property string region: ""
    readonly property real mainIslandOffsetX: {
      var slots = root.moduleSlots
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (slot && slot.parent === moduleListRoot.item && slot.activeItem
            && "mainIslandOffsetX" in slot.activeItem) return slot.activeItem.mainIslandOffsetX
      }
      return 0
    }
    readonly property real centeringWidth: {
      var slots = root.moduleSlots
      var width = 0
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (!slot || slot.parent !== moduleListRoot.item || !slot.activeItem) continue
        width += "centeringWidth" in slot.activeItem ? slot.activeItem.centeringWidth : slot.width
      }
      return width
    }
    readonly property bool centerRepositioning: companionFlag("centerRepositioning")
    readonly property bool forceTopEntry: companionFlag("forceTopEntry")
    readonly property bool entryExiting: companionFlag("entryExiting")
    function companionFlag(name) {
      var slots = root.moduleSlots
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (slot && slot.parent === moduleListRoot.item && slot.activeItem
            && name in slot.activeItem && slot.activeItem[name]) return true
      }
      return false
    }
    readonly property real mainIslandWidth: {
      var width = 0
      var slots = root.moduleSlots
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (!slot || slot.parent !== moduleListRoot.item || !slot.activeItem) continue
        width += "mainIslandWidth" in slot.activeItem ? slot.activeItem.mainIslandWidth : slot.width
      }
      return width
    }
    readonly property real hoverTargetWidth: {
      var width = 0
      var slots = root.moduleSlots
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (!slot || slot.parent !== moduleListRoot.item || !slot.activeItem) continue
        width += "hoverTargetWidth" in slot.activeItem ? slot.activeItem.hoverTargetWidth
          : (slot.companionAgent ? slot.activeItem.implicitWidth : slot.width)
      }
      return width
    }
    // Widgets with transient islands expose their animated progress so the
    // surrounding background and its padding follow the same timeline.
    readonly property real islandRevealProgress: {
      var slots = root.moduleSlots
      var progress = 0
      for (var i = 0; i < slots.length; i++) {
        var slot = slots[i]
        if (!slot || slot.parent !== moduleListRoot.item || !slot.activeItem) continue
        var value = slot.islandRevealProgress
        progress = Math.max(progress, value)
      }
      return progress
    }

    visible: entries.length > 0
    // A hidden list must not build its modules. The center section declares
    // both an anchored and an unanchored arrangement and shows whichever
    // fits, so leaving the other one loaded mounts every center module
    // twice — two IPC handlers registered for the same target, two clocks
    // ticking, two of every timer and fetch behind them.
    active: visible && entries.length > 0
    sourceComponent: root.vertical ? verticalModuleList : horizontalModuleList
    width: item ? item.implicitWidth : 0
    height: item ? item.implicitHeight : 0

    Component {
      id: horizontalModuleList

      Row {
        spacing: 0

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            required property int index
            entry: modelData
            region: moduleListRoot.region
            showSeparator: moduleListRoot.region === "left" && index > 0
          }
        }
      }
    }

    Component {
      id: verticalModuleList

      Column {
        spacing: 0

        Repeater {
          model: moduleListRoot.entries

          ModuleSlot {
            required property var modelData
            entry: modelData
            region: moduleListRoot.region
          }
        }
      }
    }
  }

  component ModuleSlot: Item {
    id: slot

    required property var entry
    property string region: ""
    property bool showSeparator: false
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property string customType: root.customModuleType(entry)
    readonly property var registryMetadata: root.barWidgetRegistry.metadataFor(root.canonicalWidgetId(moduleName))
    readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
    readonly property string pluginApiId: registered ? root.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
    // Re-evaluate when the registry mutates (Component reference changes,
    // plugin enabled/disabled, etc.). Reading the `widgets` property creates
    // the binding dependency — the wrapped function call alone wouldn't.
    readonly property var registryComponent: {
      var w = root.barWidgetRegistry.widgets
      if (customType) return null
      var registryName = root.canonicalWidgetId(moduleName)
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool qmlCustom: customType === "qml"
    readonly property bool commandCustom: customType === "command"
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: {
      if (registered) return registryLoader.item
      if (qmlCustom) return qmlLoader.item
      return componentLoader.item
    }
    readonly property bool companionAgent: moduleName === "omarchy.agents" && region === "center"
    // A popup temporarily owns pointer input, hiding the bar's hover state.
    // Keep the capsule alive while its close returns input to the bar.
    property bool agentPanelGrace: false
    onPanelOpenChanged: {
      if (!companionAgent) return
      if (panelOpen) {
        panelGraceTimer.stop()
        agentPanelGrace = true
      } else if (agentPanelGrace) panelGraceTimer.restart()
    }
    Timer { id: panelGraceTimer; interval: Timing.agentIsland.returningMs; onTriggered: slot.agentPanelGrace = false }
    readonly property bool agentRequested: root.agentHoverHeld || panelOpen || agentPanelGrace || root.agentLaunchPulse || root.agentActivitySequenceActive
    property real agentProgress: agentRequested ? 1 : 0
    Behavior on agentProgress { NumberAnimation { duration: slot.agentRequested ? Timing.agentIsland.enteringMs : Timing.agentIsland.leavingMs; easing.type: Easing.InOutCubic } }
    clip: companionAgent
    opacity: companionAgent ? agentProgress : 1
    readonly property real islandRevealProgress: companionAgent ? agentProgress : activeItem
      ? ("islandRevealProgress" in activeItem ? activeItem.islandRevealProgress : (activeItem.visible ? 1 : 0)) : 0
    readonly property bool hovered: moduleHover.hovered
    readonly property bool dragSource: root.barDragSource === slot
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    // Modules bigger than the mark they want (a text label in a padded slot,
    // a multi-line stack on a vertical bar) can say how long the open-panel
    // dot should be along the bar, so it tracks what the module paints
    // instead of a fraction of whatever slot it happens to fill.
    readonly property real panelIndicatorExtent: {
      var key = root.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
      var hint = activeItem && key in activeItem ? activeItem[key] : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round((root.vertical ? slot.height : slot.contentWidth) * 0.55))
    }
    readonly property real panelIndicatorCenterX: {
      var hint = activeItem && "openPanelIndicatorCenterX" in activeItem
        ? activeItem.openPanelIndicatorCenterX : undefined
      return hint !== undefined && hint !== null && isFinite(Number(hint))
        ? Number(hint) : slot.contentWidth / 2
    }
    // Separator space belongs to the slot, not the button's painted area.
    readonly property real contentInset: showSeparator && region === "left" && !root.vertical ? Style.space(8) : 0
    readonly property real contentWidth: Math.max(0, slot.width - contentInset)
    implicitWidth: activeItem && activeItem.visible
      ? (root.vertical ? root.barSize : (activeItem.implicitWidth + (showSeparator ? Style.space(8) : 0)) * (companionAgent ? agentProgress : 1))
      : 0
    implicitHeight: activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight
    z: modulePointer.dragging ? 100 : 0

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: {
      if (root.barDragSource === slot) root.clearBarDrag()
      root.unregisterModuleSlot(slot)
    }

    HoverHandler { id: moduleHover }

    Rectangle {
      visible: slot.showSeparator && slot.region === "left" && !root.vertical
      x: Math.round((Style.space(8) - width) / 2)
      y: Math.round((parent.height - height) / 2)
      width: Math.max(1, Style.space(1))
      height: Style.space(18)
      radius: width / 2
      color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.32)
    }

    BorderSurface {
      visible: slot.dragSource
      anchors.fill: parent
      anchors.margins: Style.space(1)
      color: root.transparent ? "transparent" : root.background
      borderSpec: Border.flat(root.barForeground, 1)
      radius: Math.min(Style.cornerRadius, height / 2)
      opacity: root.transparent ? 0.22 : 0.32
    }

    Loader {
      id: componentLoader
      active: !slot.qmlCustom && !slot.registered
      sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
      anchors.fill: parent
      anchors.leftMargin: slot.showSeparator && slot.region === "left" ? Style.space(8) : 0
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: registryLoader
      active: slot.registered
      sourceComponent: slot.registered ? slot.registryComponent : null
      anchors.fill: parent
      anchors.leftMargin: slot.showSeparator && slot.region === "left" ? Style.space(8) : 0
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Loader {
      id: qmlLoader
      active: slot.qmlCustom
      source: slot.qmlCustom ? root.customModuleSource(slot.entry) : ""
      anchors.fill: parent
      anchors.leftMargin: slot.showSeparator && slot.region === "left" ? Style.space(8) : 0
      opacity: slot.dragSource ? 0.22 : 1.0
      onLoaded: {
        slot.injectProps()
        Qt.callLater(slot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen && !slot.dragSource ? 0.9 : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
      width: root.vertical ? Style.space(2) : slot.panelIndicatorExtent
      height: root.vertical ? slot.panelIndicatorExtent : Style.space(2)
      // The mark sits on the module's inner edge — the one facing the
      // desktop — so it underlines a top bar, overlines a bottom one, and
      // points inward from a left or right one. It reads as pointing at the
      // panel that opens on that side.
      x: root.vertical
        ? (root.position === "left" ? parent.width - width - inset : inset)
        : Math.round(slot.contentInset + slot.panelIndicatorCenterX - width / 2)
      y: root.vertical
        ? Math.round((parent.height - height) / 2)
        : (root.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: slot.panelOpen ? Timing.panelSelection.enteringMs : Timing.panelSelection.leavingMs; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      id: modulePointer

      property bool dragging: false
      property bool suppressClick: false
      property real pressedX: 0
      property real pressedY: 0
      readonly property bool canReorder: false
      readonly property real dragThreshold: Style.space(4)

      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      cursorShape: root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
      readonly property string doubleClickAction: BarActions.actionFor(slot.moduleName)
      property int pendingButton: Qt.LeftButton
      property real pendingX: 0
      property real pendingY: 0

      Timer {
        id: singleClickTimer
        interval: Math.max(1, Qt.styleHints.mouseDoubleClickInterval)
        onTriggered: root.pressModuleClickTarget(slot, modulePointer.pendingButton,
          modulePointer.pendingX, modulePointer.pendingY)
      }

      // Do not assign drag.target here: ModuleSlot is owned by Row/Column
      // positioners, and mutating slot.x/slot.y can leave stale offsets that
      // make neighboring modules overlap after a small aborted drag.

      onPressed: function(mouse) {
        dragging = false
        suppressClick = false
        pressedX = mouse.x
        pressedY = mouse.y
        root.clearBarDrag()
      }

      onPositionChanged: function(mouse) {
        if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance >= dragThreshold) {
          if (!dragging) {
            root.barDragWindow = root.targetWindow(slot.activeItem) || root.targetWindow(slot)
            root.barDragScreen = root.barDragWindow ? root.barDragWindow.screen : null
            root.barDragOffsetX = pressedX
            root.barDragOffsetY = pressedY
            root.captureBarDragGhost(slot)
            root.barDragSource = slot
          }
          dragging = true
          root.hideTooltip(slot.activeItem)
        }

        if (dragging) {
          var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
          var screenPoint = root.barDragScreenPoint(scenePoint)
          root.barDragSceneX = scenePoint.x
          root.barDragSceneY = scenePoint.y
          root.barDragScreenX = screenPoint.x
          root.barDragScreenY = screenPoint.y

          var drop = root.moduleDropAtScene(scenePoint, slot)
          root.barDragTarget = drop ? drop.slot : null
          root.barDragAfter = drop ? drop.after : false
          root.barDragTargetGeometry = drop ? root.dropMarkerRect(drop.slot, drop.after) : null
        }
      }

      onReleased: function(mouse) {
        var wasDragging = dragging
        var targetSlot = root.barDragTarget
        var afterTarget = root.barDragAfter

        if (wasDragging) suppressClick = true

        dragging = false
        root.clearBarDrag()

        if (wasDragging && targetSlot) {
          root.dropBarModuleAtTarget(slot, targetSlot, afterTarget)
          mouse.accepted = true
        } else if (!wasDragging) {
          mouse.accepted = false
        }
      }

      onCanceled: {
        dragging = false
        suppressClick = false
        root.clearBarDrag()
      }

      onDoubleClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
          suppressClick = true
          singleClickTimer.stop()
          root.performModuleDoubleClick(slot.moduleName)
          mouse.accepted = true
        }
      }

      onClicked: function(mouse) {
        if (suppressClick) {
          suppressClick = false
          mouse.accepted = true
          return
        }

        if (doubleClickAction) {
          // Wait for the system's double-click interval so a single-click
          // panel cannot grab the pointer before the secondary action.
          pendingButton = mouse.button
          pendingX = mouse.x
          pendingY = mouse.y
          singleClickTimer.restart()
          mouse.accepted = true
        } else if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) {
          mouse.accepted = false
        }
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      var target = activeItem
      if (!target) return
      if ("bar" in target) target.bar = firstParty
        ? root : root.pluginBarApiFor(pluginApiId, moduleName, registered)
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
      if (slot.moduleName === "jeebis.apps" && "detachedEntry" in target)
        target.detachedEntry = Qt.binding(function() {
          var widgets = root.moduleWidgets("jeebis.workspaces")
          return widgets.length > 0 && widgets[0].islandRevealProgress < 0.001
        })
      // Bridge the shared load state without exposing another plugin's objects.
      if (slot.moduleName === "jeebis.workspaces" && "systemBusy" in target)
        target.systemBusy = Qt.binding(function() { return root.loadIslandVisible })
    }

    Component {
      id: customCommandModuleComponent
      CustomCommandModule { entry: slot.entry }
    }
  }

  component CustomCommandModule: WidgetButton {
    id: customRoot

    required property var entry
    readonly property string moduleName: root.entryId(entry)
    readonly property var settings: root.entrySettings(entry)
    property string outputText: ""
    property string outputTooltip: ""
    property bool outputActive: false

    function setting(name, fallback) {
      var value = settings ? settings[name] : undefined
      return value === undefined || value === null ? fallback : value
    }

    function update(raw) {
      var data = Util.parseModuleJson(raw)
      var klass = data.class || data.alt || ""

      outputText = data.text || String(raw || "").trim()
      outputTooltip = data.tooltip || String(setting("tooltip", ""))
      outputActive = klass === "active" || (Array.isArray(klass) && klass.indexOf("active") !== -1)
    }

    bar: root
    text: outputText || String(setting("text", ""))
    tooltipText: outputTooltip || String(setting("tooltip", ""))
    active: outputActive
    keepSpace: setting("keepSpace", false) === true
    horizontalMargin: Number(setting("horizontalMargin", 7.5))
    verticalPadding: Number(setting("verticalPadding", 6))
    fontSize: Number(setting("fontSize", 12))

    onPressed: function(button) {
      var command = ""
      if (button === Qt.RightButton)
        command = String(setting("onRightClick", ""))
      else if (button === Qt.MiddleButton)
        command = String(setting("onMiddleClick", ""))
      else
        command = String(setting("onClick", ""))

      if (command) root.run(command)
    }

    Process {
      id: customProc
      command: ["bash", "-lc", String(customRoot.setting("exec", ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: customRoot.update(text)
      }
    }

    Timer {
      interval: Math.max(1, Number(customRoot.setting("interval", 5))) * 1000
      running: String(customRoot.setting("exec", "")) !== ""
      repeat: true
      triggeredOnStart: true
      onTriggered: root.runProcess(customProc)
    }
  }
}
