# KeyCounter

[English](README.md) | 日本語

macOS メニューバー常駐型のキーストローク監視・記録アプリです。
キーごとの入力回数を集計し、JSON ファイルに永続化します。1,000 回押すごとに macOS 通知を送信します。

---

## 機能

- **グローバル監視**: アクティブなアプリに関係なく、すべてのキー入力をカウント
- **メニューバー統計**: キーボードアイコンをクリックすると本日のカウント・累計・Top 10 を表示
- **本日のカウント**: 日別集計、深夜0時に自動リセット
- **永続化**: 再起動後もカウントを保持（JSON ファイルに保存）
- **マイルストーン通知**: キーごとに 1,000 回ごとにネイティブ通知（1000, 2000, …）
- **多言語 UI**: English / 日本語 / システム自動検出
- **権限復帰の即時対応**: アクセシビリティ権限付与後、自動でモニタリングを再開

---

## 動作環境

| 項目 | 要件 |
|------|------|
| macOS | 13 Ventura 以降 |
| Swift | 5.9 以降（Xcode 15 付属） |
| 権限 | アクセシビリティ（初回起動時にプロンプト表示） |

---

## ビルド

```bash
# App Bundle のみ作成
./build.sh

# ビルド後にそのまま起動（プロジェクトフォルダから実行）
./build.sh --run

# ビルド → /Applications にインストール → codesign → TCC リセット → 起動  ← 推奨
./build.sh --install

# 配布用 DMG を作成（ユーザーが /Applications にドラッグ）
./build.sh --dmg
```

> `swift build` 単体でも実行ファイルは生成されますが、通知機能には App Bundle が必要です。必ず `build.sh` を使用してください。

### ビルドスクリプトの動作

```
swift build -c release
  └─ .build/release/KeyCounter   （実行ファイル）

KeyCounter.app/
  ├── Contents/MacOS/KeyCounter   <- 実行ファイルをここにコピー
  └── Contents/Info.plist         <- LSUIElement=true でDockに非表示
```

### `--install` の手順（開発時推奨）

| ステップ | 内容 |
|----------|------|
| `cp -r KeyCounter.app /Applications/` | `/Applications` にインストール |
| `codesign --force --deep --sign -` | ad-hoc 署名（アクセシビリティ権限を安定化） |
| `pkill -x KeyCounter` | 旧プロセスを停止してからバイナリを差し替え |
| `tccutil reset Accessibility <bundle-id>` | 古いバイナリハッシュの TCC エントリを削除 |
| `open /Applications/KeyCounter.app` | 新しいビルドを起動 |

**TCC リセットが必要な理由:** macOS はアクセシビリティ権限をバイナリのハッシュ単位で管理しています。`swift build` のたびに新しいバイナリ（異なるハッシュ）が生成されるため、古い TCC エントリが陳腐化します。リセットしないと、システム設定でトグルが ON になっていても `AXIsProcessTrusted()` が `false` を返し続けます。

### ログ確認

```bash
tail -f ~/Library/Logs/KeyCounter/app.log
```

---

## アクセシビリティ権限

権限がない場合、初回起動時にアラートが表示されます。

1. **「システム設定を開く」** をクリック
2. **プライバシーとセキュリティ → アクセシビリティ** に移動
3. **KeyCounter** を有効化
4. 任意のアプリに戻る — モニタリングが即座に再開

**権限復帰の仕組み（多段構成）:**

| トリガー | 復帰までの時間 |
|----------|---------------|
| アプリがアクティブになる（`didBecomeActiveNotification`） | ほぼ即時 |
| 権限リトライタイマー | 3 秒ごと |
| ヘルスチェックタイマー | 5 秒ごと |

---

## セキュリティ

### このアプリが記録すること・しないこと

| | 詳細 |
|---|---|
| **記録する** | キー名（例: `Space`, `e`）と押下回数のみ |
| **記録しない** | 入力テキスト・文字列・パスワード・クリップボードの内容 |
| **保存先** | ローカル JSON ファイルのみ — ネットワーク送信なし |
| **イベントアクセス** | `.listenOnly` タップ — 読み取り専用、キー入力の改ざん・注入は不可 |

### リスク一覧

| 項目 | リスク | 本アプリでの対策 |
|------|--------|----------------|
| グローバルキー監視 | 高（権限の性質上） | `.listenOnly` + `tailAppendEventTap` — 受動的リッスンのみ |
| データの内容 | 低 | キー名＋カウントのみ。入力文字列の再構築は不可能 |
| データファイル | 中 | 無暗号化。同一ユーザーの他プロセスが読める |
| ネットワーク | なし | 外部通信は一切なし |
| プロセス実行 | 低 | `/usr/bin/open` を固定パスでのみ実行 |
| コード署名 | 中 | ad-hoc のみ。他ユーザーへの配布は Gatekeeper がブロック |

### アクセシビリティ権限が必要な理由

macOS はグローバル `CGEventTap` のインストールにユーザーの明示的な同意（システム設定 → プライバシーとセキュリティ → アクセシビリティ）を要求します。この権限がなければ `AXIsProcessTrusted()` が `false` を返し、タップは生成されません。これは macOS が強制するゲートであり、ユーザーが許可しない限りキー入力の監視は行われません。

### 配布する場合

現在は ad-hoc 署名（`codesign --sign -`）を使用しており、個人利用では十分です。他のユーザーへ配布するには：

