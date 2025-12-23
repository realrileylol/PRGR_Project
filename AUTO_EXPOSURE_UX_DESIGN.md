# Auto-Exposure UX/UI Integration Design

## Overview

Design for integrating C++ auto-exposure into PRGR launch monitor UI.

**Goal:** Automatic exposure adjustment that "just works" with minimal user interaction.

---

## User Experience Flow

### Scenario 1: Outdoor Setup (Bright Sun)
```
1. User opens app outdoors
2. Auto-exposure detects bright conditions
   → Reduces shutter to 500µs, gain to 2x
3. Ball zone calibration shows properly exposed ball
4. User calibrates and starts tracking
5. If cloud passes, auto-exposure adapts automatically
```

### Scenario 2: Indoor Setup (Garage)
```
1. User opens app in garage
2. Auto-exposure detects dim conditions
   → Increases shutter to 1200µs, gain to 12x
3. Ball visible and properly exposed
4. User calibrates and tracks
5. If lights change, auto-exposure adapts
```

### Scenario 3: Moving Device (Outdoor → Indoor)
```
1. Device was outdoors (bright settings)
2. User moves to garage
3. Auto-exposure detects darkness
   → Gradually increases gain/shutter
4. Ball remains visible throughout transition
5. No manual adjustment needed
```

---

## UI Components

### 1. Exposure Status Indicator (Minimal)

**Location:** Bottom of camera preview (calibration & capture)

```
┌─────────────────────────────────────────────┐
│                                             │
│         Camera Preview                      │
│                                             │
│                                             │
└─────────────────────────────────────────────┘
 Exposure: AUTO  ●●●●●●○○○○ 178  850µs @ 8.5x
```

**Elements:**
- **Mode:** AUTO / OUTDOOR / INDOOR / DIM
- **Brightness bar:** ●●●●●● (filled = current, target = 6 dots)
- **Brightness value:** 178 (current measured)
- **Settings:** 850µs shutter, 8.5x gain

