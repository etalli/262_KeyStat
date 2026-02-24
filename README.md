# KeyStat

English | [日本語](README.ja.md)

A macOS menu bar app that monitors and records global keyboard and mouse input.
Counts keystrokes and mouse clicks per key/button, saves the data to a JSON file, and sends a macOS notification every 1,000 presses.

---

## Features

- **Global monitoring**: Counts all keystrokes and mouse clicks regardless of the active application
- **Mouse click tracking**: Left / Right / Middle buttons and extra buttons are counted separately
- **Menu bar statistics**: Click the keyboard icon to see today's count, total count, and the top 10 most-used keys/buttons
- **Show All**: Open a full ranked list of every key and mouse button with total and today's counts
- **Today's count**: Daily input total, reset automatically at midnight
- **Data saving**: Counts survive reboots — stored in a JSON file
- **Milestone notifications**: Native macOS notification at every 1,000 presses per key/button (1000, 2000, …)
- **Multilingual UI**: English / 日本語 / System auto-detect
- **Instant permission recovery**: Monitoring resumes automatically when Accessibility permission is granted

---

## Requirements

| Item | Requirement |
|------|-------------|
| macOS | 13 Ventura or later |
| Swift | 5.9 or later (bundled with Xcode 15) |
| Permission | Accessibility (prompted on first launch) |

---

## Build

```bash
# Build App Bundle only
./build.sh

# Build and launch immediately (from project directory)
./build.sh --run

# Build, install to /Applications, codesign, reset TCC, and launch  ← recommended
./build.sh --install

# Build and create a distributable DMG (drag app to /Applications)
./build.sh --dmg
```

> Running `swift build` alone produces the executable, but notifications require a proper App Bundle. Always use `build.sh`.

### What the build script does

```
swift build -c release
  └─ .build/release/KeyStat   (executable)

KeyStat.app/
  ├── Contents/MacOS/KeyStat   <- executable copied here
  └── Contents/Info.plist         <- LSUIElement=true hides the Dock icon
```

### `--install` steps (recommended for development)

| Step | What it does |
|------|--------------|
| `cp -r KeyStat.app /Applications/` | Installs to `/Applications` |
| `codesign --force --deep --sign -` | Ad-hoc signature (stabilises Accessibility permission) |
| `pkill -x KeyStat` | Stops the running process before replacing the binary |
| `tccutil reset Accessibility <bundle-id>` | Clears the stale TCC entry for the old binary hash |
| `open ~/Applications/KeyStat.app` | Launches the new build |

**Why TCC reset is needed:** macOS stores Accessibility permissions keyed by binary hash. Each `swift build` produces a new binary with a different hash, making the old TCC entry stale. Without resetting, `AXIsProcessTrusted()` returns `false` even though the toggle appears ON in System Settings.

### Logs

```bash
tail -f ~/Library/Logs/KeyStat/app.log
```

---

## Accessibility Permission

An alert is shown on first launch if the permission is missing.

1. Click **Open System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Enable **KeyStat**
4. Switch back to any app — monitoring resumes instantly

**Recovery mechanism (layered):**

| Trigger | Latency |
|---------|---------|
| App becomes active (`didBecomeActiveNotification`) | ~instant |
| Permission retry timer | every 3 s |
| Health check timer | every 5 s |

---

## Security

### What this app does and does not do

| | Details |
|---|---|
| **Records** | Key names (e.g. `Space`, `e`) and mouse button names (e.g. `🖱Left`) with press counts only |
| **Does NOT record** | Typed text, sequences, passwords, clipboard content, or mouse cursor position |
| **Storage** | Local JSON file only — no network transmission |
| **Event access** | `.listenOnly` tap — read-only, cannot inject or modify keystrokes |

### Risk summary

| Area | Risk | Mitigation in this app |
|------|------|------------------------|
| Global key monitoring | High (by nature) | `.listenOnly` + `tailAppendEventTap` — passive only |
| Data content | Low | Key name + count only; typed text cannot be reconstructed |
| Data file | Medium | Unencrypted; readable by any process running as the same user |
| Network | None | No outbound connections |
| Process execution | Low | Only runs `/usr/bin/open` with a hardcoded bundle path |
| Code signing | Medium | Ad-hoc only; Gatekeeper blocks distribution to other users |

### Why Accessibility permission is required

macOS requires explicit user consent (via System Settings > Privacy & Security > Accessibility) before any app can install a global `CGEventTap`. Without this permission, `AXIsProcessTrusted()` returns `false` and the tap is never created. This is a macOS-enforced gate — the app cannot monitor keystrokes silently without the user granting it.

### For distribution

The app currently uses an ad-hoc signature (`codesign --sign -`), which is sufficient for personal use. To distribute to other users:

- Enrol in the **Apple Developer Program** ($99/year)
- Sign with a **Developer ID Application** certificate
- Submit for **Apple Notarisation** (required for Gatekeeper approval on macOS 10.15+)

---

## Data file

```
~/Library/Application Support/KeyStat/counts.json
```

```json
{
  "startedAt": "2026-01-01T00:00:00Z",
  "counts": {
    "Space": 15234,
    "Return": 8901,
    "e": 7432
  },
  "dailyCounts": {
    "2026-02-22": 3120
  }
}
```

Use **Settings… > Open Log Folder** in the menu to open the directory in Finder.


---

For internal design details, see [Architecture.md](Architecture.md).
