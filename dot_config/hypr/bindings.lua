-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.
--
-- Keybinding convention for application launches:
--   SUPER + ALT + KEY       launches the primary app or TUI for that key.
--   SUPER + SHIFT + ALT + KEY launches its GUI or alternate app.
-- Keep ALT in application-launch bindings for consistency.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
o.bind("SUPER + SHIFT + S", "Capture Screenshot", "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Omarchy's default resize keys use physical keycodes 20/21 (the top-row
-- minus/equal keys), not the EQUAL/MINUS keysym names.
for _, modifiers in ipairs({
    "SUPER",
    "SUPER + SHIFT",
    "SUPER + ALT",
    "SUPER + SHIFT + ALT",
    "SUPER + CTRL",
    "SUPER + CTRL + SHIFT",
}) do
    hl.unbind(modifiers .. " + code:20")
    hl.unbind(modifiers .. " + code:21")
end

-- Tiled window size bounds as fractions of the monitor's usable dimensions.
-- 0.25 means one quarter; 0.75 means three quarters.
local MIN_WINDOW_RATIO = 0.25
local MAX_WINDOW_RATIO = 0.75
local RESIZE_STEP = 50

-- Scroll時、フォーカス列の左右位置に応じて通常リサイズ方向を反転する。
-- trueで有効、falseで無効。
local SCROLL_RESIZE_DIRECTION_BY_FOCUS = false

-- Monitor width/height are reported in output pixels; window geometry uses
-- logical pixels. Convert before comparing ratios (especially with scale > 1).
local function logical_monitor_size(monitor)
    local scale = monitor.scale or 1
    if scale <= 0 then
        scale = 1
    end
    return monitor.width / scale, monitor.height / scale
end

local directions = {
    {
        key = "LEFT", vim = "H", direction = "l", scroll_direction = "l",
        resize = { x = -RESIZE_STEP }, scroll_resize = { x = -RESIZE_STEP },
    },
    {
        key = "DOWN", vim = "J", direction = "d", scroll_direction = "l",
        resize = { y = RESIZE_STEP }, scroll_resize = { x = -RESIZE_STEP },
    },
    {
        key = "UP", vim = "K", direction = "u", scroll_direction = "r",
        resize = { y = -RESIZE_STEP }, scroll_resize = { x = RESIZE_STEP },
    },
    {
        key = "RIGHT", vim = "L", direction = "r", scroll_direction = "r",
        resize = { x = RESIZE_STEP }, scroll_resize = { x = RESIZE_STEP },
    },
}

local function is_scrolling()
    local workspace = hl.get_active_workspace()
    return workspace and workspace.tiled_layout == "scrolling"
end

-- Dwindle full width uses Hyprland's maximized state. Directional focus,
-- swap, and move dispatchers are rejected while that state is active. Leave
-- maximized mode first; real fullscreen (mode 2) remains untouched.
local function prepare_directional_action()
    if is_scrolling() then
        return
    end

    local active = hl.get_active_window()
    if active and active.fullscreen == 1 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "unset" }))
    end
end

local function has_vertical_split_neighbor(active, workspace)
    if not active or not workspace then
        return false
    end

    local active_left = active.at.x
    local active_right = active_left + active.size.x
    local active_top = active.at.y
    local active_bottom = active_top + active.size.y

    for _, other in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not other.floating and other.address ~= active.address then
            local other_left = other.at.x
            local other_right = other_left + other.size.x
            local other_top = other.at.y
            local other_bottom = other_top + other.size.y
            local horizontal_overlap = math.min(active_right, other_right) - math.max(active_left, other_left)
            local min_width = math.min(active.size.x, other.size.x)
            local vertical_overlap = math.min(active_bottom, other_bottom) - math.max(active_top, other_top)

            -- Treat windows as part of the same vertical split when they occupy
            -- substantially the same column and their vertical bounds do not overlap.
            if horizontal_overlap >= min_width * 0.5 and vertical_overlap <= 1 then
                return true
            end
        end
    end

    return false
end

