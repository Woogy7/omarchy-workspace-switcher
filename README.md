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
```

Then add the keybinding — the plugin is an overlay, so it needs one. Append
[`bindings.example.lua`](bindings.example.lua) to `~/.config/hypr/bindings.lua`
(Omarchy ≥ 4.0 Lua config) and reload Hyprland. It replaces the default
`Super+Tab` / `Super+Shift+Tab` (next / previous workspace); set
`"tapAction": "switch"` if you want a quick tap to keep doing exactly that.
Prefer another key? Change the two `o.bind` lines.

Requirements: Omarchy 4.x (omarchy-shell), Hyprland with the Lua config
(for `hl.timer` / `hl.is_key_down`, used to detect the `Super` release), and
a Quickshell build with `ScreencopyView` (the one Omarchy ships).

## Use

**Hold-to-switch (the bind above):** `Super+Tab` opens with the *next*
workspace pre-selected. Keep `Super` held, tap `Tab` / `Shift+Tab` to cycle
(wraps around), **release `Super` to switch**. `Esc` cancels.

What a *lone* tap does (press `Super+Tab`, release without cycling further)
is up to you — `tapAction`:

- `"browse"` (default): the switcher stays open as a plain picker — arrows,
  hover, `Enter` to switch, `Esc` to close. Pressing `Super+Tab` again while
  it is open re-enters hold mode (release switches).
- `"switch"`: pure alt-tab — a tap jumps to the next workspace immediately
  (and a fast tap doesn't even show the UI), exactly like the Omarchy default
  `Super+Tab` it replaces.

**Browse mode:** `omarchy-shell shell toggle io.github.woogy7.workspaces`
opens it as a plain picker:

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
| `tapAction`         | `"browse"` | lone `Super+Tab` tap: `"browse"` keeps the switcher open, `"switch"` jumps to the next workspace |
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
