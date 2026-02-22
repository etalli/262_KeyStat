# KeyCounter

English | [日本語](README.ja.md)

A macOS menu bar app that monitors and records global keyboard input.
Counts keystrokes per key, persists the data to a JSON file, and sends a macOS notification every 1,000 presses.

---

## Features

- **Global monitoring**: Counts all keystrokes regardless of the active application
- **Menu bar statistics**: Click the keyboard icon to see today's count, total count, and the top 10 most-pressed keys
- **Today's count**: Daily keystroke total, reset automatically at midnight
- **Persistence**: Counts survive reboots — stored in a JSON file
- **Milestone notifications**: Native macOS notification at every 1,000 presses per key (1000, 2000, …)
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
  └─ .build/release/KeyCounter   (executable)

KeyCounter.app/
  ├── Contents/MacOS/KeyCounter   <- executable copied here
  └── Contents/Info.plist         <- LSUIElement=true hides the Dock icon
```

### `--install` steps (recommended for development)

| Step | What it does |
|------|--------------|
| `cp -r KeyCounter.app /Applications/` | Installs to `/Applications` |
| `codesign --force --deep --sign -` | Ad-hoc signature (stabilises Accessibility permission) |
| `pkill -x KeyCounter` | Stops the running process before replacing the binary |
| `tccutil reset Accessibility <bundle-id>` | Clears the stale TCC entry for the old binary hash |
| `open ~/Applications/KeyCounter.app` | Launches the new build |

**Why TCC reset is needed:** macOS stores Accessibility permissions keyed by binary hash. Each `swift build` produces a new binary with a different hash, making the old TCC entry stale. Without resetting, `AXIsProcessTrusted()` returns `false` even though the toggle appears ON in System Settings.

### Logs

```bash
tail -f ~/Library/Logs/KeyCounter/app.log
```

---

## Accessibility Permission

An alert is shown on first launch if the permission is missing.

1. Click **Open System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Enable **KeyCounter**
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
| **Records** | Key names (e.g. `Space`, `e`) and press counts only |
| **Does NOT record** | Typed text, sequences, passwords, clipboard content |
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
~/Library/Application Support/KeyCounter/counts.json
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

## File structure

```
262_MacOS_keyCounter/
├── Package.swift
├── build.sh
├── Resources/
│   └── Info.plist
└── Sources/KeyCounter/
    ├── main.swift
    ├── AppDelegate.swift
    ├── KeyboardMonitor.swift
    ├── KeyCountStore.swift
    ├── NotificationManager.swift
    └── L10n.swift
```

---

## Architecture

### Data flow

```
Key press
  |
  v
CGEventTap  (OS-level event hook)
  |  KeyboardMonitor.swift
  |  keyTapCallback()  <-- file-scope global function (@convention(c) compatible)
  |
  v
KeyCountStore.shared.increment(key:)
  |  serial DispatchQueue for thread safety
  |  counts[key] += 1
  |  dailyCounts[today] += 1
  |  scheduleSave()   <- debounced 2 s write
  |
  +-- count % 1000 == 0?
  |     YES -> DispatchQueue.main.async { NotificationManager.notify() }
  |
  v
(on menu open)
NSMenuDelegate.menuWillOpen
  └─ KeyCountStore.{todayCount, totalCount, topKeys()}  -> rebuild menu
```

---

### File responsibilities

#### [main.swift](Sources/KeyCounter/main.swift)

Entry point. Launches `NSApplication` with `.accessory` policy so the app appears only in the menu bar, not in the Dock.

```swift
app.setActivationPolicy(.accessory)
```

---

#### [KeyboardMonitor.swift](Sources/KeyCounter/KeyboardMonitor.swift)

Intercepts system-wide key-down events via `CGEventTap`.

**Key design decision — `@convention(c)` constraint:**

`CGEventTapCallBack` is a C function pointer type, which means Swift closures that capture variables cannot be used directly. The callback is therefore defined as a file-scope global function and accesses state only through singletons (`KeyCountStore.shared`, etc.), which require no capture.

```
CGEvent.tapCreate(callback: keyTapCallback)
                            ^
                  global function (no captures)
                  -> implicitly convertible to @convention(c)
```

**Tap recovery:** If the tap is disabled by system timeout (`.tapDisabledByTimeout`), the callback immediately re-enables it via `CGEvent.tapEnable`.

Key code to name translation is handled by a static lookup table in `keyName(for:)` (US keyboard layout).

---

#### [KeyCountStore.swift](Sources/KeyCounter/KeyCountStore.swift)

Singleton that manages counts and persists them to disk.

**Thread safety:**

The `CGEventTap` callback runs outside the main thread. A serial `DispatchQueue` serialises all dictionary access.

```
CGEventTap thread             Main thread
      |                            |
  queue.sync { increment }    queue.sync { topKeys() }
      |  <-- serialised -->        |
  scheduleSave()                   ...
      |
  queue.asyncAfter(+2 s) { save() }   <- debounced write
```

JSON is written with `.atomic` to prevent file corruption. Consecutive writes within 2 seconds are coalesced into a single disk write via `DispatchWorkItem` cancellation.

---

#### [NotificationManager.swift](Sources/KeyCounter/NotificationManager.swift)

Delivers native notifications via `UNUserNotificationCenter`.
`trigger: nil` means immediate delivery (no scheduling).
Notification permission is requested on first singleton access.

---

#### [AppDelegate.swift](Sources/KeyCounter/AppDelegate.swift)

Manages the menu bar UI and accessibility permission recovery.

**Menu rebuild strategy:**
Rebuilding the menu on every keystroke is wasteful. Instead, `NSMenuDelegate.menuWillOpen` is used to rebuild only when the user actually opens the menu. The menu is split into three sections: status, stats, settings.

**Permission recovery (layered):**
1. `appDidBecomeActive` — fires when the user switches back to any app; attempts `monitor.start()` immediately
2. `schedulePermissionRetry()` — polls `AXIsProcessTrusted()` every 3 s as a fallback
3. `setupHealthCheck()` — checks `monitor.isRunning` every 5 s and triggers retry if stopped

---

#### [L10n.swift](Sources/KeyCounter/L10n.swift)

Centralised localisation singleton. Supports English, Japanese, and system auto-detection. Language preference is persisted in `UserDefaults`.

---

## Menu structure

```
[keyboard icon]
──────────────────────────
● Monitoring              <- green / red, tappable if stopped
──────────────────────────
Since Feb 1, 2026
Today: 3,120 keystrokes
Total: 48,291 keystrokes
──────────────────────────
🥇 Space   —  15,234
🥈 Return  —   8,901
🥉 e       —   7,432
   a       —   6,100
   ...
──────────────────────────
About KeyCounter
Settings…
  ├─ Open Log Folder
  ├─ Language
  │   ├─ System (Auto)
  │   ├─ English
  │   └─ 日本語
  └─ Reset…
──────────────────────────
Quit                    Q
```