local function adjacent_vertical_stack_target(active, workspace, vim_key)
    if not active or not workspace then
        return nil
    end

    local windows = {}
    for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not window.floating and window.address ~= active.address then
            table.insert(windows, window)
        end
    end

    local active_left = active.at.x
    local active_right = active_left + active.size.x
    local nearest_gap = math.huge
    local target = nil

    for _, seed in ipairs(windows) do
        local stack = { seed }
        for _, other in ipairs(windows) do
            if other.address ~= seed.address then
                local overlap_x = math.min(seed.at.x + seed.size.x, other.at.x + other.size.x)
                    - math.max(seed.at.x, other.at.x)
                local min_width = math.min(seed.size.x, other.size.x)
                local overlap_y = math.min(seed.at.y + seed.size.y, other.at.y + other.size.y)
                    - math.max(seed.at.y, other.at.y)
                if overlap_x >= min_width * 0.5 and overlap_y <= 1 then
                    table.insert(stack, other)
                end
            end
        end

        if #stack >= 2 then
            local stack_left = math.huge
            local stack_right = -math.huge
            local upper = seed
            local lower = seed
            for _, window in ipairs(stack) do
                stack_left = math.min(stack_left, window.at.x)
                stack_right = math.max(stack_right, window.at.x + window.size.x)
                if window.at.y < upper.at.y then upper = window end
                if window.at.y > lower.at.y then lower = window end
            end

            local gap
            if stack_right <= active_left + 1 then
                gap = active_left - stack_right
            elseif stack_left >= active_right - 1 then
                gap = stack_left - active_right
            end

            if gap and gap < nearest_gap then
                nearest_gap = gap
                target = vim_key == "K" and upper or lower
            end
        end
    end

    return target
end

local function direction_for(item)
    if item.vim == "J" or item.vim == "K" then
        local active = hl.get_active_window()
        local workspace = hl.get_active_workspace()
        if has_vertical_split_neighbor(active, workspace) then
            return item.direction
        end
    end

    return is_scrolling() and item.scroll_direction or item.direction
end

local function focus_direction(item)
    prepare_directional_action()

    if item.vim == "J" or item.vim == "K" then
        local active = hl.get_active_window()
        local workspace = hl.get_active_workspace()
        if not has_vertical_split_neighbor(active, workspace) then
            local target = adjacent_vertical_stack_target(active, workspace, item.vim)
            if target then
                hl.dispatch(hl.dsp.focus({ window = target }))
                return
            end
        end
    end

    local scrolling = is_scrolling()
    local direction = direction_for(item)
    if scrolling and direction ~= "u" and direction ~= "d" then
        hl.dispatch(hl.dsp.layout("focus " .. direction))
    else
        hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
end

local function direction_for_float(item)
    return is_scrolling() and item.scroll_direction or item.direction
end

local function tiled_windows_except(active, workspace)
    local tiled = {}
    for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not window.floating and window.address ~= active.address then
            table.insert(tiled, window)
        end
    end
    return tiled
end

local function edge_window(windows, direction)
    local horizontal = direction == "l" or direction == "r"
    local reverse = direction == "r" or direction == "d"
    local best, best_primary, best_cross

    for _, window in ipairs(windows) do
        local primary = horizontal and (window.at.x + window.size.x / 2)
            or (window.at.y + window.size.y / 2)
        local cross = horizontal and (window.at.y + window.size.y / 2)
            or (window.at.x + window.size.x / 2)
        if not best
            or (reverse and primary > best_primary)
            or (not reverse and primary < best_primary)
            or (primary == best_primary and cross < best_cross) then
            best, best_primary, best_cross = window, primary, cross
        end
    end

    return best
end

local function swap_direction(item)
    local active = hl.get_active_window()
    if active and active.floating then
        local workspace = hl.get_active_workspace()
        if not workspace then return end

        local target = edge_window(tiled_windows_except(active, workspace), direction_for_float(item))
        if not target then return end

        local float_x, float_y = active.at.x, active.at.y
        local float_width, float_height = active.size.x, active.size.y
        hl.dispatch(hl.dsp.window.float({ action = "off", window = active }))
        hl.timer(function()
            hl.dispatch(hl.dsp.focus({ window = active }))
            hl.dispatch(hl.dsp.window.swap({ target = target }))
            hl.timer(function()
                hl.dispatch(hl.dsp.window.float({ action = "on", window = target }))
                hl.dispatch(hl.dsp.window.resize({
                    window = target, x = float_width, y = float_height, relative = false,
                }))
                hl.dispatch(hl.dsp.window.move({
                    window = target, x = float_x, y = float_y, relative = false,
                }))
                hl.dispatch(hl.dsp.focus({ window = active }))
            end, { timeout = 50, type = "oneshot" })
        end, { timeout = 50, type = "oneshot" })
        return
    end

    prepare_directional_action()
    hl.dispatch(hl.dsp.window.swap({ direction = direction_for(item) }))
