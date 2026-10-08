# Get Lost

Every open window, grouped by workspace, as a plain text list in the Omarchy menu style. Tap a key, see where everything is, jump to it.

<!-- TODO: preview.png -->

Made for the moment a window you were just using seems to have vanished: it's behind a maximized window, scrolled off-screen in the scrolling layout, or on a workspace that moved to another monitor when you unplugged it.

## Features

- Every workspace with its windows listed underneath, including the scratchpad and other special workspaces.
- Each workspace header shows its monitor, its layout (dwindle or scrolling), and the shortcut that takes you there.
- Windows you can't currently see are dimmed: covered by a fullscreen or maximized window, or scrolled off the edge of the screen.
- Empty workspaces between used ones show as dimmed "empty" lines, so the numbering never skips.
- Terminals running tmux show the session name and how many tmux windows it has.
- Updates live while open. Change a layout, move windows or switch workspace with your usual shortcuts and the list follows.
- Number keys show a single workspace. No search box and nothing to type.
- Uses the menu colours and font of your current Omarchy theme.

## Requirements

- Omarchy with Omarchy Shell plugin support (tested with Omarchy 4 and Hyprland 0.56).
- `jq` (ships with Omarchy).
- Optional: `tmux`, for session names and window counts.

## Install

```bash
omarchy plugin add https://github.com/JamesForan/getlost.git --enable
```

Then add a key binding to `~/.config/hypr/bindings.lua`. To open it with a tap of SUPER on its own (press and release, no other key):

```lua
o.bind("SUPER + Super_L", "Get Lost", "omarchy-shell shell toggle jamesforan.getlost", { release = true })
```

It's a release binding, so SUPER + anything else still works as normal. If you'd rather use a regular shortcut, check `omarchy menu keybindings --print` for a free one first:

```lua
o.bind("SUPER + O", "Get Lost", "omarchy-shell shell toggle jamesforan.getlost")
```

Hyprland reloads the binding when you save the file. You can also open it from a terminal:

```bash
omarchy-shell shell toggle jamesforan.getlost
```

## Keys

| Key | Action |
| --- | --- |
| 1–9 | Show only that workspace |
| 0, Backspace | Show all workspaces again |
| ↑ ↓, j k, Tab | Move between windows |
| Enter, click | Go to that window |
| Esc | Back to all workspaces, then close |
| Your toggle key | Close |

Going to a dimmed window brings it into view: it takes over from a maximized window, or the scrolling layout scrolls to it.

## Notes

- Browsers only tell the compositor the active tab's title, so tab counts aren't shown.
- Shortcut hints come from Omarchy's keybinding list (`omarchy menu keybindings --print`). A special workspace you open with your own script won't have one.
- Window rows use Nerd Font icons for common apps (browsers, VS Code, terminals, Spotify, Slack, file managers) and a generic icon for the rest.
- This plugin runs inside the Omarchy Shell process. Review the source before installing any plugin.

## Remove

Remove the key binding from `~/.config/hypr/bindings.lua`, then:

```bash
omarchy plugin remove jamesforan.getlost
```

## Development

The repository root is the plugin folder:

- `manifest.json`: plugin manifest (an `overlay`, kept loaded between uses).
- `Overlay.qml`: the list UI.
- `window-list`: Bash and jq script that reads Hyprland and prints the grouped windows as JSON (`window-list focus <address>` focuses a window). Run it directly to see the data.

Validate with `omarchy plugin validate .`. For local testing, copy the three files to `~/.config/omarchy/plugins/jamesforan.getlost/`, run `omarchy-shell shell rescanPlugins` and `omarchy plugin enable jamesforan.getlost`. The overlay stays loaded, so restart the shell (`omarchy restart shell`) after editing `Overlay.qml`. Edits to `window-list` apply on the next open.

## License

MIT
