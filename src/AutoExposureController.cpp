#include "AutoExposureController.h"
#include <cstring>
#include <algorithm>

// Preset configurations (optimized for golf ball tracking)
const AutoExposureController::Preset AutoExposureController::PRESETS[] = {
    {800,  10.0f, 180.0f},  // AUTO (default starting point)
    {500,   2.0f, 170.0f},  // OUTDOOR_BRIGHT
    {700,   4.0f, 180.0f},  // OUTDOOR_NORMAL
    {1200, 12.0f, 190.0f},  // INDOOR
    {1500, 16.0f, 200.0f}   // INDOOR_DIM
};

AutoExposureController::AutoExposureController()
    : m_zone_center_x(0)
    , m_zone_center_y(0)
    , m_zone_radius(0)
    , m_zone_defined(false)
    , m_target_min(160.0f)
    , m_target_max(200.0f)
    , m_target_ideal(180.0f)
    , m_min_shutter(500)
    , m_max_shutter(1500)
    , m_min_gain(1.0f)
    , m_max_gain(16.0f)
    , m_current_shutter(800)
    , m_current_gain(10.0f)
    , m_current_mode(PresetMode::AUTO)
    , m_auto_enabled(true)
    , m_adjustment_speed(0.3f)
    , m_min_adjustment_interval_sec(0.1)
    , m_history_count(0)
    , m_history_index(0)
{
    // Initialize history to zero
    std::memset(m_brightness_history, 0, sizeof(m_brightness_history));
}

void AutoExposureController::setBallZone(int center_x, int center_y, int radius) {
    m_zone_center_x = center_x;
    m_zone_center_y = center_y;
    m_zone_radius = radius;
    m_zone_defined = true;
}

void AutoExposureController::setPresetMode(PresetMode mode) {
    if (mode == PresetMode::AUTO) {
        m_auto_enabled = true;
        m_current_mode = PresetMode::AUTO;
        return;
    }

    // Apply preset
    int preset_idx = static_cast<int>(mode);
    if (preset_idx >= 0 && preset_idx < 5) {
        const Preset& preset = PRESETS[preset_idx];
        m_current_shutter = preset.shutter_us;
        m_current_gain = preset.gain;
        m_target_ideal = preset.target_brightness;
        m_current_mode = mode;
        m_auto_enabled = false;
    }
}

void AutoExposureController::setTargetBrightness(float min, float max, float ideal) {
    m_target_min = min;
    m_target_max = max;
    m_target_ideal = ideal;
}

void AutoExposureController::setShutterLimits(int min_us, int max_us) {
    m_min_shutter = min_us;
    m_max_shutter = max_us;
}

void AutoExposureController::setGainLimits(float min, float max) {
    m_min_gain = min;
    m_max_gain = max;
}

void AutoExposureController::setAdjustmentSpeed(float speed) {
    m_adjustment_speed = std::max(0.0f, std::min(1.0f, speed));
}

// ============================================================================
// FAST BRIGHTNESS MEASUREMENT
// ============================================================================

