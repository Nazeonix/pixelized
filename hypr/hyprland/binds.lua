-- ---- KEYBINDINGS ----

local mainMod = "SUPER" -- Sets "Windows" key as main modifier
local terminal = "kitty"
local fileManager = "nautilus"
local menu = "qs -c clover ipc call clover launcher"
local lock = "qs -c lock"
local wallRandom = "qs -c clover ipc call wallpaper random"
local wallNext = "qs -c clover ipc call wallpaper next"
local wallPrev = "qs -c clover ipc call wallpaper prev"

local colStep  = "0.1"  -- column width change per keypress (Super + / -)
local fineStep = "0.05" -- fine step (Super + Ctrl + arrows, resize submap)

-- ============================================================
-- APPS / QUICK ACTIONS  (intuitive Super + letter)
-- ============================================================

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))               -- Terminal (alternative)
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close()) -- Quit / close window
-- closeWindowBind:set_enabled(false)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(lock))                         -- Lock
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")) -- Power / exit

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))                  -- Explorer (file manager)
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))                     -- Launcher
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())                        -- Pseudo-tile
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(wallRandom))           -- Random wallpaper
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(wallNext))              -- Next wallpaper
hl.bind(mainMod .. " + CTRL + SHIFT + W", hl.dsp.exec_cmd(wallPrev))      -- Previous wallpaper
-- Clover (widget desktop)
local clover = "qs -c clover ipc call clover "
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(clover .. "edit"))  -- Clover edit mode
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd(clover .. "hide"))  -- Clover focus mode (hide/show widgets)
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(clover .. "toggle notes"))  -- Hide/show notes widget
-- Alt-Tab (release Alt to switch, Esc to cancel)
hl.bind("ALT + TAB",         hl.dsp.exec_cmd("qs -c clover ipc call alttab next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("qs -c clover ipc call alttab prev"))

-- ============================================================
-- SCREENSHOT  (Print = area select → annotate with satty)
-- ============================================================

hl.bind("PRINT", hl.dsp.exec_cmd(
    'mkdir -p "$HOME/Pictures/Screenshots" && grim -g "$(slurp)" -t png - | satty ' ..
    '--filename - ' ..
    '--output-filename "$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png" ' ..
    '--early-exit'
))

-- ============================================================
-- FOCUS
-- ============================================================

hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + period", hl.dsp.layout("focus r"))      -- next column
hl.bind(mainMod .. " + G",      hl.dsp.layout("fit visible"))  -- fit visible columns to screen


-- ============================================================
-- RESIZE WINDOWS
-- ============================================================

-- Column width: Super + / -
hl.bind(mainMod .. " + equal", hl.dsp.layout("colresize +" .. colStep), { repeating = true })
hl.bind(mainMod .. " + minus", hl.dsp.layout("colresize -" .. colStep), { repeating = true })

-- Cycle presets (1/3, 1/2, 2/3, full): Super + ] / [
hl.bind(mainMod .. " + bracketright", hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + bracketleft",  hl.dsp.layout("colresize -conf"))

-- Reset to half: Super + \
hl.bind(mainMod .. " + backslash", hl.dsp.layout("colresize 0.5"))

-- Window height inside a column: Super + Shift + / -
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = -20, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = 20,  relative = true }), { repeating = true })


-- ============================================================
-- RESIZE WITH ARROW KEYS
-- ============================================================

-- Super + Ctrl + Arrow: fine-grained
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.layout("colresize -" .. fineStep), { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.layout("colresize +" .. fineStep), { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0, y = 10,  relative = true }), { repeating = true })


-- ============================================================
-- MOVE WINDOWS
-- ============================================================

-- Super + Alt + Arrow
hl.bind(mainMod .. " + ALT + left",  hl.dsp.layout("swapcol l"))                  -- swap column left
hl.bind(mainMod .. " + ALT + right", hl.dsp.layout("swapcol r"))                  -- swap column right
hl.bind(mainMod .. " + ALT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + ALT + down",  hl.dsp.window.move({ direction = "down" }))


-- ============================================================
-- WINDOW MANAGEMENT
-- ============================================================

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))


-- ============================================================
-- WORKSPACES
-- ============================================================

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0

    hl.bind(
        mainMod .. " + " .. key,
        hl.dsp.focus({ workspace = i })
    )

    hl.bind(
        mainMod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = i })
    )
end


-- ============================================================
-- SPECIAL WORKSPACE / SCRATCHPAD
-- ============================================================

hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))


-- ============================================================
-- WORKSPACE SCROLLING
-- ============================================================

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))


-- ============================================================
-- MOUSE MOVE / RESIZE
-- ============================================================

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })


-- ============================================================
-- DEDICATED RESIZE MODE
-- ============================================================
--
-- Super + R enters resize mode.
--   Left/Right = column width
--   Up/Down    = window height
--   0          = reset column to half
--   Escape     = leave

hl.bind(mainMod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()

    hl.bind("left",  hl.dsp.layout("colresize -" .. fineStep), { repeating = true })
    hl.bind("right", hl.dsp.layout("colresize +" .. fineStep), { repeating = true })
    hl.bind("up",    hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
    hl.bind("down",  hl.dsp.window.resize({ x = 0, y = 10,  relative = true }), { repeating = true })

    hl.bind("0",      hl.dsp.layout("colresize 0.5"))
    hl.bind("escape", hl.dsp.submap("reset"))

end)


-- ============================================================
-- MULTIMEDIA
-- ============================================================

-- Volume / brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),   { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),    { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("qs -c clover ipc call brightness up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("qs -c clover ipc call brightness down"), { locked = true, repeating = true })


-- ============================================================
-- MEDIA PLAYER
-- ============================================================

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })
