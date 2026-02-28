# KeyLens 理解度テスト — Level 2

このテストは、KeyLens プロジェクトの**実装の深い部分と設計判断**を理解できているかを確認するためのものです。

## 第1部：SwiftUI × AppKit 統合

**Q1. `KeystrokeOverlayController` では `NSHostingController<OverlayView>` を使って SwiftUI ビューを AppKit に埋め込んでいます。なぜ `NSHostingView` ではなく `NSHostingController` を使い、`panel.contentViewController` に設定しているのでしょうか？**

**Q2. `OverlayView` に `.fixedSize()` が2箇所付いています（`Text` と外側の `HStack`）。それぞれ何のために使われていますか？**

---

## 第2部：非同期・スレッド設計

**Q3. `startListening()` 内でキー入力を受信した後、`placePanel()` を直接呼ばずに `DispatchQueue.main.async { self?.placePanel() }` で遅らせているのはなぜですか？**

**Q4. `OverlayViewModel` の `fadeTimer` は `DispatchWorkItem` で実装されています。`Timer` や `asyncAfter` ではなく `DispatchWorkItem` を使うことで実現している「重要な機能」は何ですか？**

---

## 第3部：設定の永続化

**Q5. `OverlayConfig` は `UserDefaults` に JSON（`Data`）として保存されています。なぜ `UserDefaults.standard.set(_:forKey:)` で直接 `struct` を保存しないのでしょうか？**

**Q6. `OverlayConfig.current` は毎回 `UserDefaults` + `JSONDecoder` を呼び出すプロパティです。キャッシュせずに毎回読み直す設計にしている理由を答えてください。**

---

## 第4部：通知設計

**Q7. 今回の実装で `keystrokeInput` 通知のペイロードを `String` から `KeystrokeEvent` struct に変更しました。この変更によって「型安全性」の面でどのような改善がありましたか？**

**Q8. `OverlayViewModel` は `.overlayConfigDidChange` 通知を受信して `config` を更新します。一方 `fadeDelay` は通知を受けず `append()` 呼び出し時に毎回 `OverlayConfig.current.fadeDelay` を読んでいます。この違いはなぜ設けられているのでしょうか？**

---

## 第5部：応用・トレードオフ

**Q9. `NSPanel` に `.stationary` という `collectionBehavior` が設定されています。これがないと何が起きますか？**

**Q10. 現在の `OverlayConfig` は `static var current` で毎回 UserDefaults から読み込みます。もし将来「設定変更を即座に反映しつつ、読み取りコストも下げたい」となった場合、どのような設計変更が考えられますか？（自由記述）**

---

回答の準備ができたら教えてください。答え合わせと解説を行います！
