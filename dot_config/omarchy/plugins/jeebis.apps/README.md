# Application island

Clicking an app icon focuses its most recently used window in the current
workspace. Focus order is tracked from Hyprland activewindowv2 events, with
focusHistoryID as the initial fallback. Closed windows are resolved afresh at
click time. Activation uses the native Wayland toplevel API, with a Hyprland
Lua/legacy dispatcher fallback for clients without a Wayland toplevel.

ChatGPT windows are excluded from application icons because the separate Agent
capsule represents ChatGPT. Window tracking remains intact for automatic reveals.

CLI Codex (org.omarchy.codex) is excluded alongside ChatGPT. Both are recognized
by the shared ../jeebis.bar/AgentModel.js module.

## Direct hover and new-app arrivals

The host keeps an invisible hover target covering this workspace's full icon-row
width, even when the capsule is hidden. It excludes Agent apps as before.

The application snapshot is tracked separately for every workspace. The first
window of an app appearing on the focused workspace gets an arrival even if the
app is already running elsewhere (including a window moved into this workspace).
Switching to a workspace with existing apps, additional windows of an app already
on that workspace, and initial shell startup use the normal reveal. New applications opened on the focused workspace each
first reveal the plain main capsule for 400 ms (`showBaseFirst`), then introduce
a separate capsule to the right over 240 ms (`entryAnimation`). It remains
fully displayed for 320 ms (`dwell` timer). During the next
320 ms (`mergeAnimation`) their icon slides into a reserved position in the main
capsule while the separate background fades into it. The main icon is hidden
until handoff completes, preventing duplicate icons. Independent ListModel
entries preserve each app's timer during simultaneous launches. Closing an app
or switching workspace cancels pending arrivals for that workspace. After merging, the main capsule automatically stays visible for 400 ms; pointer
hover still holds it open. Other automatic reveals keep their usual two seconds.
Arrival content spacing uses Style.space(16), matching the other islands. The
original click-to-focus behavior also works on incoming icons.

Tuning is centralized in `../jeebis.bar/AnimationTiming.js` (milliseconds):
- `appIsland.releasingMs`: hover exit grace.
- `appIsland.enteringMs` / `leavingMs`: main capsule reveal/hide.
- `appArrival.preparingMs`: plain base capsule before the separate icon enters.
- `appArrival.enteringMs`: separate capsule entrance.
- `appArrival.presentMs`: fully displayed separate capsule dwell.
- `appArrival.joiningMs`: icon merge and synchronized width adjustment.
- `appArrival.settledMs`: main capsule hold after merge.
- `appDeparture.reorderingMs`: icon reorder inside the main row before splitting.
- `appDeparture.preparingMs`: retained closed icon before splitting.
- `appDeparture.separatingMs`: icon split and synchronized width adjustment.
- `appDeparture.leavingMs`: separate capsule fade-out.
- `appDeparture.settledMs`: remaining capsule hold after departure.

Save the timing file, run `omarchy restart shell`, then `chezmoi add` that file.

The widget exports `mainIslandWidth` separately from the total arrival width so
the host draws only the committed capsule; arrivals paint their own backgrounds.

## Closed-app departures

A `closewindow` event for the current workspace queues a departure only when
that app's final window on the workspace has closed. Window moves and workspace
switches do not count as closes. Agent apps remain excluded. Cached metadata
keeps the closed icon in the main row for 400 ms (`showBeforeSplit.interval`),
letting a hidden island first reveal. The icon then detaches right over 320 ms
(`splitAnimation.duration`) into its own capsule, fading/shrinking away over
240 ms (`fadeOut.duration`). Until detachment, the closed icon is noninteractive.
Remaining apps stay visible through the animation and for one second afterward.
An app closed before its arrival has merged fades out from its incoming capsule
instead. Reopening the app or changing workspace cancels its pending departure.
Stable ListModel entries give simultaneous departures independent timelines.

