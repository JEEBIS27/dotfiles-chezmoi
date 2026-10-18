# Omarchy bar

This is the Quickshell implementation of the Omarchy status bar. It is
shipped as a first-party plugin of [`omarchy-shell`](../../README.md), the
long-running shell host. The bar is mounted at startup and lives inside
the shell for its whole session.

- `manifest.json` declares the plugin (`id: omarchy.bar`, `kind: bar`) and points at `Bar.qml` as the entry point.
- `Bar.qml` is Omarchy-owned bar engine code, loaded by the omarchy-shell host. Users should not edit it directly.
- `widgets/` holds simple first-party bar widgets with sibling manifests.
- Feature plugins such as `../panels/audio/`, `../panels/network/`, `../panels/power/`, and `../agents/` provide richer popup bar plugins.
- The bar receives its config from the host shell as a `barConfig` property; the host loads it from `~/.config/omarchy/shell.json` (or `config/omarchy/shell.json` when the user has no file).
- `omarchy bar position` updates only the user shell.json file.

## Customizing

The bar config lives under the `bar:` key of [`~/.config/omarchy/shell.json`](../../README.md#shelljson-shape). Out of the box the shell uses [`config/omarchy/shell.json`](../../../config/omarchy/shell.json). Once you customize anything via the bar gestures, `omarchy bar ...`, or by editing shell.json directly, your file is canonical — there is no deep-merge.

The bar is configured directly on the bar itself: drag empty bar space (or click-and-hold) to move the bar to another screen edge, double-left-click empty center-bar space to toggle transparency, and drag widgets to reorder them. The `omarchy bar position`, `omarchy bar transparent`, `omarchy bar move`, and `omarchy bar set` commands do the same from scripts. Enable or disable widgets with `omarchy plugin enable` and `omarchy plugin disable` (widget ids come from `omarchy plugin list`).

Example `shell.json` (bar subtree only shown):

```json
{
  "version": 1,
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [
        { "id": "omarchy.menu" },
        { "id": "omarchy.spacer", "size": 12 },
        { "id": "omarchy.workspaces" }
      ],
      "center": [
        { "id": "omarchy.media" },
        { "id": "omarchy.clock", "format": "HH:mm" }
      ],
      "right": [
        { "id": "omarchy.audio" },
        { "id": "omarchy.power" }
      ]
    }
  }
}
```

`centerAnchor` pins one center module to the exact horizontal/vertical center and flanks others around it. Set to an empty string to disable anchoring (the center list is centered as a group).

## Module catalogue

### First-party interactive widgets

| Name | What it does | Interactions |
|---|---|---|
| `omarchy.menu` | Omarchy menu launcher | left = menu · right = terminal |
| `omarchy.workspaces` | Hyprland workspace switcher | left = focus workspace |
| `omarchy.clock` | Date/time label + popup with a month grid, ISO week numbers, and month stepping | left = popup · right = cycle label format · middle = timezone selector |
| `omarchy.media` | MPRIS now-playing — scrolling track + artist, cover-art popup | left = play/pause · middle = next · scroll = prev/next · right = popup |
| `omarchy.indicators` | Manual state indicators | left = indicator action |
| `omarchy.system-update` | Available update indicator | left = update |
| `omarchy.tray` | System tray | hover = reveal drawer · right on chevron = manage |
| `omarchy.weather` | Weather icon + popup with forecast | left = popup · right = full notification |
| `omarchy.microphone` | Mic icon + scroll volume | left = mute toggle · middle = audio panel · scroll = source volume |

| `omarchy.audio` | Volume icon + popup with master slider, output-device picker, per-app mixer | left = popup · right = mute · middle = popup · scroll = volume |
| `omarchy.network` | Wi-Fi/Ethernet icon + popup with Wi-Fi scan, signal, connect, DNS provider selection | left = popup |
| `omarchy.tailscale` | Tailscale status, connection switcher, machine browser, and copy actions | left = popup · right = toggle · middle = refresh |
| `omarchy.agents` | AI coding agent limits with pace, today, last week, and all-time model breakdown | left = panel · right = launch agent · middle = next subscription |
| `omarchy.power` | Battery/AC icon + popup with battery stats, power profiles, and system info | left = popup · right = toggle percentage |
| `omarchy.bluetooth` | Bluetooth icon + popup with device list, connect/disconnect, battery | left = popup · right = toggle radio |
| `omarchy.monitor` | Brightness and laptop display controls | left = popup |

The `omarchy.indicators` widget loads individual bar indicators from `indicators/`. Omit `items` (or set it to an empty array) to show all indicators in the default order, or set `items` to a subset such as `["Dnd", "Reminder", "NightLight"]`. Set `alwaysShow` to `true` to keep inactive indicators visible instead of revealing them only on hover. Multiple `omarchy.indicators` instances are allowed, so different sections can show different subsets.

## Orientation

All widgets work in `top`, `bottom`, `left`, and `right` positions. Popups anchor on the side opposite the bar edge, sliding into the workspace. Vertical bars use 28px width; widgets that show text fall back to compact icon-only forms (e.g. `media` hides its scrolling label).

## Custom user modules

The schema accepts arbitrary module ids that you provide. Set `type` to `command` for shell-driven output or `qml` for a custom QML widget. Both still go under `bar.layout.<section>` in `shell.json`.

Command module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "omarchy.tray" },
        { "id": "vpn", "type": "command", "exec": "~/.config/omarchy/bar/scripts/vpn-status", "interval": 5, "tooltip": "VPN", "onClick": "nm-connection-editor" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

The command may print plain text or Waybar-style JSON, for example:

```json
{"text":"󰌆","tooltip":"Work VPN","class":"active"}
```

QML module:

```json
{
  "version": 1,
  "bar": {
    "layout": {
      "right": [
        { "id": "gpu", "type": "qml" },
        { "id": "omarchy.audio" }
      ]
    }
  }
}
```

Then create `~/.config/omarchy/bar/modules/gpu.qml`. If you want to store it elsewhere, add a `source` path.

Custom QML modules should be an `Item` with `implicitWidth` and `implicitHeight`. They may optionally define these properties, which the bar fills after loading:

```qml
import QtQuick

Item {
  property var bar
  property string moduleName
  property var settings

  implicitWidth: 28
  implicitHeight: bar ? bar.barSize : 26

  Text {
    anchors.centerIn: parent
    text: "GPU"
    color: bar ? bar.foreground : "white"
    font.family: bar ? bar.fontFamily : "monospace"
    font.pixelSize: 12
  }

  MouseArea {
    anchors.fill: parent
    onClicked: if (bar) bar.run("omarchy-launch-or-focus-tui btop")
  }
}
```

## Bar properties available to widgets

Widgets receive `bar` (the shell root), `moduleName` (string), and `settings` (object) injected at load time. The bar exposes:

- `bar.foreground`, `bar.background`, `bar.urgent` — theme colors (live-updated)
- `bar.fontFamily` — current monospace family
- `bar.position` — `"top" | "bottom" | "left" | "right"`
- `bar.vertical` — boolean shortcut
- `bar.barSize` — 26 horizontal / 28 vertical
- `bar.run(command)` — fire-and-forget bash exec
- `bar.shellQuote(value)` — safe shell-quote a string
- `bar.showTooltip(target, text)` / `bar.hideTooltip(target)` — shared tooltip popup
- `bar.requestPopout(owner)` / `bar.releasePopout(owner)` — one-popup-at-a-time coordinator

First-party bar widgets are manifest-backed just like third-party widgets.
Simple widgets carry sibling manifests such as `widgets/Workspaces.manifest.json`;
richer popup plugins live in feature directories such as `../panels/audio/`,
`../panels/network/`, and `../agents/`; and feature plugins such as
`omarchy.menu` and `omarchy.media` declare their bar-widget entry points in their own
`manifest.json`. Bar layout ids are namespaced, e.g. `omarchy.audio`,
`omarchy.network`, and `omarchy.clock`. Older UpperCamelCase ids such as
`AudioPanel` and `Clock` are migrated forward; new configs should use the
namespaced ids.

Third-party widgets ship as separate plugins under
`~/.config/omarchy/plugins/<plugin-id>/` with their own `manifest.json`
declaring `kinds: ["bar-widget"]` and a `barWidget` entry point. See
[../../README.md](../../README.md) for the manifest schema. Rescan, enable,
and place third-party plugins with `omarchy-shell shell rescanPlugins`,
`omarchy plugin enable`, and `omarchy bar move`.


## Custom bar interactions

Bar edge dragging and widget reordering are disabled.

| Control | Click | Double-click |
| --- | --- | --- |
| Theme (leftmost) | Omarchy theme picker | Aether |
| Agent | Agent usage panel | ChatGPT |
| Workspace island | Focus workspace | Workspace overview with live previews |
| Clock island | Calendar popup | Google Calendar web app |

Secondary actions run through `~/.local/bin/jeebis-bar-action`. For these four
controls a normal click waits for the system double-click interval, preventing
the normal popup from intercepting the second click. Unassigned controls keep
their original click behavior. Blank bar space has no global double-click action.

Aether requires the official binary at `~/.local/bin/aether` and the Arch
`webkit2gtk-4.1` package. Overview uses the adapted `jeebis.overview` plugin.

## Transient companion islands

The app capsule remains visible while the workspace capsule or app capsule is
hovered. Leaving both starts a 100 ms grace period, followed by the existing
closing animation. Returning during the grace period cancels it. Automatic
workspace/window reveals still last two seconds without pointer interaction.

Agent occupies a separate capsule left of the workspace capsule. It is held by
its own hover, or workspace hover when ChatGPT or CLI Codex is on the current workspace.
Hover exit uses the same 100 ms grace period. Automatic Agent reveals occur for
a new ChatGPT or CLI Codex window, or workspace selection (including same-workspace commands)
when the selected workspace contains ChatGPT or CLI Codex. Generic app opening/closing no
longer triggers Agent. The native usage panel holds the capsule open; a 100 ms
close grace bridges the handoff from the popup's pointer surface back to the bar,
preventing the icon from disappearing and immediately returning.

Notification hover expands only the clear button. Opening the notification panel
also expands its history button; both changes animate independently.

### Animation timing

All user-defined animation durations and presentation/hover delays are grouped
in `jeebis.bar/AnimationTiming.js`. Each frozen group represents one animation;
its abstract phase names have Japanese comments describing the concrete motion.
All values are milliseconds. Change these constants instead of QML timer bodies.

For example, app hover exit is `appIsland.releasingMs`, Agent hover exit is
`agentIsland.releasingMs`, and popup-close handoff is `agentIsland.returningMs`.
The user's existing values are preserved, including the 150 ms app hover exit.
Agent sequencing adds `changingMs + presentMs` and `collapsingMs + settledMs`,
so the related phases follow automatically when a component duration changes.

After editing the shared file, reload all consumers and save it to Dotfiles:

```bash
omarchy restart shell
chezmoi add ~/.config/omarchy/plugins/jeebis.bar/AnimationTiming.js
```

The file covers custom bar/plugin animations, including calendar/power panel
content and the bar's fallback widgets. Data polling, compositor synchronization,
system double-click timing, and installed Omarchy UI internals keep their own
contracts; they are not presentation timing constants.

The notification widget supplies `openPanelIndicatorCenterX` and
`openPanelIndicatorWidth` so unread/history selection points to its own button.

### Agent launch buttons

ChatGPT (`chatgpt`) and CLI Codex (`org.omarchy.codex`) share Agent behavior.
`AgentModel.js` centralizes exact application-ID matching for the bar, launchers,
and app-island exclusion; normal terminal windows are unaffected.
`jeebis.agent-launchers` expands ChatGPT/Codex text buttons to the left of the
Agent icon while its island is hovered. Moving across the expanded island holds
it open. Each button focuses an existing window across workspaces or launches
the app if absent. Kanagawa white means running and gray means not running.
Button expansion animates and its exit delay is 100 ms.
Codex starts with `omarchy-launch-tui --app-id=org.omarchy.codex codex`, matching
the user's existing TUI keybinding without altering Codex permissions.

The application section now reads mainIslandWidth and hoverTargetWidth hints.
This preserves a hover target while hidden and keeps new-app arrival backgrounds
separate from the main capsule until their merge completes.

## Show-desktop restoration and Agent exits

The apps widget keeps original workspace membership for windows parked in
`special:desktop` by Super+D, and suppresses new-arrival detection on restoration.
It also recognizes restoration when the shell first loaded while windows were
parked. A genuine first app window on another workspace still gets an arrival.
No Hyprland keybindings are modified.

Agent exit playback is triggered only by actual `closewindow` events and only
when no window of that app kind remains running. The host caches app kinds by
window address and waits for the compositor model to confirm the close.
The launcher expands for 400 ms, then changes the closed label to the theme's
muted color over the normal color transition. After another 1320 ms (320 ms color transition plus 1000 ms hold) it retracts
its buttons (320 ms), holds only the Agent icon for 400 ms, and releases the
capsule to its existing 240 ms hide animation. Hover or an open usage panel
still holds the island as usual. Repeated closes restart the sequence and retain
the set of closing app kinds. Desktop hiding/restoration never triggers exit
playback because it emits workspace moves rather than actual close events.

## Agent startup/exit shared timeline

First startup of ChatGPT or CLI Codex now plays the same lifecycle sequence as
exit. Startups begin with a muted label, exits with a lit label, and switch to
the real running state after 400 ms. Additional windows of a still-running Agent
app and focus-only actions use the normal reveal without a false color change.
No startup sequence is emitted for show-desktop restoration.

Timeline from lifecycle trigger (milliseconds):
- 0–400: expanded buttons; the 180 ms button reveal and 240 ms capsule reveal overlap this phase.
- 400–720: label color transition (320 ms).
- 720–1720: hold the updated color (1000 ms).
- 1720–2040: retract buttons (320 ms).
- 2040–2440: Agent icon alone (400 ms).
- 2440–2680: hide the Agent capsule (240 ms), unless hovered or its panel is open.

The playback is in jeebis.agent-launchers/BarWidget.qml, activityPlayback; edit
its phase durations in AnimationTiming.js under agentActivity. Compound waits
are computed from changingMs + presentMs and collapsingMs + settledMs.
Button expansion remains 180 ms; contraction is 320 ms. Total lifecycle: 2680 ms.
Automatic workspace reveals do not extend an active lifecycle sequence.

## Load/spinner consistency and Agent-only changes

The host injects the load island's real visibility into Workspaces.systemBusy,
including its closing animation. While any high-load item is displayed, the
workspace spinner timer runs. Existing per-workspace CPU attribution keeps
priority. If no workspace crosses its separate busy threshold, the workspace
with the largest measured CPU share gets a fallback spinner; when attribution is
unavailable, the focused workspace is used. One-workspace layouts temporarily
show that dot during high load, so the load island never lacks a spinner.

The application island's window signature excludes AgentModel matches as well
as unidentified clients, just like its application icon collection. Agent-only
window opens/closes no longer trigger a two-second application island reveal.
Real workspace selections and non-Agent window changes retain their behavior.

## Directional companion motion

The app capsule and its icon viewport enter rightward from the workspace-facing
edge, and return leftward while hiding. A clipped viewport holds the complete
row against its right edge as the reveal width grows, so the actual icons move
with the capsule rather than fading outside its bounds. Only the main app
capsule gets this horizontal offset; standalone arrival/departure icons retain
their own geometry and timelines. Agent mirrors this motion to the left, with
its content gap following the same reveal progress. Both hover targets remain
at their fully expanded resting positions to prevent hover feedback loops.
Existing AnimationTiming.js entry/exit durations are unchanged.
