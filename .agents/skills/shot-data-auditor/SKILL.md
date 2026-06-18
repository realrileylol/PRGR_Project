# Shot Data Auditor

Validates shot data from the PRGR Launch Monitor for physical plausibility. Produces a shot-by-shot audit report with PASS/WARN/FAIL per metric.

## When to Use

Invoke this skill when:
- Reviewing shot data after a testing session to check for measurement errors
- Debugging suspicious readings (e.g., impossibly high spin, mismatched speed and distance)
- Validating that a new algorithm or calibration change produces physically reasonable outputs
- Comparing sensor outputs between radar and camera to find disagreements

## Validation Rules

### 1. Ball Speed

- **Valid range**: 20--220 mph
- **Typical ranges by club**:
  - Driver: 130--190 mph
  - 3-wood: 115--170 mph
  - 5-iron: 95--140 mph
  - 7-iron: 80--120 mph
  - 9-iron: 65--105 mph
  - Wedge: 50--95 mph
  - Putter: 5--20 mph (if tracked)
- **FAIL**: Ball speed outside 20--220 mph
- **WARN**: Ball speed outside the typical range for the reported club type (if club type is available)

### 2. Club Speed

- **Valid range**: 10--140 mph
- **Typical ranges by club**:
  - Driver: 80--130 mph
  - 7-iron: 65--95 mph
  - Wedge: 50--80 mph
- **FAIL**: Club speed outside 10--140 mph
- **WARN**: Club speed outside the typical range for the reported club type

### 3. Smash Factor (Ball Speed / Club Speed)

- **Valid range**: 1.0--1.6
- **Typical ranges by club**:
  - Driver: 1.45--1.50
  - Irons: 1.30--1.50 (lower lofts higher, higher lofts lower)
  - Wedges: 1.10--1.30
- **FAIL**: Smash factor outside 1.0--1.6
- **WARN**: Smash factor outside the typical range for the reported club type
- **Note**: Smash factor > 1.50 for a driver may indicate a measurement error (or an illegal ball). Flag for review.

### 4. Launch Angle

- **Valid range**: -5 to 60 degrees
- **Typical ranges by club**:
  - Driver: 8--18 degrees
  - 3-wood: 10--16 degrees
  - 5-iron: 12--20 degrees
  - 7-iron: 16--25 degrees
  - 9-iron: 24--36 degrees
  - Wedge (full swing): 28--45 degrees
  - Wedge (flop/lob): 40--60 degrees
- **FAIL**: Launch angle outside -5 to 60 degrees
- **WARN**: Launch angle outside the typical range for the reported club type

### 5. Spin Rate

- **Valid range**: 1,000--13,000 RPM
- **Typical ranges by club**:
  - Driver: 1,500--4,000 RPM
  - 3-wood: 2,500--5,000 RPM
  - 5-iron: 3,500--6,500 RPM
  - 7-iron: 5,500--8,500 RPM
  - 9-iron: 7,500--10,500 RPM
  - Wedge: 8,000--13,000 RPM
- **FAIL**: Spin rate outside 1,000--13,000 RPM
- **WARN**: Spin rate outside the typical range for the reported club type
- **Cross-check**: High ball speed + high spin is unusual (driver at 170 mph with 8,000 RPM spin is suspicious). Flag when `ball_speed > 140 mph AND spin > 5000 RPM`.

### 6. Carry Distance

Validate carry distance against ball speed and launch angle using reference lookup tables. These are approximate TrackMan-derived values for sea-level, no-wind conditions:

| Ball Speed (mph) | Launch Angle | Expected Carry (yards) | Tolerance |
|-------------------|-------------|----------------------|-----------|
| 80                | 20          | 85--95               | +/- 15    |
| 100               | 18          | 125--140             | +/- 20    |
| 120               | 16          | 165--185             | +/- 25    |
| 140               | 14          | 200--225             | +/- 30    |
| 160               | 12          | 235--265             | +/- 30    |
| 180               | 11          | 265--295             | +/- 35    |

- **FAIL**: Measured carry deviates from expected by more than 2x the tolerance.
- **WARN**: Measured carry deviates from expected by more than 1x the tolerance.
- **Note**: Carry distance is highly sensitive to spin rate and environmental conditions. WARN findings here are informational, not necessarily errors.

### 7. Confidence Scores

- **FAIL**: Any measurement with confidence score < 0.3
- **WARN**: Any measurement with confidence score < 0.5
- **Report**: List which specific measurements have low confidence (ball speed confidence, spin confidence, etc.)

### 8. Sensor Agreement (Radar vs Camera)

When both radar and camera provide measurements for the same parameter:

- **Ball speed**: Compare radar-derived speed with camera-derived speed.
- **FAIL**: Disagreement > 20%
- **WARN**: Disagreement > 10%
- **Formula**: `disagreement = abs(radar - camera) / max(radar, camera) * 100`

When sensors disagree:
- If radar confidence > camera confidence, note radar as likely more accurate for speed.
- If camera confidence > radar confidence, note camera as likely more accurate for trajectory.
- Flag for investigation regardless -- sensor disagreement often indicates a calibration issue.

## Procedure

1. Load the shot data (from file, database, or in-memory structure).
2. For each shot, evaluate every applicable rule above.
3. Classify each metric as PASS, WARN, or FAIL.
4. Produce the per-shot and summary reports.

## Output Format

### Per-Shot Report

```
## Shot #<N> Audit

Club: <club type or "unknown">
Timestamp: <timestamp>

| Metric           | Value       | Range Check | Cross-Check | Confidence | Result |
|------------------|-------------|-------------|-------------|------------|--------|
| Ball Speed       | 152 mph     | PASS        | PASS        | 0.92       | PASS   |
| Club Speed       | 105 mph     | PASS        | --          | 0.88       | PASS   |
| Smash Factor     | 1.45        | PASS        | PASS        | --         | PASS   |
| Launch Angle     | 11.2 deg    | PASS        | PASS        | 0.85       | PASS   |
| Spin Rate        | 2,800 RPM   | PASS        | PASS        | 0.71       | PASS   |
| Carry Distance   | 248 yds     | PASS        | PASS        | 0.78       | PASS   |
| Sensor Agreement | 2.1%        | --          | --          | --         | PASS   |

**Shot Verdict: PASS**
```

### Summary Report

```
## Session Audit Summary

Date: <date>
Total Shots: <N>
Passed: <N> | Warned: <N> | Failed: <N>

### Failed Shots
- Shot #3: Ball speed 245 mph (FAIL: exceeds 220 mph max)
- Shot #7: Sensor disagreement 24% (FAIL: exceeds 20% threshold)

### Warned Shots
- Shot #5: Spin rate 4,200 RPM with driver (WARN: typical driver spin 1,500--4,000)
- Shot #12: Carry distance 195 yds, expected 220--250 yds for 145 mph at 13 deg (WARN)

### Metrics Distribution
- Ball Speed: min=68, max=172, mean=134, stddev=22 mph
- Spin Rate: min=1,800, max=9,200, mean=4,100, stddev=1,800 RPM
- Smash Factor: min=1.22, max=1.49, mean=1.41

### Recommendations
- <any systemic issues observed, e.g., "All wedge shots show spin below typical range -- check spin detection algorithm calibration">
- <sensor-specific notes, e.g., "Camera confidence consistently below 0.6 -- check Camera 0 focus and lighting">
```
