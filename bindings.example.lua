-- Workspace Switcher keybindings for Omarchy (Lua config, Omarchy >= 4.0 "quattro").
-- Append to ~/.config/hypr/bindings.lua, then reload Hyprland.
--
-- Two binds:
--   SUPER+TAB  opens the switcher as a plain picker: arrows/hover to select,
--              Enter or click to switch, Esc to close.
--   ALT+TAB    alt-tab style: opens with the next workspace pre-selected; keep
--              ALT held and tap TAB / SHIFT+TAB to cycle; release ALT to switch.
--              What a lone tap does is the "tapAction" setting (browse | switch).
--
-- Change `hold_mod` to "SUPER" (and keep or drop the plain picker bind) if you
-- would rather hold Super. Both replace Omarchy defaults: SUPER+TAB (next
-- workspace) and ALT+TAB / ALT+SHIFT+TAB (cycle windows).

local switcher = { id = "io.github.woogy7.workspaces", timer = nil, held = false }
local hold_mod = "ALT"
local hold_keys = ({ ALT = { "Alt_L", "Alt_R" }, SUPER = { "Super_L", "Super_R" } })[hold_mod]

local function switcher_send(action)
  hl.exec_cmd("omarchy-shell shell summon " .. switcher.id
    .. " '{\"action\":\"" .. action .. "\",\"modifier\":\"" .. hold_mod:lower() .. "\"}'")
end

-- Poll the compositor for the modifier release; it is the source of truth,
-- so the overlay never has to guess whether the modifier is still down.
local function switcher_watch_release()
  if switcher.held then return end
  switcher.held = true
  if switcher.timer then switcher.timer:set_enabled(false) end
  switcher.timer = hl.timer(function()
    if not switcher.held then return end
    local down = false
    for _, k in ipairs(hold_keys) do if hl.is_key_down(k) then down = true end end
    if not down then
      switcher.held = false
      if switcher.timer then switcher.timer:set_enabled(false) end
      switcher_send("commit")
    end
  end, { timeout = 25, type = "repeat" })
end

-- Plain picker on SUPER+TAB.
hl.unbind("SUPER + TAB")
o.bind("SUPER + TAB", "Workspace switcher", "omarchy-shell shell toggle " .. switcher.id)

-- Hold-to-switch on <hold_mod>+TAB.
hl.unbind(hold_mod .. " + TAB")
hl.unbind(hold_mod .. " + SHIFT + TAB")
o.bind(hold_mod .. " + TAB", "Workspace switcher (next)", function()
  switcher_send(switcher.held and "next" or "open-next")
  switcher_watch_release()
end)
o.bind(hold_mod .. " + SHIFT + TAB", "Workspace switcher (previous)", function()
  switcher_send(switcher.held and "prev" or "open-prev")
  switcher_watch_release()
end)
