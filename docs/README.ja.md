# KeyLens

[English](../README.md) | 日本語

<div align="center">

![macOS](https://img.shields.io/badge/macOS-13%2B-brightgreen?style=flat-square&logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift)
[![DMG をダウンロード](https://img.shields.io/badge/⬇_ダウンロード-DMG-blue?style=flat-square)](https://github.com/etalli/262_KeyLens/releases/latest)
[![GitHub release](https://img.shields.io/github/v/release/etalli/262_KeyLens?style=flat-square&color=blue)](https://github.com/etalli/262_KeyLens/releases/latest)

**macOS メニューバー常駐型のキーストローク・マウスクリック記録、分析**

<table>
  <tr>
    <td><img src="../images/menu_v037.png" width="280"/></td>
    <td><img src="../images/Heatmap.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">メニュー</td>
    <td align="center">ヒートマップ</td>
  </tr>
</table>

</div>

---

## 機能

- **グローバル監視** — アクティブなアプリに関係なく、すべてのキー入力をカウント
- **メニューバー統計** — 本日のカウント・累計・平均入力間隔を表示
- **全件表示** — すべてのキー・マウスボタンを累計／本日別にランキング表示するウィンドウ
- **グラフ表示** — キーボードヒートマップ、Top キー、バイグラム、アプリ別、デバイス別、日別合計、エルゴノミクス学習曲線、週次デルタレポートなど
- **キーストロークオーバーレイ** — ⌘C / ⇧A 形式で最近のキー入力をリアルタイム表示するフローティングウィンドウ

---

## クイックインストール

1. **[KeyLens.dmg](https://github.com/etalli/262_KeyLens/releases/latest)** をダウンロード
2. DMG を開き、**KeyLens.app** を `/Applications` にドラッグ
3. アプリを起動 — **アクセシビリティ** 権限を求めるアラートが表示される
4. **「システム設定を開く」** をクリック → **プライバシーとセキュリティ > アクセシビリティ** → **KeyLens** を有効化
5. 任意のアプリに戻る — メニューバーにキーボードアイコンが表示され、モニタリング開始

> **注意:** アプリは ad-hoc 署名を使用しており、個人利用を想定しています。初回起動時に Gatekeeper の警告が出る場合は、アプリを右クリックして **「開く」** を選択してください。

---

## 使い方

### メニューバー

メニューバーのキーボードアイコン（⌨）をクリックしてパネルを開きます。

| 項目 | 説明 |
|------|------|
| **本日 / 累計** | 本日および全期間のキーストローク数 |
| **平均間隔** | キーストローク間の平均時間（ms） |
| **Top キー** | 最もよく押されたキーとカウント |
| **全件表示** | すべてのキー・マウスボタンのランキングテーブルを開く |
| **グラフ** | フル分析ウィンドウを開く |
| **オーバーレイ** | リアルタイムキーストロークオーバーレイの切り替え |
| **設定…** | 言語・通知・リセット・CSV 書き出し・ログフォルダを開く |

### グラフウィンドウ

メニューの **グラフ** から開きます。スクロールしてセクションを確認：

| セクション | 表示内容 |
|-----------|---------|
| **キーボードヒートマップ** | 頻度またはエルゴノミクス負荷で色分けされた物理キーレイアウト。レイアウトテンプレート（ANSI / Pangaea / Ortho）を切り替え可能 |
| **Top 20 キー** | キー種別で色分けされた横棒グラフ |
| **Top 20 バイグラム** | 最頻出の連続キーペア。同一指率・交互打鍵率サマリー |
| **日別合計** | 日ごとのキーストローク数の折れ線グラフ |
| **エルゴノミクス学習曲線** | 時系列での同一指率・交互打鍵率・高負荷率 |
| **週次デルタレポート** | 直近7日間と前7日間の比較 — キーストロークとエルゴノミクス率をトレンド矢印で表示 |
| **キー分類** | キー種別分布のドーナツグラフ |
| **キーボードショートカット** | よく使われる修飾キー＋キーの組み合わせ |
| **アプリ別** | アプリごとの打鍵数（累計・本日）とエルゴノミクススコア |
| **デバイス別** | キーボードデバイスごとの打鍵数（累計・本日）とエルゴノミクススコア |

### キーストロークオーバーレイ

<table>
  <tr>
    <td><img src="../images/keystroke_overlay_settings.png" width="280"/></td>
    <td><img src="../images/KeyStorokeOverlay-screenshot.png" width="400"/></td>
  </tr>
  <tr>
    <td align="center">設定</td>
    <td align="center">表示例</td>
  </tr>
</table>

メニューの **オーバーレイ** で切り替え。3 秒間操作がないと自動フェードアウトするフローティングウィンドウに最近のキー入力をリアルタイム表示します。歯車アイコン（⚙）から位置とサイズを設定できます。

---

## セキュリティ

| | 詳細 |
|---|---|
| **記録する** | キー名（例: `Space`, `e`）・マウスボタン名と押下回数のみ |
| **記録しない** | 入力テキスト・パスワード・クリップボードの内容・マウスカーソルの位置 |
| **保存先** | ローカル JSON ファイルのみ — ネットワーク送信なし |
| **イベントアクセス** | `.listenOnly` タップ — 読み取り専用、キー入力の改ざん・注入は不可 |

<details>
<summary>リスク一覧</summary>

| 項目 | リスク | 本アプリでの対策 |
|------|--------|----------------|
| グローバルキー監視 | 高（権限の性質上） | `.listenOnly` + `tailAppendEventTap` — 受動的リッスンのみ |
| データの内容 | 低 | キー名＋カウントのみ。入力文字列の再構築は不可能 |
| データファイル | 中 | 無暗号化。同一ユーザーの他プロセスが読める |
| ネットワーク | なし | 外部通信は一切なし |
| コード署名 | 中 | ad-hoc のみ。他ユーザーへの配布は Gatekeeper がブロック |

</details>

---

## データファイル

```
~/Library/Application Support/KeyLens/counts.json
```

**設定… > ログフォルダを開く** でフォルダを Finder で開けます。スキーマの詳細は [Architecture.md](Architecture.md) を参照。

---

## ソースからビルド

[Architecture — Build & Test](Architecture.md#build--test) を参照してください。

---

内部設計の詳細は [Architecture.md](Architecture.md) を参照してください。
開発ロードマップは [Roadmap.md](Roadmap.md) を参照してください。

フィードバック歓迎! バグ報告、機能要望、あるいは単純な質問など、何でも気軽に [Issue](https://github.com/etalli/262_KeyLens/issues) を立ててください。
