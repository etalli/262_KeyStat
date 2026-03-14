# References

## Keyboard Layout Optimization

- Klein, A. (2021). *Engram: A Systematic Approach to Optimize Keyboard Layouts for Touch Typing, With Example for the English Language*. Preprints.org.
  https://www.preprints.org/manuscript/202103.0287
  — Systematic layout optimization using character-pair (bigram) frequency and ergonomic scoring. Basis for bigram-driven layout evaluation.
  従来のキーボード配列が歴史的事情で決まっているのに対し、人間工学 × データ解析に基づく新しいキーボード配列設計の枠組みを提示する。従来は経験則や経験者の勘に頼られがちな配列設計に対して、定量的最適化手法を導入した。

- Onsorodi, A. H. H., & Korhan, O. (2020). *Application of a Genetic Algorithm to the Keyboard Layout Problem*. PLOS ONE, 15(1), e0226611.
  https://doi.org/10.1371/journal.pone.0226611
  — Genetic algorithm approach using bigram frequency to minimize finger travel distance. Demonstrates measurable improvement over QWERTY.
  遺伝的アルゴリズムにより、文字頻度とキーボード座標の組み合わせ最適化を実装。結果、QWERTYと比較して 指の移動効率が改善された配列候補を得た。これはタイピングの疲労軽減や効率改善につながる可能性を示唆する研究

- Nivasch, K. (2023). *Keyboard Layout Optimization and Adaptation*. International Journal on Artificial Intelligence Tools, World Scientific.
  https://doi.org/10.1142/S0218213023600023
  — Surveys optimization models including ergonomic scoring approaches comparable to Carpalx.
　　深層学習支援型の探索により、従来のGAよりも効率的に高品質なキーボード配列候補を生成可能としている。
　　最適化された配列が理論上優れていても、実際のユーザーがどれだけ早く慣れるかが重要という実践的視点を加えている。
　　アルゴリズム評価だけでなく、実ユーザー実験を組み合わせている。

- Krzywinski, M. (2006–). *Carpalx: Keyboard Layout Optimizer*. bcgsc.ca.
  https://mk.bcgsc.ca/carpalx/
  — Widely referenced layout scoring algorithm. Foundational reference for same-finger penalty and finger load weighting models.
  Carpalx は、キーボード配列を定量的に評価・最適化するためのツール・モデル。タイピングの労力を数値化し、最小になる配列を見つけるシミュレーションを行う。手や指への負担を減らすことを目的としている。指の「努力コスト」をモデル化し、小指に最も高いコストを割り当てている。


## Typing Ergonomics & Repetitive Strain Injury(RSI)

- Keller, K., Corbett, J., & Nichols, D. (1998). *Repetitive Strain Injury in Computer Keyboard Users: Pathomechanics and Treatment Principles in Individual and Group Intervention*. Journal of Hand Therapy, 11(1).
  https://doi.org/10.1016/s0894-1130(98)80056-2
  — Describes RSI as a multifactorial kinetic-chain disorder. Supports the claim that same-finger repetition is a primary strain mechanism.
  コンピュータのキーボード使用に伴う反復性ストレス障害（RSI）の発症メカニズムと病態、評価法、治療・予防の原則を総合的に整理したレビューで、とくに、RSI は姿勢・筋・神経の相互作用による多因子性障害、予防には姿勢改善・適宜休憩・職場環境の最適化が重要、治療は個別ケアと職場介入を統合するべき、というポイントが強調されている。

- Kim, J. H., et al. (2014). *Differences in Typing Forces, Muscle Activity, Comfort, and Typing Performance Among Virtual, Notebook, and Desktop Keyboards*. Ergonomics.
  https://pubmed.ncbi.nlm.nih.gov/24856862/
  — Empirical measurement of finger-level muscle activation and typing force. Basis for finger load weighting by finger type.
  仮想キーボードは指の力と筋肉負担は少ないが、タイピング効率と快適さが大きく劣る。逆に 物理的なキートラベル（押し込み感）がある従来型キーボードは、長時間や生産性重視の入力作業に適している可能性が高いという結論。験的な指レベルの筋電図（EMG）計測。指ごとの打鍵力と筋活動量を実測し、小指が最も高い活性化率を示すことを確認

- (2024). *Therapeutic Approaches for the Prevention of Upper Limb Repetitive Strain Injuries in Work-Related Computer Use: A Scoping Review*. Journal of Occupational Rehabilitation, Springer Nature.
  https://doi.org/10.1007/s10926-024-10204-z
  — Comprehensive review of 58 studies on RSI prevention. Supports time-window transition analysis as a fatigue detection method.
  キーボード・マウスなどを使う人に生じる上肢の反復性ストレス障害（RSI）を予防するための治療・介入法 について、
　2000年代以降の研究成果を体系的にまとめることを目的とした網羅的な整理