end

local function move_direction(item)
    local active = hl.get_active_window()
    if active and active.floating then
        hl.dispatch(hl.dsp.window.move({
            window = active,
            x = item.resize.x or 0,
            y = item.resize.y or 0,
            relative = true,
        }))
        return
    end

    prepare_directional_action()
    hl.dispatch(hl.dsp.window.move({ direction = direction_for(item) }))
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function resize(item, target_ratio)
    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    -- Floating geometry is independent of tiled columns and neighbor limits.
    if active.floating then
        local x = item.resize and item.resize.x or 0
        local y = item.resize and item.resize.y or 0
        if target_ratio then
            local logical_width = logical_monitor_size(monitor)
            x = target_ratio * logical_width - active.size.x
        end
        hl.dispatch(hl.dsp.window.resize({
            window = active,
            x = x,
            y = y,
            relative = true,
        }))
        return
    end

    local scrolling = is_scrolling()
    local vertical_scroll_resize = scrolling
        and (item.vim == "J" or item.vim == "K")
        and has_vertical_split_neighbor(active, hl.get_active_workspace())

    if scrolling and not vertical_scroll_resize then
        local logical_width = logical_monitor_size(monitor)
        if logical_width <= 0 then
            return
        end

        local current = active.size.x / logical_width
        local requested = target_ratio and (target_ratio - current)
            or (item.scroll_resize.x or 0) / logical_width

        -- Scrolling columns resize from the focused column's side. Reverse the
        -- delta when the closest neighboring column is to the left, so the
        -- same key expands/shrinks the shared boundary consistently.
        local workspace = hl.get_active_workspace()
        local nearest_x_distance = math.huge
        local nearest_is_left = false
        if workspace then
            for _, other in ipairs(hl.get_workspace_windows(workspace.id)) do
                if not other.floating and other.address ~= active.address then
                    local active_center_x = active.at.x + active.size.x / 2
                    local other_center_x = other.at.x + other.size.x / 2
                    local dx = other_center_x - active_center_x
                    if math.abs(dx) > 1 and math.abs(dx) < nearest_x_distance then
                        nearest_x_distance = math.abs(dx)
                        nearest_is_left = dx < 0
                    end
                end
            end
        end
        if target_ratio then
            local target = clamp(target_ratio, MIN_WINDOW_RATIO, MAX_WINDOW_RATIO)
            -- Scrolling's colresize accepts an absolute column-width ratio.
            -- Use it directly so window gaps don't skew the measured surface width.
            hl.dispatch(hl.dsp.layout("colresize " .. string.format("%.4f", target)))
            return
        end

        if SCROLL_RESIZE_DIRECTION_BY_FOCUS and nearest_is_left then
            requested = -requested
        end

        local next_ratio = clamp(current + requested, MIN_WINDOW_RATIO, MAX_WINDOW_RATIO)
        local amount = string.format("%+.4f", next_ratio - current)
        if amount ~= "+0.0000" and amount ~= "-0.0000" then
            hl.dispatch(hl.dsp.layout("colresize " .. amount))
        end
        return
    end

    local amount = item.resize
    local axis = target_ratio and "x" or ((amount.x or 0) ~= 0 and "x" or "y")
    local logical_width, logical_height = logical_monitor_size(monitor)
    local dimension = axis == "x" and logical_width or logical_height
    local workspace = hl.get_active_workspace()
    local tiled = {}
    if workspace then
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            if not window.floating then
                table.insert(tiled, window)
            end
        end
    end

    local delta = target_ratio and (target_ratio * dimension - active.size.x) or (amount[axis] or 0)
    if #tiled > 1 and dimension > 0 then
        local min_size = MIN_WINDOW_RATIO * dimension
        local max_size = MAX_WINDOW_RATIO * dimension
        local low_delta = min_size - active.size[axis]
        local high_delta = max_size - active.size[axis]
        local active_start = active.at[axis]
        local active_end = active_start + active.size[axis]
        local cross_axis = axis == "x" and "y" or "x"
        local active_cross_start = active.at[cross_axis]
        local active_cross_end = active_cross_start + active.size[cross_axis]

        -- Bound all touching Dwindle neighbors as well as the focused window.
        -- This keeps the opposite pane from crossing 0.75 when this pane shrinks.
        for _, other in ipairs(tiled) do
            if other.address ~= active.address then
                local other_start = other.at[axis]
                local other_end = other_start + other.size[axis]
                local other_cross_start = other.at[cross_axis]
                local other_cross_end = other_cross_start + other.size[cross_axis]
                local overlaps = math.min(active_cross_end, other_cross_end) > math.max(active_cross_start, other_cross_start)
                local adjacent = math.abs(active_end - other_start) <= 32 or math.abs(other_end - active_start) <= 32

                if overlaps and adjacent then
                    low_delta = math.max(low_delta, other.size[axis] - max_size)
                    high_delta = math.min(high_delta, other.size[axis] - min_size)
                end
            end
        end
        delta = clamp(delta, low_delta, high_delta)
    end
    if delta ~= 0 then
        hl.dispatch(hl.dsp.window.resize({
            x = axis == "x" and delta or 0,
            y = axis == "y" and delta or 0,
            relative = true,
        }))
    end
