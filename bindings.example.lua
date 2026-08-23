-- Workspace Switcher keybindings for Omarchy (Lua config, Omarchy >= 4.0 "quattro").
-- Append to ~/.config/hypr/bindings.lua.
--
-- Alt-tab style: SUPER+TAB opens the switcher with the next workspace
-- pre-selected; keep SUPER held and tap TAB / SHIFT+TAB to cycle; release
-- SUPER to switch; ESC cancels. A quick SUPER+TAB tap still means "next
-- workspace" (and SUPER+SHIFT+TAB "previous"), like the Omarchy defaults
-- these replace.

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")

local switcher = { id = "io.github.woogy7.workspaces", timer = nil, held = false }

local function switcher_send(action)
  hl.exec_cmd("omarchy-shell shell summon " .. switcher.id .. " '{\"action\":\"" .. action .. "\"}'")
end

-- Poll the compositor for the modifier release; it is the source of truth,
-- so the overlay never has to guess whether SUPER is still down.
local function switcher_watch_release()
  if switcher.held then return end
  switcher.held = true
  if switcher.timer then switcher.timer:set_enabled(false) end
  switcher.timer = hl.timer(function()
    if not switcher.held then return end
    if not hl.is_key_down("Super_L") and not hl.is_key_down("Super_R") then
      switcher.held = false
      if switcher.timer then switcher.timer:set_enabled(false) end
      switcher_send("commit")
    end
  end, { timeout = 25, type = "repeat" })
end

o.bind("SUPER + TAB", "Workspace switcher (next)", function()
  switcher_send(switcher.held and "next" or "open-next")
  switcher_watch_release()
end)
o.bind("SUPER + SHIFT + TAB", "Workspace switcher (previous)", function()
  switcher_send(switcher.held and "prev" or "open-prev")
  switcher_watch_release()
end)

-- Prefer a plain picker instead (no hold; Enter/click switches)? Use:
-- o.bind("SUPER + TAB", "Workspace switcher", "omarchy-shell shell toggle io.github.woogy7.workspaces")
