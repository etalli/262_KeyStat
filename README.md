# KeyLens

English | [日本語](docs/README.ja.md)

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)
[![Download DMG](https://img.shields.io/badge/⬇_Download-DMG-blue?style=flat-square)](https://github.com/etalli/262_KeyLens/releases/latest)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)

**A macOS menu bar app that records and analyzes global keyboard and mouse input.**

<table>
  <tr>
    <td><img src="images/menu_v037.png" width="280"/></td>
    <td><img src="images/Heatmap.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">Menu</td>
    <td align="center">Heatmap</td>
  </tr>
</table>


</div>

---

## Features

- **Global monitoring** — Counts all keystrokes regardless of the active application
- **Menu bar statistics** — Today's count, total count, average keystroke interval
- **Show All** — Full ranked list of every key with total and today's counts
- **Charts** — Interactive views: Keyboard Heatmap (Frequency / Strain mode), Top Keys, Daily Totals, Ergonomic Learning Curve, Weekly Delta Report, and more
- **Keystroke Overlay** — Real-time floating window showing recent keystrokes (⌘C / ⇧A style)

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

Use **Settings… > Open Log Folder** to open the directory in Finder. See [Architecture](docs/Architecture.md) for the schema.

---

## Build from Source

See [Architecture — Build & Test](docs/Architecture.md#build--test).

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

For internal design details, see [Architecture](docs/Architecture.md).
For the development roadmap, see [Roadmap](docs/Roadmap.md).


Feedback Welcome!
Feel free to open an issue for anything — bug reports, feature requests, or just a simple question. We’d love to hear from you.