end

local function rightmost_column_is_full_width()
    if not is_scrolling() then
        return false
    end

    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    local workspace = hl.get_active_workspace()
    if not monitor or not active or not workspace then
        return false
    end

    local logical_width = logical_monitor_size(monitor)
    if logical_width <= 0 or active.size.x < logical_width * 0.9 then
        return false
    end

    local active_center_x = active.at.x + active.size.x / 2
    for _, other in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not other.floating and other.address ~= active.address then
            local other_center_x = other.at.x + other.size.x / 2
            if other_center_x < active_center_x then
                return true
            end
        end
    end
    return false
end

local function move_to_previous_column_if_full_width_rightmost(was_full_width_rightmost)
    if not was_full_width_rightmost then
        return
    end

    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    local logical_width = logical_monitor_size(monitor)
    -- Pan the scrolling view, then restore focus to the same window in case
    -- the layout selects a neighboring column while moving.
    hl.dispatch(hl.dsp.layout("move +" .. tostring(math.floor(logical_width / 2))))
    hl.dispatch(hl.dsp.focus({ window = active }))
end


local function toggle_full_width()
    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    local logical_width = logical_monitor_size(monitor)
    if logical_width <= 0 then
        return
    end

    local currently_full_width = active.size.x >= logical_width * 0.9

    if currently_full_width then
        local restore_rightmost = is_scrolling() and rightmost_column_is_full_width()
        if is_scrolling() then
            hl.dispatch(hl.dsp.layout("colresize 0.5"))
        else
            hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
            resize({ scroll_resize = { x = 0 }, resize = { x = 0 } }, 0.5)
        end
        move_to_previous_column_if_full_width_rightmost(restore_rightmost)
        return
    end

    if is_scrolling() then
        hl.dispatch(hl.dsp.layout("colresize 1"))
    else
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    end
end

local function launch_codex()
    local workspace = hl.get_active_workspace()
    if not workspace then return end

    local existing = {}
    for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
        existing[window.address] = true
    end

    hl.dispatch(hl.dsp.exec_cmd(
        "omarchy-launch-tui --app-id=org.omarchy.codex /home/jeebis/.local/bin/jeebis-codex-herdr"
    ))

    local attempts = 0
    local function maximize_codex_window()
        attempts = attempts + 1
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            if not existing[window.address]
                and window.class == "org.wezfurlong.wezterm"
                and type(window.title) == "string"
                and window.title:match("^Codex") then
                hl.dispatch(hl.dsp.focus({ window = window }))
                toggle_full_width()
                return
            end
        end
        if attempts < 60 then
            hl.timer(maximize_codex_window, { timeout = 50, type = "oneshot" })
        end
    end

    hl.timer(maximize_codex_window, { timeout = 50, type = "oneshot" })
end

local half_width_restore = {}