**Color coding:**
- Green: Brightness in target range (160-200)
- Yellow: Slightly out of range but adjusting
- Red: At exposure limits (can't adjust further)

### 2. Preset Mode Buttons (Optional Quick Access)

**Location:** Settings or Calibration screen

```
Exposure Mode:
┌──────┐ ┌──────────┐ ┌──────┐ ┌──────┐
│ AUTO │ │ ☀️ OUTDOOR│ │🏠 INDOOR│ │ DIM  │
└──────┘ └──────────┘ └──────┘ └──────┘
  (●)        ( )         ( )      ( )
```

**Behavior:**
- **AUTO** (default): Continuous automatic adjustment
- **OUTDOOR**: Lock to outdoor preset (500µs, 2x gain)
- **INDOOR**: Lock to indoor preset (1200µs, 12x gain)
- **DIM**: Lock to low-light preset (1500µs, 16x gain)

**When to use presets:**
- User knows lighting won't change (e.g., indoor range)
- Want consistent exposure (tournament play)
- Auto mode over-adjusting (edge case)

### 3. Real-Time Adjustment Indicator

**Show when auto-exposure makes changes:**

```
Exposure: AUTO  ●●●●●●○○○○ 182  ⚡ Adjusting...
                                ↑ Blinks briefly
```

**Feedback:**
- Small flash/icon when adjustment occurs
- Shows user the system is adapting
- Builds confidence it's working

---

## Integration Points

### A. Calibration Screen (Primary)

**Purpose:** User sets up ball zone and can verify exposure

```qml
CalibrationView.qml:

Rectangle {
    id: cameraPreview

    // Camera preview
    Image {
        source: "image://camera/preview"
    }

    // Exposure status overlay (bottom)
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 40
        color: "#AA000000"

        Row {
            spacing: 10

            Text {
                text: "Exposure: " + exposureMode
                color: "white"
            }

            // Brightness bar
            BrightnessBar {
                current: currentBrightness
                target: 180
                min: 160
                max: 200
            }

            Text {
                text: currentBrightness.toFixed(0)
                color: brightnessColor
            }

            Text {
                text: currentShutter + "µs @ " + currentGain.toFixed(1) + "x"
                color: "lightgray"
            }

            // Adjustment indicator
            Text {
                text: "⚡"
                visible: justAdjusted
                color: "yellow"
            }
        }
    }

    // Preset buttons (collapsible)
    Row {
        id: presetButtons
        anchors.top: parent.top
        spacing: 5

        Button {
            text: "AUTO"
            highlighted: exposureMode === "AUTO"
            onClicked: autoExposure.set_preset_mode("auto")
        }
        Button {
            text: "☀️ OUTDOOR"
            highlighted: exposureMode === "OUTDOOR"
            onClicked: autoExposure.set_preset_mode("outdoor_bright")
        }
        Button {
            text: "🏠 INDOOR"
            highlighted: exposureMode === "INDOOR"
            onClicked: autoExposure.set_preset_mode("indoor")
        }
    }
}
```

**C++ Backend (CalibrationManager):**

```cpp
// CalibrationManager.h
class CalibrationManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString exposureMode READ exposureMode NOTIFY exposureModeChanged)
    Q_PROPERTY(float currentBrightness READ currentBrightness NOTIFY brightnessChanged)
    Q_PROPERTY(int currentShutter READ currentShutter NOTIFY shutterChanged)
    Q_PROPERTY(float currentGain READ currentGain NOTIFY gainChanged)

private:
    AutoExposureController* m_autoExposure;

public slots:
    void updateAutoExposure(const cv::Mat& frame) {
        auto result = m_autoExposure->update(frame.data, frame.cols, frame.rows, frame.step);

        if (result.adjusted) {
            // Apply to camera
            applyExposureSettings(result.shutter_us, result.gain);

            // Notify UI
            emit shutterChanged();
            emit gainChanged();
            emit justAdjusted();  // Trigger indicator
        }

        emit brightnessChanged(result.brightness);
    }

    void setExposureMode(const QString& mode) {
        if (mode == "auto") {
            m_autoExposure->setPresetMode(AutoExposureController::PresetMode::AUTO);
        } else if (mode == "outdoor") {
            m_autoExposure->setPresetMode(AutoExposureController::PresetMode::OUTDOOR_BRIGHT);
        }
        // ... etc
        emit exposureModeChanged();
    }
};
```

### B. Capture Screen (Minimal Status)

**Purpose:** Show exposure is working during capture

```qml
CaptureView.qml:

Rectangle {
    id: statusBar

    Text {
        text: "Armed - Exposure: " + exposureMode + " (" + currentBrightness + ") " +
              currentShutter + "µs @ " + currentGain + "x"
        color: brightnessInRange ? "green" : "yellow"
    }
}
```

**Simple one-line status showing:**
- Mode (AUTO/OUTDOOR/INDOOR)
- Current brightness (is it good?)
- Current settings (for debugging)

### C. Settings Screen (Advanced Control)

**Purpose:** Advanced users can tune behavior

```qml
SettingsView.qml:

GroupBox {
    title: "Auto-Exposure"

    RadioButton {
        text: "Automatic (recommended)"
        checked: true
    }
    RadioButton {
        text: "Manual preset"
    }

    // Preset selector (when manual)
    ComboBox {
        model: ["Outdoor Bright", "Outdoor Normal", "Indoor", "Indoor Dim"]
        enabled: !autoMode
    }

    // Advanced tuning
    Slider {
        text: "Target Brightness"
        from: 140
        to: 220
        value: 180
    }

    Slider {
        text: "Adjustment Speed"
        from: 0.1
        to: 0.9
        value: 0.3
    }
}
```

---

## Visual Design Examples

### Brightness Bar Component

```qml
// BrightnessBar.qml
Rectangle {
    property real current: 150
    property real target: 180
    property real min: 160
    property real max: 200

    width: 100
    height: 20
    color: "transparent"

    // Background
    Rectangle {
        width: parent.width
        height: parent.height
        color: "#333"
        radius: 3
    }

    // Target range (green zone)
    Rectangle {
        x: (min / 255) * parent.width
        width: ((max - min) / 255) * parent.width
        height: parent.height
        color: "#4CAF50"
        opacity: 0.3
        radius: 3
    }

    // Current level (filled bars)
    Row {
        spacing: 2
        Repeater {
            model: 10
            Rectangle {
                width: 8
                height: 16
                y: 2
                color: index < (current / 25.5) ? getBarColor(current) : "#555"
                radius: 2
            }
        }
    }

    function getBarColor(brightness) {
        if (brightness >= min && brightness <= max) return "#4CAF50"  // Green
        if (brightness < min) return "#FFC107"  // Yellow (too dark)
        return "#FF5722"  // Red (too bright)
    }
}
```

### Preset Button Component

```qml
// PresetButton.qml
Button {
    property bool active: false
    property string presetName: ""

    text: presetName
    highlighted: active

    background: Rectangle {
        color: active ? "#2196F3" : "#424242"
        radius: 4
        border.color: active ? "#1976D2" : "#666"
        border.width: 2
    }

    onClicked: {
        autoExposureManager.setPreset(presetName)
    }
}
```

---

## Testing & Validation UI

### Calibration Test Mode

**Show real-time comparison to help user verify auto-exposure:**

```
┌─────────────────────────────────────────┐
│ Ball Zone Exposure Test                 │
│                                         │
│ Current: 178  [●●●●●●○○○○]  ✓ Good     │
│ Target:  180  [●●●●●●●●●●]              │
│                                         │
│ Shutter: 850µs  (-150µs from default)   │
│ Gain:    8.2x   (-1.8x from default)    │
│                                         │
│ [ Test Outdoor ] [ Test Indoor ]        │
└─────────────────────────────────────────┘
```

**Features:**
- Shows current vs target brightness
- Shows adjustment from default settings
- Test buttons to simulate different conditions
- Visual confirmation exposure is working

---

## Implementation Steps

### Phase 1: Backend Integration (C++)

1. ✅ Build fast_auto_exposure module
2. Add to CameraManager or CalibrationManager
3. Call `update()` on each frame
4. Apply adjustments to camera

### Phase 2: Basic UI (QML)

1. Add exposure properties to QML
2. Create simple status text
3. Test visibility during calibration

### Phase 3: Enhanced UI

1. Create BrightnessBar component
2. Add preset buttons
3. Add adjustment indicator
4. Polish styling

### Phase 4: Settings Integration

1. Add to Settings screen
2. Save/load preferred mode
3. Advanced tuning sliders

---

## Recommended Minimal Implementation

**For first version, just show:**

```
Calibration Screen Bottom Bar:
┌─────────────────────────────────────────┐
│ Exposure: AUTO  Brightness: 178/180 ✓   │
│ 850µs @ 8.5x                            │
└─────────────────────────────────────────┘
```

**That's it!** Simple, informative, non-intrusive.

**Add later if needed:**
- Preset buttons
- Brightness bar visualization
- Settings page controls

---

## Summary

**DO:**
- ✅ Run auto-exposure continuously (no button)
- ✅ Show minimal status in calibration
- ✅ Provide preset quick-switches
- ✅ Visual feedback when adjusting
- ✅ Color-code brightness status

**DON'T:**
- ❌ Require manual "Auto-Detect" button
- ❌ Show in all camera previews (cluttered)
- ❌ Force user to configure
- ❌ Hide when it's adjusting (show activity)

**User sees difference:**
1. Outdoor: Ball properly exposed (not blown out)
2. Indoor: Ball visible (not too dark)
3. Status bar: Shows it's working
4. During calibration: Can verify immediately
5. During capture: One less thing to worry about

The system "just works" like a modern camera's auto-exposure!
