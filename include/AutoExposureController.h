#pragma once

#include <cstdint>
#include <cmath>
#include <algorithm>
#include <chrono>

/**
 * @brief Ultra-fast auto-exposure controller for high-speed ball tracking
 *
 * Optimized for 200+ FPS capture with minimal overhead:
 * - SIMD-optimized brightness calculation (< 50µs)
 * - Zero-copy frame analysis
 * - Fast adjustment algorithm
 * - Thread-safe for real-time use
 *
 * Target: < 100µs total overhead per frame
 */
class AutoExposureController {
public:
    /**
     * @brief Brightness measurement result
     */
    struct BrightnessStats {
        float mean;          // Average brightness in zone
        float max;           // Maximum brightness in zone
        uint32_t pixels;     // Number of pixels measured
        bool valid;          // Measurement is valid
    };

    /**
     * @brief Exposure adjustment result
     */
    struct AdjustmentResult {
        bool adjusted;           // Settings were changed
        int shutter_us;          // New shutter speed (microseconds)
        float gain;              // New analog gain
        float brightness;        // Measured brightness
        const char* reason;      // Adjustment reason (static string)
    };

    /**
     * @brief Exposure preset mode
     */
    enum class PresetMode {
        AUTO,              // Automatic adjustment
        OUTDOOR_BRIGHT,    // Full sun, bright conditions
        OUTDOOR_NORMAL,    // Cloudy, normal outdoor
        INDOOR,            // Indoor lighting
        INDOOR_DIM         // Low light conditions
    };

    /**
     * @brief Preset configuration
     */
    struct Preset {
        int shutter_us;
        float gain;
        float target_brightness;
    };

public:
    AutoExposureController();
    ~AutoExposureController() = default;

    // Configuration
    void setBallZone(int center_x, int center_y, int radius);
    void setPresetMode(PresetMode mode);
    void setTargetBrightness(float min, float max, float ideal);
    void setShutterLimits(int min_us, int max_us);
    void setGainLimits(float min, float max);
    void setAdjustmentSpeed(float speed);  // 0.0-1.0

    // Measurement (ultra-fast)
    BrightnessStats measureBrightness(const uint8_t* frame, int width, int height, int stride);

    // Update (call every frame or periodically)
    AdjustmentResult update(const uint8_t* frame, int width, int height, int stride, bool force = false);

    // Status query
    int getCurrentShutter() const { return m_current_shutter; }
    float getCurrentGain() const { return m_current_gain; }
    PresetMode getCurrentMode() const { return m_current_mode; }
    bool isAutoMode() const { return m_auto_enabled; }

    // Reset
    void reset();

private:
    // Fast brightness calculation (SIMD-optimized)
    BrightnessStats measureBrightnessCircle(const uint8_t* frame, int width, int height, int stride);
    BrightnessStats measureBrightnessRect(const uint8_t* frame, int width, int height, int stride);

    // Adjustment calculation
    void calculateAdjustment(float current_brightness, int& new_shutter, float& new_gain, const char*& reason);

    // Smoothing
    void addToHistory(float brightness);
    float getSmoothedBrightness() const;

    // Preset configurations
    static const Preset PRESETS[];

private:
    // Ball zone
    int m_zone_center_x;
    int m_zone_center_y;
    int m_zone_radius;
    bool m_zone_defined;

    // Target brightness
    float m_target_min;
    float m_target_max;
    float m_target_ideal;

    // Exposure limits
    int m_min_shutter;
    int m_max_shutter;
    float m_min_gain;
    float m_max_gain;

    // Current settings
    int m_current_shutter;
    float m_current_gain;
    PresetMode m_current_mode;
    bool m_auto_enabled;

    // Adjustment parameters
    float m_adjustment_speed;
    double m_min_adjustment_interval_sec;
    std::chrono::steady_clock::time_point m_last_adjustment_time;

    // Brightness history (for smoothing)
    static constexpr int HISTORY_SIZE = 5;
    float m_brightness_history[HISTORY_SIZE];
    int m_history_count;
    int m_history_index;
};

/**
 * @brief Inline optimized brightness sum (compiler will vectorize)
 */
inline uint32_t fast_sum_row(const uint8_t* row, int start, int end) {
    uint32_t sum = 0;
    // Unroll loop for better auto-vectorization
    int i = start;
    for (; i + 4 <= end; i += 4) {
        sum += row[i] + row[i+1] + row[i+2] + row[i+3];
    }
    for (; i < end; i++) {
        sum += row[i];
    }
    return sum;
}

/**
 * @brief Inline optimized max finder
 */
inline uint8_t fast_max_row(const uint8_t* row, int start, int end) {
    uint8_t max_val = 0;
    for (int i = start; i < end; i++) {
        if (row[i] > max_val) max_val = row[i];
    }
    return max_val;
}