Startup sequence: base capsule 400 ms (including its 240 ms reveal), separate
capsule entrance 240 ms, dwell 320 ms, merge 320 ms, main capsule hold 400 ms,
then hide 240 ms. Total 1920 ms without hover. If there are no previous app icons, skip the plain-base phase. The standalone
capsule enters and dwells normally, then moves intact into the usual app-island
position. No empty receiver is drawn; at the end of movement, the same visual
becomes the main capsule without a second reveal/fade animation.

## First application on an empty workspace

An empty application list no longer creates a placeholder capsule. Arrivals use
phase 2 to relocate their entire standalone capsule (including its background)
into the main capsule's normal position. Only nonempty receivers use phase 1
and the merging background fade. The final handoff disables the main reveal and
width animations for that update so the visible capsule stays continuous.
Concurrent arrivals wait for this first relocation before joining the receiver.
Movement uses appArrival.joiningMs; entry, dwell and settled times are unchanged.

## Departure ordering

Closed apps are retained at the right edge before splitting. Live icons keep
their relative order. A stable icon ListModel and Row move transition animate
reordering when another app closes while the island is visible. Pending closes
are ordered oldest at the far right and split sequentially; each split waits
for its preparation timer and the latest row movement/resize to finish.
`appDeparture.reorderingMs` controls the reorder duration. The existing
preparation, split, fade and settled timings remain unchanged.

## Icon coordinates during handoff

The committed icon row is anchored to the viewport's left edge. Its clipping
width animates independently, so inserting/removing an icon does not translate
the remaining row. Departure captures the rendered delegate position with
`mapToItem(root, 0, 0)` before removing it. Arrival targets use the same stable
left-origin slot coordinates, avoiding a jump between the standalone and
committed icon. The main viewport's existing directional entrance/exit remains.

## Applications inside WezTerm

`~/.config/wezterm/tabs.lua` publishes a readable `Neovim · WezTerm — …`
window title from the active pane's foreground process. Supported applications
are Neovim, Yazi and Codex. Only WezTerm classes accept this prefix; arbitrary
filenames or terminal titles never decide the application identity. Unknown
applications/shells keep their WezTerm icon. Different applications in separate
windows get distinct identities; clicks focus the matching window.

Neovim and Yazi reuse installed `nvim`/`yazi` icons. Codex remains in the Agent
island, following the existing no-duplicate policy. Omarchy already supplies
`/usr/share/omarchy/shell/plugins/agents/assets/codex.svg`. Returning to a shell
is treated as an Agent exit even when the WezTerm window remains open.

Herdr is always classified as Codex because it is used as an Agent workspace.
When the active WezTerm pane's foreground process is `herdr`, its window gets
the same Codex identity and Agent-island behavior as a direct `codex` process.
No Herdr pane inspection, API calls, external polling or cache is involved.
This applies to local, named-session and remote Herdr clients alike.

Additional candidates: lazygit (Git), btop/htop (load graph), Claude Code and
OpenCode (dedicated Agent identities would also need to be added).

References:
- https://wezterm.org/config/lua/PaneInformation.html
- https://wezterm.org/config/lua/window-events/format-window-title.html

## Web application icons

Normal applications use `desktopEntryForClient()` in `AppGroup.qml` to resolve
an installed `.desktop` entry and its `Icon=` value, then `iconSource()` resolves
the icon name or file URL. Desktop launchers live in
`~/.local/share/applications/`; user icons live in
`~/.local/share/icons/hicolor/256x256/apps/`.

`webAppEntries` maps Chromium URL-derived classes to the Omarchy launchers
Calendar, Document, Presentation, Sheets and Teams. This matches the dedicated web-app
window's class, not its changeable page title. A regular browser tab continues
to use the browser icon. Teams accepts both teams.microsoft.com and
teams.cloud.microsoft. The mapped apps use explicit user icon paths to avoid
ambiguity with theme icon names.

Google Docs/Slides/Sheets icons are from Google's static asset host:
- https://ssl.gstatic.com/docs/doclist/images/mediatype/icon_1_document_x128.png
- https://ssl.gstatic.com/docs/doclist/images/mediatype/icon_1_presentation_x128.png
- https://ssl.gstatic.com/docs/doclist/images/mediatype/icon_1_spreadsheet_x128.png
The existing Google Calendar and Teams icons are reused. Icon assets are also saved in chezmoi's
`dot_local/share/icons/hicolor/256x256/apps/` directory. Changes to QML can be
reloaded with `omarchy restart shell`.