local function toggle_half_width()
    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    local logical_width = logical_monitor_size(monitor)
    if logical_width <= 0 then
        return
    end

    local address = active.address
    local current_width = active.size.x / logical_width
    local saved_width = half_width_restore[address]

    if saved_width and current_width < 0.9 then
        if is_scrolling() then
            hl.dispatch(hl.dsp.layout("colresize " .. string.format("%.4f", saved_width)))
        elseif saved_width >= 0.9 then
            hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        else
            resize({ scroll_resize = { x = 0 }, resize = { x = 0 } }, saved_width)
        end
        half_width_restore[address] = nil
        return
    end

    half_width_restore[address] = current_width
    local was_full_width_rightmost = is_scrolling() and rightmost_column_is_full_width()
    if not is_scrolling() and current_width >= 0.9 then
        hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    end
    resize({ scroll_resize = { x = 0 }, resize = { x = 0 } }, 0.5)
    move_to_previous_column_if_full_width_rightmost(was_full_width_rightmost)
end

-- Dキー: デスクトップ表示とアプリ起動
local show_desktop_state = {}
local show_desktop_fade_generation = {}

local function move_window_with_fade(window, workspace)
    local address = window.address
    local generation = (show_desktop_fade_generation[address] or 0) + 1
    show_desktop_fade_generation[address] = generation

    hl.dispatch(hl.dsp.window.set_prop({
        window = window,
        prop = "animation",
        value = "fade",
    }))
    hl.dispatch(hl.dsp.window.move({
        workspace = workspace,
        follow = false,
        window = window,
    }))

    -- Keep the override through the fade, then restore the window's default style.
    hl.timer(function()
        if show_desktop_fade_generation[address] ~= generation then
            return
        end
        hl.dispatch(hl.dsp.window.set_prop({
            window = address,
            prop = "animation",
            value = "unset",
        }))
        show_desktop_fade_generation[address] = nil
    end, { timeout = 450, type = "oneshot" })
end

local function toggle_show_desktop()
    local workspace = hl.get_active_workspace()
    if not workspace then
        return
    end

    local workspace_id = tostring(workspace.id)
    local saved = show_desktop_state[workspace_id]
    if saved then
        local special_windows = hl.get_workspace_windows("special:desktop")
        local restore_addresses = {}
        for _, address in ipairs(saved.addresses) do
            restore_addresses[address] = true
        end

        for _, window in ipairs(special_windows) do
            if restore_addresses[window.address] then
                move_window_with_fade(window, workspace_id)
            end
        end
        show_desktop_state[workspace_id] = nil

        if saved.focus_address then
            for _, window in ipairs(hl.get_workspace_windows(workspace_id)) do
                if window.address == saved.focus_address then
                    hl.dispatch(hl.dsp.focus({ window = window }))
                    break
                end
            end
        end
        return
    end

    local windows = hl.get_workspace_windows(workspace.id)
    local active = hl.get_active_window()
    local state = { addresses = {}, focus_address = active and active.address }
    for _, window in ipairs(windows) do
        table.insert(state.addresses, window.address)
    end
    if #state.addresses == 0 then
        return
    end

    show_desktop_state[workspace_id] = state
    for _, window in ipairs(windows) do
        move_window_with_fade(window, "special:desktop")
    end
end

hl.unbind("SUPER + D")
o.bind("SUPER + D", "Toggle show desktop", toggle_show_desktop)

hl.unbind("SUPER + ALT + D")
o.bind("SUPER + ALT + D", "Codex (Herdr, maximized)", launch_codex)

hl.unbind("SUPER + SHIFT + D")
o.bind(
    "SUPER + SHIFT + D",
    "Workspace overview",
    "omarchy-shell shell toggle jeebis.overview '{}'"
)

hl.unbind("SUPER + SHIFT + ALT + D")
o.bind("SUPER + SHIFT + ALT + D", "ChatGPT (new window here)", { launch = "/home/jeebis/.local/bin/jeebis-chatgpt-new-window" })

-- Old Z bindings are retired; Shift+F owns maximize.
for _, key in ipairs({ "SUPER + Z", "SUPER + CTRL + Z", "SUPER + SHIFT + Z", "SUPER + CTRL + SHIFT + Z" }) do hl.unbind(key) end
hl.unbind("SUPER + ALT + F")
hl.unbind("SUPER + Y")
o.bind("SUPER + Y", "Yazi file manager", { launch = "gtk-launch yazi" })

hl.unbind("SUPER + SHIFT + ALT + F")
hl.unbind("SUPER + ALT + SHIFT + F")
o.bind("SUPER + SHIFT + ALT + F", "GUI file manager", { omarchy = "nautilus" })