- **Apple Developer Program** に加入（年額 $99）
- **Developer ID Application** 証明書で署名
- **Apple 公証（Notarisation）** を申請（macOS 10.15 以降で Gatekeeper 通過に必須）

---

## データファイル

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

メニューの **設定… → 保存先を開く** でフォルダを Finder で開けます。

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
    ├── NotificationManager.swift
    └── L10n.swift
```

---

## アーキテクチャ

### データフロー

```
キー押下
  |
  v
CGEventTap  （OS レベルのイベントフック）
  |  KeyboardMonitor.swift
  |  keyTapCallback()  <-- ファイルスコープのグローバル関数（@convention(c) 互換）
  |
  v
KeyCountStore.shared.increment(key:)
  |  serial DispatchQueue でスレッド安全
  |  counts[key] += 1
  |  dailyCounts[today] += 1
  |  scheduleSave()   <- 2 秒 debounce で書き込み
  |
  +-- count % 1000 == 0?
  |     YES -> DispatchQueue.main.async { NotificationManager.notify() }
  |
  v
（メニューを開いたとき）
NSMenuDelegate.menuWillOpen
  └─ KeyCountStore.{todayCount, totalCount, topKeys()}  -> メニュー再構築
```

---

### 各ファイルの役割

#### [main.swift](Sources/KeyCounter/main.swift)

エントリポイント。`NSApplication` を `.accessory` ポリシーで起動し、Dock に表示せずメニューバーのみに常駐させます。

```swift
app.setActivationPolicy(.accessory)
```

---

#### [KeyboardMonitor.swift](Sources/KeyCounter/KeyboardMonitor.swift)

`CGEventTap` を使ってシステム全体のキーダウンイベントを傍受します。

**設計上の重要事項 — `@convention(c)` 制約:**

`CGEventTapCallBack` は C 関数ポインタ型のため、変数をキャプチャする Swift クロージャは直接使えません。そのためコールバックはファイルスコープのグローバル関数として定義し、シングルトン（`KeyCountStore.shared` など）経由でのみ状態にアクセスします。

```
CGEvent.tapCreate(callback: keyTapCallback)
                            ^
                  グローバル関数（キャプチャなし）
                  -> @convention(c) に暗黙変換可能
```

**タップ復帰:** システムタイムアウトでタップが無効化（`.tapDisabledByTimeout`）された場合、コールバック内で即座に `CGEvent.tapEnable` で再有効化します。

キーコードからキー名への変換は `keyName(for:)` の静的ルックアップテーブルで処理します（US キーボードレイアウト）。

---

#### [KeyCountStore.swift](Sources/KeyCounter/KeyCountStore.swift)

カウントを管理し、ディスクへ永続化するシングルトンです。

**スレッド安全:**

`CGEventTap` コールバックはメインスレッド外で動作します。serial `DispatchQueue` で辞書へのすべてのアクセスをシリアライズします。

```
CGEventTap スレッド           メインスレッド
      |                            |
  queue.sync { increment }    queue.sync { topKeys() }
      |  <-- シリアライズ -->       |
  scheduleSave()                   ...
      |
  queue.asyncAfter(+2 s) { save() }   <- debounce 書き込み
```

JSON は `.atomic` オプションで書き込み、ファイル破損を防ぎます。2 秒以内の連続書き込みは `DispatchWorkItem` のキャンセルで1回にまとめます。

---

#### [NotificationManager.swift](Sources/KeyCounter/NotificationManager.swift)

`UNUserNotificationCenter` でネイティブ通知を配信します。
`trigger: nil` は即時配信（スケジューリングなし）を意味します。
通知権限はシングルトンへの初回アクセス時にリクエストします。

---

#### [AppDelegate.swift](Sources/KeyCounter/AppDelegate.swift)

メニューバー UI とアクセシビリティ権限復帰を管理します。

**メニュー再構築の戦略:**
キー入力のたびにメニューを再構築するのは非効率です。代わりに `NSMenuDelegate.menuWillOpen` を使用し、ユーザーがメニューを開いたときだけ再構築します。メニューはステータス・統計・設定の3セクションに分割されています。

**権限復帰（多段構成）:**
1. `appDidBecomeActive` — ユーザーが任意のアプリに戻った瞬間に発火し、即座に `monitor.start()` を試みる
2. `schedulePermissionRetry()` — `AXIsProcessTrusted()` を 3 秒ごとにポーリング（フォールバック）
3. `setupHealthCheck()` — `monitor.isRunning` を 5 秒ごとに確認し、停止を検出したらリトライを開始

---

#### [L10n.swift](Sources/KeyCounter/L10n.swift)

ローカライズ文字列を一元管理するシングルトンです。English / 日本語 / システム自動検出をサポートし、言語設定は `UserDefaults` に永続化されます。

---

## メニュー構造

```
[キーボードアイコン]
──────────────────────────
● 監視中                  <- 緑 / 赤、停止時はクリック可能
──────────────────────────
2026年2月1日 から記録中
本日: 3,120 キー入力
合計: 48,291 キー入力
──────────────────────────
🥇 Space   —  15,234
🥈 Return  —   8,901
🥉 e       —   7,432
   a       —   6,100
   ...
──────────────────────────
KeyCounter について
設定…
  ├─ 保存先を開く
  ├─ 言語
  │   ├─ System (Auto)
  │   ├─ English
  │   └─ 日本語
  └─ リセット…
──────────────────────────
終了                    Q
```
