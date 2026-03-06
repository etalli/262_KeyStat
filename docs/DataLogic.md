# Ergonomic Load Calculation Logic

Within `KeyLensCore`, finger load is quantified through the following four steps:

### 1. Base Capability Values (FingerLoadWeight)

First, we define the relative "strength" or "stamina" of each finger:

- **Index finger**: 1.0 (The strongest, baseline finger)
- **Middle finger**: 0.9
- **Thumb**: 0.8
- **Ring finger**: 0.6
- **Pinky finger**: 0.5 (The weakest and most easily fatigued)

**Formula**: `Keystrokes / Capability Value`
For example, typing 100 times with your pinky (0.5) is counted as the same load as typing 200 times with your index finger (1.0). In other words, weaker fingers incur a higher load per keystroke.

### 2. Same-Finger Bigram Penalty (SameFingerPenalty)

Typing different keys consecutively with the same finger (Same-Finger Bigram) puts significant strain on the hand. This penalty increases non-linearly with "distance":

- **Same key**: 0.5x penalty (e.g., key repeat)
- **Adjacent (same row)**: 1.0x penalty (e.g., F → G)
- **1-row vertical move**: 4.0x penalty (e.g., F → R)
- **2+ rows vertical move**: 16.0x penalty (e.g., F → 4)

The logic is designed such that vertical stretching increases the load exponentially (by the square of the distance factor).

### 3. High-Strain Sequence Detection (HighStrainDetector)

Movements that are particularly likely to cause repetitive strain injury (RSI) are flagged as "High Strain":

- **Criteria**: "Same finger" and "vertical movement of 1 or more rows".
- **Example**: Typing 'R' (upper row) immediately after 'F' (home row) with the same index finger.

These sequences are specifically tracked and visualized in the "Strain" mode of the heatmap.

### 4. Integrated Scoring (ErgonomicScoreEngine)

Finally, all metrics are aggregated into a single score out of 100:

- **Deductions**: High frequency of same-finger bigrams, high-strain sequences, and thumb use imbalance (left vs. right).
- **Bonuses**: Good hand alternation and efficient thumb utilization.

**Summary**:
Rather than simply counting "which key was pressed how many times," KeyLens simulates the physical strain based on "which finger was used, how far it had to stretch, and how much it was used consecutively."

---
*If you are interested in more detailed logic, such as the handling of specific keys like Space or Cmd, please let us know.*