AutoExposureController::BrightnessStats
AutoExposureController::measureBrightnessCircle(const uint8_t* frame, int width, int height, int stride) {
    BrightnessStats stats = {0.0f, 0.0f, 0, false};

    // Bounding box of circle
    int x1 = std::max(0, m_zone_center_x - m_zone_radius);
    int x2 = std::min(width, m_zone_center_x + m_zone_radius);
    int y1 = std::max(0, m_zone_center_y - m_zone_radius);
    int y2 = std::min(height, m_zone_center_y + m_zone_radius);

    if (x2 <= x1 || y2 <= y1) {
        return stats;
    }

    // Fast circle approximation - scan rows
    const int radius_sq = m_zone_radius * m_zone_radius;
    uint64_t sum = 0;
    uint8_t max_val = 0;
    uint32_t pixel_count = 0;

    for (int y = y1; y < y2; y++) {
        const int dy = y - m_zone_center_y;
        const int dy_sq = dy * dy;

        // Calculate horizontal extent at this y
        int dx_max = static_cast<int>(std::sqrt(std::max(0, radius_sq - dy_sq)));
        int row_x1 = std::max(x1, m_zone_center_x - dx_max);
        int row_x2 = std::min(x2, m_zone_center_x + dx_max + 1);

        if (row_x2 <= row_x1) continue;

        const uint8_t* row = frame + y * stride;

        // Fast sum and max for this row segment
        sum += fast_sum_row(row, row_x1, row_x2);
        uint8_t row_max = fast_max_row(row, row_x1, row_x2);
        if (row_max > max_val) max_val = row_max;

        pixel_count += (row_x2 - row_x1);
    }

    if (pixel_count > 0) {
        stats.mean = static_cast<float>(sum) / static_cast<float>(pixel_count);
        stats.max = static_cast<float>(max_val);
        stats.pixels = pixel_count;
        stats.valid = true;
    }

    return stats;
}

AutoExposureController::BrightnessStats
AutoExposureController::measureBrightnessRect(const uint8_t* frame, int width, int height, int stride) {
    BrightnessStats stats = {0.0f, 0.0f, 0, false};

    // Use larger rectangle around zone (1.5x radius)
    int box_size = static_cast<int>(m_zone_radius * 1.5f);
    int x1 = std::max(0, m_zone_center_x - box_size);
    int x2 = std::min(width, m_zone_center_x + box_size);
    int y1 = std::max(0, m_zone_center_y - box_size);
    int y2 = std::min(height, m_zone_center_y + box_size);

    if (x2 <= x1 || y2 <= y1) {
        return stats;
    }

    uint64_t sum = 0;
    uint8_t max_val = 0;
    uint32_t pixel_count = 0;

    // Scan rectangle (cache-friendly row-wise access)
    for (int y = y1; y < y2; y++) {
        const uint8_t* row = frame + y * stride;

        sum += fast_sum_row(row, x1, x2);
        uint8_t row_max = fast_max_row(row, x1, x2);
        if (row_max > max_val) max_val = row_max;
    }

    pixel_count = (x2 - x1) * (y2 - y1);
    if (pixel_count > 0) {
        stats.mean = static_cast<float>(sum) / static_cast<float>(pixel_count);
        stats.max = static_cast<float>(max_val);
        stats.pixels = pixel_count;
        stats.valid = true;
    }

    return stats;
}

AutoExposureController::BrightnessStats
AutoExposureController::measureBrightness(const uint8_t* frame, int width, int height, int stride) {
    if (!frame) {
        return {0.0f, 0.0f, 0, false};
    }

    // If no zone defined, measure center region
    if (!m_zone_defined) {
        m_zone_center_x = width / 2;
        m_zone_center_y = height / 2;
        m_zone_radius = std::min(width, height) / 4;
    }

    // Use rectangle measurement (faster than circle)
    return measureBrightnessRect(frame, width, height, stride);
}

// ============================================================================
// BRIGHTNESS HISTORY & SMOOTHING
// ============================================================================

void AutoExposureController::addToHistory(float brightness) {
    m_brightness_history[m_history_index] = brightness;
    m_history_index = (m_history_index + 1) % HISTORY_SIZE;
    if (m_history_count < HISTORY_SIZE) {
        m_history_count++;
    }
}

float AutoExposureController::getSmoothedBrightness() const {
    if (m_history_count == 0) {
        return 0.0f;
    }

    float sum = 0.0f;
    for (int i = 0; i < m_history_count; i++) {
        sum += m_brightness_history[i];
    }
    return sum / static_cast<float>(m_history_count);
}

// ============================================================================
// ADJUSTMENT CALCULATION
// ============================================================================