for _, item in ipairs(directions) do
    -- SUPER + 矢印、および SUPER + H/J/K/L: フォーカス移動
    hl.unbind("SUPER + " .. item.key)
    hl.unbind("SUPER + " .. item.vim)
    o.bind("SUPER + " .. item.key, nil, function() focus_direction(item) end)
    o.bind("SUPER + " .. item.vim, nil, function() focus_direction(item) end)

    -- SUPER + SHIFT + 矢印/HJKL: リサイズ
    hl.unbind("SUPER + SHIFT + " .. item.key)
    hl.unbind("SUPER + SHIFT + " .. item.vim)
    o.bind("SUPER + SHIFT + " .. item.key, "Resize window", function() resize(item) end)
    o.bind("SUPER + SHIFT + " .. item.vim, "Resize window", function() resize(item) end)

    -- SUPER + SHIFT + CTRL + 矢印/HJKL: ウィンドウをMove
    local move_key = "SUPER + SHIFT + CTRL + "
    local move_key_alt_order = "SUPER + CTRL + SHIFT + "
    hl.unbind(move_key .. item.key)
    hl.unbind(move_key_alt_order .. item.key)
    hl.unbind(move_key .. item.vim)
    hl.unbind(move_key_alt_order .. item.vim)
    o.bind(move_key .. item.key, "Move window", function() move_direction(item) end)
    o.bind(move_key .. item.vim, "Move window", function() move_direction(item) end)

    -- SUPER + CTRL + H/J/K/L: Swap (Shift is reserved for resize)
    hl.unbind("SUPER + CTRL + " .. item.vim)
    o.bind("SUPER + CTRL + " .. item.vim, nil, function()
        swap_direction(item)
    end)

    -- Same swap operation on arrows
    hl.unbind("SUPER + CTRL + " .. item.key)
    o.bind("SUPER + CTRL + " .. item.key, nil, function()
        swap_direction(item)
    end)

end

-- 上のリサイズ割り当てと重なる既定機能を別キーへ移動
o.bind("SUPER + ALT + CTRL + H", "Hardware menu", "omarchy-menu toggle hardware")
o.bind("SUPER + ALT + CTRL + K", "Herdr keybindings", "omarchy-menu-herdr-keybindings")

