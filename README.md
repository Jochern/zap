# Zap

Minimal macOS window switcher. Native Swift, no bloat. Inspired by [AltTab](https://github.com/lwouis/alt-tab-macos) — but stripped down to the essentials.

## Features

- **Fast window switching** via configurable keyboard shortcut (default: ⌥Tab)
- **Window thumbnails** with async loading and caching
- **App icons** and window titles
- **Shift+shortcut** to cycle backwards
- **Settings** via menu bar (size slider, shortcut configuration)
- **No dock icon** — lives in the menu bar

## Requirements

- macOS 13.0+
- Accessibility permission (prompted on first launch)
- Screen Recording permission (for window thumbnails)

## Permissions

Zap needs two macOS permissions to work. You'll be prompted on first launch.

| Permission | Why | What happens without it |
|---|---|---|
| **Accessibility** | Intercept the global hotkey and focus windows | Zap can't detect your shortcut or switch windows |
| **Screen Recording** | Capture window thumbnails via `CGWindowListCreateImage` | Switcher shows app icons only, no previews |

You can manage these anytime in **System Settings → Privacy & Security**.

## Build & Run

```bash
swift run           # development
make bundle         # release .app bundle
make dmg            # release .dmg
make install        # copy to /Applications
```

## Install

### From source

1. `make install`
2. Launch — grant Accessibility permission when prompted
3. ⌥Tab to switch windows

### From DMG download

Since Zap is not notarized with Apple, macOS will block it with a "damaged and can't be opened" warning. To fix this, run:

```bash
xattr -cr /Applications/Zap.app
```

Or: right-click Zap.app → **Open** → click **Open** in the dialog.

After that, grant Accessibility permission when prompted and you're good to go.

## Configuration

Click the ⚡ icon in the menu bar → Settings:

- **Modifier key**: Option, Control, or Command
- **Trigger key**: Tab, Backtick, or Space
- **Size**: Scale the switcher panel up or down
