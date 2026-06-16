-- Bulk of the Hyprland config. Placeholders in @at-sign@ form are substituted
-- by lib.replaceStrings in default.nix (kbLayout, picturesDir).

-- Catch-all monitor rule (empty output matches every connector). @scale@ is
-- substituted by default.nix; "auto" defers to Hyprland's DPI heuristic.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "@scale@" })

hl.config({
  general = {
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(fb3c67ff)", "rgba(1f5d8dff)" }, angle = 45 },
    },
  },
  decoration = {
    rounding = 5,
  },
  input = {
    kb_layout = "@kbLayout@",
  },
})

local mod = "SUPER"

-- Apps
hl.bind(mod .. " + M", hl.dsp.exec_cmd("firefox"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + CTRL + F", hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = "toggle" }))
hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("ghostty"))
hl.bind(mod .. " + CTRL + Q", hl.dsp.exec_cmd("wlogout"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("fuzzel"))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd("cd @picturesDir@; wayshot"))
hl.bind(mod .. " + N", hl.dsp.exec_cmd("ghostty -e yazi"))

-- System
hl.bind(mod .. " + F1", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(mod .. " + F2", hl.dsp.exec_cmd("loginctl lock-session $XDG_SESSION_ID"))
hl.bind(mod .. " + F5", hl.dsp.exec_cmd("systemctl reboot"))
hl.bind(mod .. " + F9", hl.dsp.exec_cmd("systemctl poweroff"))

-- Focus
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Swap focused window with its neighbor
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.swap({ direction = "d" }))

-- Workspace switch
hl.bind(mod .. " + U", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + I", hl.dsp.focus({ workspace = 2 }))
hl.bind(mod .. " + O", hl.dsp.focus({ workspace = 3 }))
hl.bind(mod .. " + P", hl.dsp.focus({ workspace = 4 }))
hl.bind(mod .. " + Y", hl.dsp.focus({ workspace = 5 }))
hl.bind(mod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 0 }))

-- Move focused window to workspace
hl.bind(mod .. " + SHIFT + U", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mod .. " + SHIFT + I", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mod .. " + SHIFT + O", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mod .. " + SHIFT + P", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mod .. " + SHIFT + Y", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 0 }))

-- Keyboard layout: hyprctl switchxkblayout accepts "all" so we don't need
-- per-device targeting. Affects only "main: yes" plus a few HID consumer
-- devices that don't produce typed characters.
hl.bind(mod .. " + SPACE", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- Mouse
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + ALT + mouse:272", hl.dsp.window.resize(), { mouse = true })

-- Locked binds (work even when a lockscreen / input inhibitor is active)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl --player=spotify,%any play-pause"), { locked = true })
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl --player=spotify,%any stop"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl --player=spotify,%any next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl --player=spotify,%any previous"), { locked = true })
