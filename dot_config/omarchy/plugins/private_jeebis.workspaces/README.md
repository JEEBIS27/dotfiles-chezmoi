# Workspace island

Only actual positive-ID Hyprland workspaces are shown. One workspace hides the island; two or more reveal it, so the minimum visible dot count is two. Scratchpads do not count.

The last dots are retained through the 240 ms exit animation. Width changes between visible workspace counts animate for 220 ms. The host bar reads `islandRevealProgress` to animate the capsule background and padding on the same timeline.

CPU and launch spinners still belong to the workspace performing the work. Clicking a dot continues to reveal the app island, including a repeated selection of the current workspace.

## Reload initialization

The workspace island starts with zero reveal progress and an empty displayed
model. After component initialization, both workspace-list and visibility-request
changes schedule one deferred synchronization. The actual IDs are assigned to
the Repeater before the reveal starts. An empty displayed list has no size and
is never visible, preventing an empty thin pill when QML bindings settle in a
different order during reload. Outgoing dots remain until the exit finishes.
Normal two-or-more-workspace visibility and the high-load spinner exception
remain unchanged.

## Screen-edge entrance and exit

At the top edge the workspace capsule and its dots slide together down from
above the screen, then slide back up when hiding. The capsule retains its full
shape rather than shrinking horizontally. Its layout slot is removed only after
the exit finishes. Dot-count width resizing runs only while fully shown; the
startup model is populated while hidden, preventing a thin empty capsule.
The bar transforms only the workspace visuals, so Agent/application islands keep
their independent horizontal animations. Entry/exit durations remain defined by
AnimationTiming.js workspaceIsland.enteringMs/leavingMs.