## Automatic icons for newly installed web apps

Install normally through Omarchy, or run:

```sh
omarchy webapp install "App name" "https://example.com"
```

Omarchy's installer already downloads the site's touch icon/favicon when no icon
is specified, writes `Icon=` into the `.desktop` launcher, and updates the user
icon cache. The result may be a generic site favicon; a custom icon URL/name can
still be supplied when needed. Download failure is reported by the installer.

The App island now discovers installed launchers automatically through
`DesktopEntries.applications`, reads their parsed `command` and `icon`, and
matches the Chromium URL-derived class to the launch URL. It supports
`omarchy-launch-webapp URL` and direct browser `--app=URL` launchers. Newly
registered entries update through DesktopEntries without adding QML mappings.
The five existing curated mappings remain as icon/path and host-alias overrides.
Normal browser tabs keep their browser icon. Two launchers with identical URL
host/path but different query parameters share a Chromium class and cannot be
reliably distinguished by this mechanism. Browser-managed hashed PWA IDs rely
on their browser-created desktop registrations instead of the URL matcher.

Only registration metadata is inspected; no launcher commands are executed.
This automatic lookup does not add future applications/icons to chezmoi: add
new launchers and downloaded icon files explicitly when they should be synced.

Chromium app-name reference:
https://chromium.googlesource.com/chromium/src/+/refs/heads/main/chrome/browser/web_applications/web_app_helpers.cc

## Floating and tiled application groups

`BarWidget.qml` hosts two persistent `AppGroup.qml` instances. Each instance
tracks only its own floating/tiled windows in the focused workspace, with
independent icon order, arrivals/departures and hover timers. Agent apps remain
excluded. Clicking an icon focuses the most recent window in the same group.
The same application can have an icon in both groups.

The focused Hyprland toplevel's `lastIpcObject.floating` selects the visible
group. Changing focus between floating/tiled windows swaps the visible list
immediately and presents that surface from above. Each surface
owns its themed capsule background. Empty groups create no placeholder capsule.

Partial per-icon arrival/departure effects in the selected list are settled at
the instant of selection. Ordinary per-icon launch/close effects and hover-based
show/hide behavior remain. Group changes alone are not new launches. Super+D
parking preserves floating/tiled membership through the special desktop workspace.

No layer-switch animation timings are defined. The selected group uses the
normal `appIsland.presentMs` auto-hide delay. Reload with `omarchy restart shell`.
Icon collection/discovery live in `AppGroup.qml`; `BarWidget.qml` owns selection.

## Composition centering and hold timing

The main App capsule is centered before a launch/close composition starts.
`compositionBaseWidth` freezes its centering reference while an incoming icon
appears/merges or a closed icon splits/fades. Standalone extents reserve layout
space but do not pull the original capsule away from center. After all pending
compositions finish, `centeringWidth` animates to the new main-capsule width over
`Timing.centerCompanions.movingMs`. Only after that movement completes does the
usual `appArrival.settledMs` or `appDeparture.settledMs` display hold begin.
The App island then exits upward when the workspace capsule is absent. Pointer
hover still holds it open. A new composition cancels an older settling timer;
workspace/group changes clear stale composition state. The first app still has
no empty receiver; its actual standalone capsule supplies its centering span.

Floating/tiled selection swaps the list immediately and presents that surface
from above using `appIsland.enteringMs`, including when Agent is visible. Its
normal display hold restarts after the drop finishes. The host's balance does
not add a second easing interval while App's own centering span is animated.

## Existing-window layer changes and empty central hover

Arrival detection checks the cached window address, workspace and application
identity. Moving an existing window between floating/tiled groups clears its
pending arrival and never creates a new composition, including repeated model
updates after the move. Real new windows and first appearances on another
workspace retain their arrival behavior.

The host's central hover uses the selected group's live `hasApplications`, not
its fading capsule geometry. If the last companion was App but its current list
is empty, central hover opens Agent instead. This also applies if that list
becomes empty while the central hover remains held.
