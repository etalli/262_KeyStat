# KeyLens

English | [日本語](README.ja.md)

<div align="center">

[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)
![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
[![Download DMG](https://img.shields.io/badge/⬇_Download-DMG-blue?style=flat-square)](https://github.com/etalli/262_KeyLens/releases/latest)

**A macOS menu bar app that monitors and records global keyboard and mouse input.**

![Menu screenshot](images/menu.png)

</div>

---

## Features

- **Global monitoring** — Counts all keystrokes and mouse clicks regardless of the active application
- **Mouse click tracking** — Left / Right / Middle buttons and extra buttons are counted separately
- **Menu bar statistics** — Today's count, total count, average keystroke interval, minimum keystroke interval (fastest burst), and the top 10 most-used keys/buttons
- **Show All** — Full ranked list of every key and mouse button with total and today's counts
- **Charts** — Four interactive views: Top 20 Keys (bar), Daily Totals (line), Key Categories (donut), Top 10 per Day (grouped bar)
- **CSV Export** — Summary and daily breakdown exported to a folder of your choice
- **Copy Data to Clipboard** — Copy `counts.json` with a customizable AI prompt prepended; paste directly into an AI assistant for analysis
- **Edit AI Prompt** — Customize the prompt via **Settings… > Edit AI Prompt…**; stored separately per language
- **Keystroke Overlay** — Real-time floating window showing recent keystrokes (⌘C / ⇧A style); fades after 3 s of inactivity
- **Milestone notifications** — Native macOS notification at every 1,000 presses per key
- **Multilingual UI** — English / 日本語 / System auto-detect
- **Instant permission recovery** — Monitoring resumes automatically when Accessibility permission is granted

---

## Quick Install

1. Download **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)**
2. Open the DMG and drag **KeyLens.app** to `/Applications`
3. Launch the app — grant **Accessibility** permission when prompted

> **Note:** The app uses an ad-hoc signature and is intended for personal use. Gatekeeper may warn on first launch — right-click the app and choose **Open** to bypass.

---

## Requirements

| Item | Requirement |
|------|-------------|
| macOS | 13 Ventura or later |
| Swift | 5.9 or later (bundled with Xcode 15) |
| Permission | Accessibility (prompted on first launch) |

---



## Security

| | Details |
|---|---|
| **Records** | Key names (e.g. `Space`, `e`) and mouse button names with press counts only |
| **Does NOT record** | Typed text, sequences, passwords, clipboard content, or cursor position |
| **Storage** | Local JSON file only — no network transmission |
| **Event access** | `.listenOnly` tap — read-only, cannot inject or modify keystrokes |

<details>
<summary>Full risk summary</summary>

| Area | Risk | Mitigation |
|------|------|------------|
| Global key monitoring | High (by nature) | `.listenOnly` + `tailAppendEventTap` — passive only |
| Data content | Low | Key name + count only; typed text cannot be reconstructed |
| Data file | Medium | Unencrypted; readable by any process running as the same user |
| Network | None | No outbound connections |
| Code signing | Medium | Ad-hoc only; Gatekeeper blocks distribution to other users |

</details>

---

## Data file

```
~/Library/Application Support/KeyLens/counts.json
```

Use **Settings… > Open Log Folder** to open the directory in Finder.

---

## Build from Source

```bash
./build.sh            # Build App Bundle only
./build.sh --run      # Build and launch immediately
./build.sh --install  # Build, install to /Applications, codesign, reset TCC, launch  ← recommended
./build.sh --dmg      # Build distributable DMG
```

> Always use `build.sh` — running `swift build` alone won't produce a working notification bundle.

<details>
<summary>What <code>--install</code> does</summary>

| Step | What it does |
|------|--------------|
| `cp -r KeyLens.app /Applications/` | Installs to `/Applications` |
| `codesign --force --deep --sign -` | Ad-hoc signature (stabilizes Accessibility permission) |
| `pkill -x KeyLens` | Stops the running process before replacing the binary |
| `tccutil reset Accessibility <bundle-id>` | Clears the stale TCC entry for the old binary hash |
| `open /Applications/KeyLens.app` | Launches the new build |

**Why TCC reset is needed:** macOS stores Accessibility permissions keyed by binary hash. Each `swift build` produces a new binary, making the old TCC entry stale. Without resetting, `AXIsProcessTrusted()` returns `false` even though the toggle appears ON in System Settings.

</details>

<details>
<summary>Logs</summary>

```bash
tail -f ~/Library/Logs/KeyLens/app.log
```

</details>

---

## Accessibility Permission

An alert is shown on first launch if the permission is missing.

1. Click **Open System Settings**
2. Go to **Privacy & Security > Accessibility**
3. Enable **KeyLens**
4. Switch back to any app — monitoring resumes instantly

**Recovery mechanism (layered):**

| Trigger | Latency |
|---------|---------|
| App becomes active (`didBecomeActiveNotification`) | ~instant |
| Permission retry timer | every 3 s |
| Health check timer | every 5 s |

---

For internal design details, see [Architecture.md](Architecture.md).