-- H/J/K/L にあった既定機能を Shift 付きへ移し
o.bind("SUPER + SHIFT + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + SHIFT + ALT + K", "Keybindings", "omarchy-menu-keybindings")
hl.unbind("SUPER + SHIFT + T")
o.bind("SUPER + SHIFT + T", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")


-- Reveal the app island for every workspace command, including reselecting
-- the current workspace. Keep the original numeric, Tab, and wheel actions.
local function focus_workspace_with_apps(workspace)
    return function()
        hl.dispatch(hl.dsp.focus({ workspace = workspace }))
        hl.dispatch(hl.dsp.event("jeebis.apps.reveal"))
    end
end

for workspace = 1, 10 do
    local keys = "SUPER + code:" .. tostring(workspace + 9)
    hl.unbind(keys)
    o.bind(keys, "Switch to workspace " .. workspace, focus_workspace_with_apps(tostring(workspace)))
end

for _, binding in ipairs({
    { keys = "SUPER + TAB", workspace = "e+1", description = "Next workspace" },
    { keys = "SUPER + SHIFT + TAB", workspace = "e-1", description = "Previous workspace" },
    { keys = "SUPER + CTRL + TAB", workspace = "previous", description = "Former workspace" },
    { keys = "SUPER + mouse_down", workspace = "e+1", description = "Scroll active workspace forward" },
    { keys = "SUPER + mouse_up", workspace = "e-1", description = "Scroll active workspace backward" },
}) do
    hl.unbind(binding.keys)
    o.bind(binding.keys, binding.description, focus_workspace_with_apps(binding.workspace))
end


-- Unified layout: Super / Ctrl+Alt / Alt / Ctrl.
for _, key in ipairs({ "SUPER + W", "SUPER + Q", "SUPER + RETURN", "SUPER + SHIFT + RETURN",
    "SUPER + F", "SUPER + SHIFT + F", "SUPER + ALT + RETURN", "SUPER + SHIFT + ALT + RETURN",
    "ALT + TAB", "ALT + SHIFT + TAB", "CTRL + ALT + TAB", "CTRL + ALT + SHIFT + TAB" }) do
    hl.unbind(key)
end
o.bind("SUPER + W", "Close window", hl.dsp.window.close())
-- Freeze the target list before closing: focus may move as windows disappear.
local function close_workspace_windows()
    local workspace = hl.get_active_special_workspace() or hl.get_active_workspace()
    if not workspace then return end
    local addresses = {}
    for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
        addresses[#addresses + 1] = window.address
    end
    for _, address in ipairs(addresses) do
        hl.dispatch(hl.dsp.window.close({ window = "address:" .. address }))
    end
end

hl.unbind("SUPER + SHIFT + W")
o.bind("SUPER + SHIFT + W", "Close windows in current workspace", close_workspace_windows)
o.bind("SUPER + F", "Search applications", "omarchy-menu toggle apps")
o.bind("SUPER + SHIFT + F", "Maximize / restore window", toggle_full_width)
hl.unbind("SUPER + N")
o.bind("SUPER + N", "New terminal", { launch = "wezterm start --always-new-process" })
o.bind("SUPER + ALT + RETURN", "Terminal", { launch = "wezterm start --always-new-process" })
o.bind("SUPER + SHIFT + ALT + RETURN", "Browser", "omarchy-launch-browser")
-- Keep application and monitor switching in the desktop's Super namespace.
for _, binding in ipairs({
    { "SUPER + SHIFT + PAGE_UP", "Previous workspace", "e-1" },
    { "SUPER + SHIFT + PAGE_DOWN", "Next workspace", "e+1" },
}) do
    hl.unbind(binding[1])
    o.bind(binding[1], binding[2], focus_workspace_with_apps(binding[3]))
end
for _, binding in ipairs({
    { "SUPER + CTRL + PAGE_UP", "Previous monitor", "-1" },
    { "SUPER + CTRL + PAGE_DOWN", "Next monitor", "+1" },
}) do
    hl.unbind(binding[1])
    o.bind(binding[1], binding[2], hl.dsp.focus({ monitor = binding[3] }))
end
-- Create a new terminal; scrolling's down split consumes its new column.
local function split_terminal(direction)
    prepare_directional_action()
    local workspace = hl.get_active_workspace()
    if not workspace then return end
    local existing = {}
    for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do existing[window.address] = true end
    local scrolling = is_scrolling()
    if not scrolling then hl.dispatch(hl.dsp.layout("preselect " .. direction)) end
    hl.dispatch(hl.dsp.exec_cmd([[wezterm start --always-new-process --cwd "$(omarchy-cmd-terminal-cwd)"]]))
    if scrolling and direction == "d" then
        local attempts = 0
        local function consume_new_terminal()
            attempts = attempts + 1
            for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
                if not existing[window.address] and window.class == "org.wezfurlong.wezterm" then
                    hl.dispatch(hl.dsp.focus({ window = window }))
                    hl.dispatch(hl.dsp.layout("consume"))
                    return
                end
            end
            if attempts < 60 then hl.timer(consume_new_terminal, { timeout = 50, type = "oneshot" }) end
        end
        hl.timer(consume_new_terminal, { timeout = 50, type = "oneshot" })
    end
end
o.bind("SUPER + RETURN", "Split terminal right", function() split_terminal("r") end)
o.bind("SUPER + SHIFT + RETURN", "Split terminal down", function() split_terminal("d") end)

for _, binding in ipairs({ { "SUPER + PAGE_UP", false }, { "SUPER + PAGE_DOWN", true } }) do
    hl.unbind(binding[1])
    o.bind(binding[1], "Cycle window", hl.dsp.window.cycle_next({ next = binding[2] }))
end
hl.unbind("SUPER + E")
o.bind("SUPER + E", "Exchange window: choose direction", hl.dsp.submap("exchange"))
hl.define_submap("exchange", function()
    for _, item in ipairs(directions) do
        local function exchange_once()
            hl.dispatch(hl.dsp.submap("reset"))
            swap_direction(item)
        end
        for _, key in ipairs({ item.vim, item.key }) do
            hl.bind(key, exchange_once)
            hl.bind("SUPER + " .. key, exchange_once)
        end
    end
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("catchall", hl.dsp.submap("reset"))
end)

-- Cycle the three preferred Omarchy themes and show the selected theme.
o.bind("SUPER + ALT + T", "Cycle theme: Tokyonight / Kanagawa / Catppuccin", (os.getenv("HOME") or "") .. "/.local/bin/jeebis-theme-cycle")
