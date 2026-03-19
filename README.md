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

## Build & Run

```bash
swift run           # development
make bundle         # release .app bundle
make dmg            # release .dmg
make install        # copy to /Applications
```

## Install

1. `make install`
2. Launch — grant Accessibility permission when prompted
3. ⌥Tab to switch windows

## Configuration

Click the ⚡ icon in the menu bar → Settings:

- **Modifier key**: Option, Control, or Command
- **Trigger key**: Tab, Backtick, or Space
- **Size**: Scale the switcher panel up or down
