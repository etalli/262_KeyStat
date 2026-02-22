# KeyCounter

macOS メニューバー常駐型のキーボード入力カウンター。
キーごとの入力回数を記録し、1000 回の倍数に達するたびに通知します。

---

## 機能

- **グローバル監視**: アプリを問わず全キー入力をカウント
- **メニューバー表示**: ⌨️ アイコンをクリックで上位 10 キーの統計を表示
- **永続化**: JSON ファイルにカウントを保存（再起動後も継続）
- **マイルストーン通知**: 各キーが 1000, 2000, 3000... 回に達すると macOS 通知

---

## 必要環境

| 項目 | 要件 |
|------|------|
| macOS | 13 Ventura 以上 |
| Swift | 5.9 以上（Xcode 15 同梱） |
| 権限 | アクセシビリティ（初回起動時に要求） |

---

## ビルド方法

```bash
# 1. リポジトリのルートで実行
./build.sh

# 2. 起動
open KeyCounter.app

# ビルドと同時に起動する場合
./build.sh --run
```

`swift build` 単体でも実行ファイルは生成されますが、通知機能には App Bundle が必要なため `build.sh` の使用を推奨します。

### ビルドスクリプトの動作

```
swift build -c release
  └─ .build/release/KeyCounter（実行ファイル）

KeyCounter.app/
  ├── Contents/MacOS/KeyCounter   ← 実行ファイルをコピー
  └── Contents/Info.plist         ← LSUIElement=true でDock非表示
```

---

## 初回起動時の権限設定

初回起動時にダイアログが表示されます。

1. 「**システム設定を開く**」をクリック
2. **プライバシーとセキュリティ → アクセシビリティ**
3. `KeyCounter` をオンにする
4. 自動的に監視が開始されます（3 秒以内）

> アクセシビリティ権限なしではキー入力を取得できません。

---

## データ保存先

```
~/Library/Application Support/KeyCounter/counts.json
```

```json
{
  "Space": 15234,
  "Return": 8901,
  "e": 7432,
  "a": 6100,
  ...
}
```

メニューの「**保存先を開く**」で Finder から直接アクセスできます。

---

## ファイル構成

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
    └── NotificationManager.swift
```

---

## アーキテクチャ / ロジック解説

### データフロー

```
キー入力
  │
  ▼
CGEventTap（OS レベルのイベントフック）
  │  KeyboardMonitor.swift
  │  keyTapCallback() ← @convention(c) グローバル関数
  │
  ▼
KeyCountStore.shared.increment(key:)
  │  DispatchQueue(serial) で排他制御
  │  → counts[key] += 1
  │  → queue.async { save() }   非同期でJSONに書き出し
  │
  ├─ milestone(1000の倍数)？
  │    └─ YES → DispatchQueue.main.async { NotificationManager.notify() }
  │
  ▼
（メニュー開時）
NSMenuDelegate.menuWillOpen
  └─ KeyCountStore.topKeys() で上位10件を取得して再描画
```

---

### 各ファイルの責務

#### [main.swift](Sources/KeyCounter/main.swift)
エントリポイント。`NSApplication` を `.accessory` ポリシーで起動（Dock 非表示）。

```swift
app.setActivationPolicy(.accessory)  // メニューバーのみ、Dockなし
```

---

#### [KeyboardMonitor.swift](Sources/KeyCounter/KeyboardMonitor.swift)
`CGEventTap` でシステム全体のキーダウンイベントを傍受する。

**重要な設計判断 — `@convention(c)` 問題:**
`CGEventTapCallBack` は C 関数ポインタ型（`@convention(c)`）のため、
Swift のクロージャを渡すには変数キャプチャが禁止される。
そのため、コールバックをファイルスコープの**グローバル関数**として定義し、
シングルトン（`KeyCountStore.shared` など）経由でアクセスする方式を採用。

```
CGEvent.tapCreate(callback: keyTapCallback)
                            ↑
                  グローバル関数（キャプチャなし）
                  → @convention(c) に暗黙変換可能
```

キーコードから名前への変換は `keyName(for:)` の静的テーブルで行う（macOS US 配列基準）。

---

#### [KeyCountStore.swift](Sources/KeyCounter/KeyCountStore.swift)
カウントの管理・永続化を担うシングルトン。

**スレッド安全設計:**
`CGEventTap` コールバックはメインスレッド以外で呼ばれる可能性があるため、
シリアル `DispatchQueue` で辞書アクセスを排他制御する。

```
CGEventTap スレッド          メインスレッド
      │                           │
  queue.sync { ... }         queue.sync { topKeys() }
      │ ← 直列化 →               │
  queue.async { save() }         ...
```

JSON の書き出しは `.atomic` オプションで行い、書き込み途中のファイル破損を防ぐ。

---

#### [NotificationManager.swift](Sources/KeyCounter/NotificationManager.swift)
`UNUserNotificationCenter` でネイティブ通知を送信。
`trigger: nil` で即時配信（スケジュールなし）。
初回アクセス時に通知権限を要求する。

---

#### [AppDelegate.swift](Sources/KeyCounter/AppDelegate.swift)
メニューバー UI と権限リトライロジックを管理。

**メニュー再構築のタイミング:**
毎キーストロークでメニューを更新するのは無駄なため、
`NSMenuDelegate.menuWillOpen` — ユーザーがアイコンをクリックした瞬間のみ再構築する。

**権限リトライ:**
権限なしで起動した場合、`Timer` で 3 秒ごとに `AXIsProcessTrusted()` を確認し、
権限が付与されたら自動的に監視を開始する。

---

## メニュー表示例

```
⌨️
━━━━━━━━━━━━━━━━━━
合計: 48,291 キー入力
─────────────────
🥇 Space  —  15,234 回
🥈 Return —   8,901 回
🥉 e      —   7,432 回
   a      —   6,100 回
   s      —   5,880 回
   ...
─────────────────
保存先を開く
─────────────────
終了             ⌘Q
```