void AutoExposureController::calculateAdjustment(
    float current_brightness,
    int& new_shutter,
    float& new_gain,
    const char*& reason)
{
    // Initialize with current values
    new_shutter = m_current_shutter;
    new_gain = m_current_gain;
    reason = "within_target";

    // Check if within acceptable range
    if (current_brightness >= m_target_min && current_brightness <= m_target_max) {
        return;
    }

    // Calculate error
    const float error = m_target_ideal - current_brightness;
    const float error_percent = error / m_target_ideal;

    if (current_brightness < m_target_min) {
        // TOO DARK - increase exposure
        // Prefer gain over shutter (avoid motion blur)
        if (m_current_gain < m_max_gain) {
            // Increase gain
            const float gain_increase = std::abs(error_percent) * m_adjustment_speed * 4.0f;
            new_gain = std::min(m_max_gain, m_current_gain * (1.0f + gain_increase));
            reason = "increased_gain";
        } else if (m_current_shutter < m_max_shutter) {
            // Gain maxed, increase shutter
            const float shutter_increase = std::abs(error_percent) * m_adjustment_speed * 200.0f;
            new_shutter = std::min(m_max_shutter, m_current_shutter + static_cast<int>(shutter_increase));
            reason = "increased_shutter";
        } else {
            reason = "at_max_exposure";
        }
    } else {
        // TOO BRIGHT - decrease exposure
        if (m_current_gain > m_min_gain) {
            // Decrease gain
            const float gain_decrease = std::abs(error_percent) * m_adjustment_speed * 0.5f;
            new_gain = std::max(m_min_gain, m_current_gain * (1.0f - gain_decrease));
            reason = "decreased_gain";
        } else if (m_current_shutter > m_min_shutter) {
            // Gain already low, decrease shutter
            const float shutter_decrease = std::abs(error_percent) * m_adjustment_speed * 100.0f;
            new_shutter = std::max(m_min_shutter, m_current_shutter - static_cast<int>(shutter_decrease));
            reason = "decreased_shutter";
        } else {
            reason = "at_min_exposure";
        }
    }
}

// ============================================================================
// UPDATE (MAIN ENTRY POINT)
// ============================================================================

AutoExposureController::AdjustmentResult
AutoExposureController::update(const uint8_t* frame, int width, int height, int stride, bool force) {
    AdjustmentResult result = {
        false,
        m_current_shutter,
        m_current_gain,
        0.0f,
        "no_update"
    };

    // Check if auto mode enabled
    if (!m_auto_enabled && !force) {
        result.reason = "manual_mode";
        return result;
    }

    // Rate limiting
    auto now = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed = now - m_last_adjustment_time;

    if (!force && elapsed.count() < m_min_adjustment_interval_sec) {
        result.reason = "rate_limited";
        return result;
    }

    // Measure brightness (FAST)
    BrightnessStats stats = measureBrightness(frame, width, height, stride);
    if (!stats.valid) {
        result.reason = "invalid_measurement";
        return result;
    }

    // Add to history and get smoothed value
    addToHistory(stats.mean);
    float smoothed = getSmoothedBrightness();
    result.brightness = smoothed;

    // Calculate adjustment
    int new_shutter;
    float new_gain;
    const char* reason;
    calculateAdjustment(smoothed, new_shutter, new_gain, reason);

    // Apply if changed
    if (new_shutter != m_current_shutter || new_gain != m_current_gain) {
        m_current_shutter = new_shutter;
        m_current_gain = new_gain;
        m_last_adjustment_time = now;
        result.adjusted = true;
    }

    result.shutter_us = m_current_shutter;
    result.gain = m_current_gain;
    result.reason = reason;

    return result;
}

// ============================================================================
// RESET
// ============================================================================

void AutoExposureController::reset() {
    m_current_shutter = 800;
    m_current_gain = 10.0f;
    m_auto_enabled = true;
    m_current_mode = PresetMode::AUTO;
    m_history_count = 0;
    m_history_index = 0;
    std::memset(m_brightness_history, 0, sizeof(m_brightness_history));
}
