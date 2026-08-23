# Workspace Switcher

Alt-tab for workspaces, for the [Omarchy](https://omarchy.org) shell.
Hold `Super`, tap `Tab` to cycle through **live previews** of your workspaces,
release to switch. Calm by design: flat cards, no overlap, same theme tokens
as Omarchy's own theme/background picker. Two layouts — a **ribbon** that
keeps every workspace on screen, or a **carousel** that keeps the selected
one in the middle.

Previews are genuinely live. Each card composites the workspace's windows at
their real geometry with Quickshell's `ScreencopyView` (hyprland-toplevel-export),
so even workspaces you can't see show their actual window contents — no
screenshots, no cache, no background daemon. Empty workspaces show the current
wallpaper.

## Install

```bash
omarchy plugin add https://github.com/Woogy7/omarchy-workspace-switcher.git --enable
~/.config/omarchy/plugins/io.github.woogy7.workspaces/install-menu   # Setup › Workspace Switcher menu
```

Then add the keybindings — the plugin is an overlay, so it needs them. Append
[`bindings.example.lua`](bindings.example.lua) to `~/.config/hypr/bindings.lua`
(Omarchy ≥ 4.0 Lua config) and reload Hyprland. Out of the box it gives you:

| Keys                    | Does |
|-------------------------|------|
| `Super+Tab`             | opens the switcher as a picker: arrows / hover to select, `Enter` or click to switch, `Esc` to close |
| `Alt+Tab` (hold)        | alt-tab style: opens with the next workspace pre-selected; keep `Alt` held and tap `Tab` / `Shift+Tab` to cycle (wraps); **release `Alt` to switch**; `Esc` cancels |

Both replace Omarchy defaults (`Super+Tab` next workspace, `Alt+Tab` cycle
windows). Set `hold_mod = "SUPER"` in the snippet if you'd rather hold Super,
and drop the picker bind. The modifier release is detected compositor-side
(`hl.is_key_down` polled by an `hl.timer`), so there is no client-side guessing.

Requirements: Omarchy 4.x (omarchy-shell), Hyprland with the Lua config, and a
Quickshell build with `ScreencopyView` (the one Omarchy ships).

## Use

**Hold-to-switch (`Alt+Tab`):** what a *lone* tap does (press, release without
cycling further) is the `tapAction` setting:

- `"browse"` (default): the switcher stays open as a picker — arrows, hover,
  `Enter` to switch, `Esc` to close. `Alt+Tab` again while open re-enters hold
  mode (release switches).
- `"switch"`: pure alt-tab — a tap jumps to the next workspace immediately (a
  fast tap doesn't even show the UI).

**Picker (`Super+Tab`, or `omarchy-shell shell toggle io.github.woogy7.workspaces`):**

| Key / input          | Action                                   |
|----------------------|------------------------------------------|
| ← → / h l            | move selection                           |
| Tab / Shift+Tab      | cycle selection (wraps)                  |
| 1–9, 0               | jump to workspace 1–10 and switch        |
| Enter                | switch to selected                       |
| Esc / click outside  | close                                    |
| hover a card         | select it                                |
| click a card         | switch to that workspace                 |
| scroll wheel         | ribbon: scroll when it overflows, else move selection; carousel: move selection |
| drag / flick         | carousel: slides and selects             |

### IPC actions

`omarchy-shell shell summon io.github.woogy7.workspaces '{"action": "<a>"}'`
with `open-next` / `open-prev` (hold-mode open), `next` / `prev` (cycle; opens
in hold mode if closed), `commit` (hold mode: switch to the selection). This
is what the keybinding uses; it also lets you wire up other modifiers or
a gesture.

## Settings

**Setup › Workspace Switcher** in the Omarchy menu (`Super+Space`, or
`omarchy menu summon setup.workspace-switcher`) exposes everything below with ✓
marks that update in place — show in bar, layout, tap action, preview size,
gap, monitors, workspaces shown, look toggles, selected emphasis, animations,
reset. Install it with `install-menu` (idempotent; `install-menu --remove`
takes it out again). It merges a marker-delimited block into
`~/.config/omarchy/extensions/omarchy-menu.jsonc` and never touches your other
entries.

**Bar icon.** The plugin also ships a bar widget (a 󰕰 chip): left click opens
that settings menu, right click opens the switcher (swap them with the
widget's `click` setting in the bar settings UI). Turn it on/off with the
menu's **Show in bar** row or `switcher-config bar on|off` — it lands next to
the Vitals chip if you have it, else at the end of the right section; move it
with `omarchy bar move`.

Under the hood the menu calls `switcher-config`, which you can use directly:

```bash
switcher-config show                 # effective settings
switcher-config get layout
switcher-config set layout carousel  # numbers/booleans are typed automatically
switcher-config toggle showLabels
switcher-config bar on|off|toggle|status
switcher-config reset
```

Settings live **inline on the plugin's entry** in `~/.config/omarchy/shell.json`
(`plugins[]`). The file is watched, so edits apply live — no restart.

```json
{
  "id": "io.github.woogy7.workspaces",
  "layout": "carousel",
  "previewWidth": 360,
  "unselectedOpacity": 0.7,
  "selectedScale": 1.04
}
```

| Key                 | Default    | Meaning |
|---------------------|------------|---------|
| `layout`            | `"ribbon"` | `"ribbon"` (cards shrink to keep every workspace on screen) or `"carousel"` (fixed-size cards, selected one centred) |
| `previewWidth`      | `320`      | card width in logical px (carousel: fixed; ribbon: preferred) |
| `minPreviewWidth`   | `200`      | ribbon only: smallest card before the row starts scrolling |
| `gap`               | `28`       | space between cards |
| `monitors`          | `"all"`    | `"all"` or `"focused"` — only workspaces on the focused monitor (not-yet-created workspaces count as focused) |
| `minWorkspaces`     | `5`        | always show workspaces 1..N (like the bar), even if empty |
| `maxWorkspaces`     | `10`       | ignore workspace ids above this |
| `showWallpaper`     | `true`     | current wallpaper behind the windows |
| `showLabels`        | `true`     | number + last window title under each card |
| `showHints`         | `true`     | faint key hint line under the strip |
| `hoverSelects`      | `true`     | moving the mouse over a card selects it (carousel does not recentre on hover) |
| `tapAction`         | `"browse"` | lone tap of the hold key: `"browse"` keeps the switcher open, `"switch"` jumps to the next workspace |
| `animations`        | `true`     | master switch; `false` makes everything instant |
| `animationDuration` | `160`      | ms for selection/scroll/scale motion |
| `fadeDuration`      | `140`      | ms for the open/close fade |
| `selectedScale`     | `1.0`      | e.g. `1.04` for a gentle lift on the selected card |
| `unselectedScale`   | `1.0`      | e.g. `0.96` to shrink neighbours (carousel) |
| `unselectedOpacity` | `1.0`      | e.g. `0.7` to dim neighbours |

Colours come from the theme's `[image-picker]` tokens (scrim, text,
selected/unselected border), so it follows your theme like the picker does.

## Notes

- Windows on hidden workspaces generally stop repainting (Hyprland sends them
  no frame callbacks), so their preview is their last committed frame — which
  is exactly what you'd see on switching.
- Hacking on `Ribbon.qml`: the shell's hot-reload keeps the old component for
  `keepLoaded` overlays, so run `omarchy-restart-shell` after edits. Settings
  changes don't need that.
- Workspaces are switched with `hyprctl dispatch 'hl.dsp.focus({ workspace = "N" })'`
  (Lua dispatcher syntax). The overlay keeps exclusive keyboard focus until it
  unmaps on purpose: dropping it earlier makes Hyprland refocus its last window
  and yank the workspace back.

## License

MIT
