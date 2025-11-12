/**
 * Fast Ball Detection Module for Golf Launch Monitor
 * Optimized C++ implementation with pybind11 bindings
 *
 * Provides 3-5x speedup over pure Python detection
 * for real-time 100 FPS ball tracking
 */

#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include <opencv2/opencv.hpp>
#include <vector>
#include <tuple>

namespace py = pybind11;

/**
 * Detect golf ball in frame using optimized color-filtered circle detection
 *
 * Returns: tuple (x, y, radius) or None if no ball detected
 */
py::object detect_ball(py::array_t<uint8_t> frame_array) {
    // Convert numpy array to cv::Mat (zero-copy using array buffer)
    py::buffer_info buf = frame_array.request();

    // Handle both color (3D array) and grayscale (2D or 3D with 1 channel) input
    cv::Mat gray;
    if (buf.ndim == 3 && buf.shape[2] == 3) {
        // Color image (H x W x 3) - convert to grayscale
        cv::Mat frame(buf.shape[0], buf.shape[1], CV_8UC3, (uint8_t*)buf.ptr);
        cv::cvtColor(frame, gray, cv::COLOR_RGB2GRAY);
    } else if (buf.ndim == 2) {
        // Already grayscale 2D (H x W) - OV9281 monochrome camera
        gray = cv::Mat(buf.shape[0], buf.shape[1], CV_8UC1, (uint8_t*)buf.ptr);
    } else if (buf.ndim == 3 && buf.shape[2] == 1) {
        // Grayscale 3D (H x W x 1)
        gray = cv::Mat(buf.shape[0], buf.shape[1], CV_8UC1, (uint8_t*)buf.ptr);
    } else {
        throw std::runtime_error("Unexpected image format. Expected (H,W), (H,W,1), or (H,W,3)");
    }

    // === CLAHE PREPROCESSING (PiTrac-style) ===
    // Enhance contrast for better ball detection in varying lighting
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(6.0, cv::Size(6, 6));
    cv::Mat enhanced_gray;
    clahe->apply(gray, enhanced_gray);

    // === BRIGHTNESS DETECTION (ultra-sensitive for dark camera) ===
    // User's ball has brightness of only 24, so threshold must be very low
    cv::Mat bright_mask;
    cv::threshold(enhanced_gray, bright_mask, 50, 255, cv::THRESH_BINARY);

    // Clean up noise with morphological operations
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5));
    cv::morphologyEx(bright_mask, bright_mask, cv::MORPH_OPEN, kernel);   // Remove noise
    cv::morphologyEx(bright_mask, bright_mask, cv::MORPH_CLOSE, kernel);  // Fill gaps

    // === EDGE DETECTION (sharp circular edges) ===
    cv::Mat edges;
    cv::Canny(enhanced_gray, edges, 50, 150);

    // Combine bright regions + edges for robust detection
    cv::Mat combined;
    cv::bitwise_or(bright_mask, edges, combined);

    // Blur for smoother circle detection
    // MATCHED TO optimized_detection.py
    cv::Mat blurred;
    cv::GaussianBlur(combined, blurred, cv::Size(9, 9), 2);

    // === ULTRA-SENSITIVE CIRCLE DETECTION ===
    // Very low param2 values for maximum sensitivity
    std::vector<int> param2_values = {10, 8, 12, 15, 7, 6, 5};  // Much more sensitive
    std::vector<cv::Vec3f> circles;

    for (int param2 : param2_values) {
        circles.clear();
        cv::HoughCircles(
            blurred,
            circles,
            cv::HOUGH_GRADIENT,
            1,          // dp
            50,         // minDist - Reduced from 80 for easier detection
            20,         // param1 - Reduced from 30 for easier detection
            param2,     // ULTRA-SENSITIVE values
            10,         // minRadius - Reduced from 15 to catch smaller balls
            250         // maxRadius - Increased to catch larger detections
        );

        // Accept any circles found (no ideal range restriction)
        if (!circles.empty()) {
            break;
        }
    }

    // === CONCENTRIC CIRCLE REMOVAL ===
    std::vector<cv::Vec3f> filtered_circles;
    std::vector<std::pair<int, int>> used_centers;

    for (const auto& circle : circles) {
        int x = cvRound(circle[0]);
        int y = cvRound(circle[1]);

        // Check if this center is already used (within 10px tolerance)
        bool is_duplicate = false;
        for (const auto& center : used_centers) {
            if (std::abs(x - center.first) < 10 && std::abs(y - center.second) < 10) {
                is_duplicate = true;
                break;
            }
        }

        if (!is_duplicate) {
            filtered_circles.push_back(circle);
            used_centers.push_back({x, y});
        }
    }

    // === SMART FILTERING - Reject dark false detections ===
    // In ultra-dark scenes, HoughCircles detects noise patterns as circles
    // Filter to find the BRIGHT ball on the mat, not dark noise circles
    int best_x = -1, best_y = -1, best_r = -1;
    double best_score = 0.0;

    for (const auto& circle : filtered_circles) {
        int x = cvRound(circle[0]);
        int y = cvRound(circle[1]);
        int r = cvRound(circle[2]);

        // Validate bounds
        if (x - r < 0 || x + r >= gray.cols || y - r < 0 || y + r >= gray.rows) {
            continue;
        }

        // Ball size filtering - golf ball should be 20-100px radius at typical distance
        if (r < 20 || r > 100) {
            continue;
        }

        // Extract ball region for brightness validation
        int y1 = std::max(0, y - r);
        int y2 = std::min(gray.rows, y + r);
        int x1 = std::max(0, x - r);
        int x2 = std::min(gray.cols, x + r);

        cv::Mat region = gray(cv::Range(y1, y2), cv::Range(x1, x2));

        if (region.empty()) {
            continue;
        }

        // === BRIGHTNESS FILTERING ===
        // Reject circles in pitch-black areas (noise patterns)
        double region_brightness = cv::mean(region)[0];

        // CRITICAL: Ball must be bright (>40 in original gray, not CLAHE)
        if (region_brightness < 40.0) {
            continue;
        }

        // === CIRCULARITY CHECK ===
        // Ball should have high peak brightness in center (smooth surface reflects light)
        // Mat texture is grainy with uniform brightness (no bright center)
        double max_brightness;
        cv::minMaxLoc(region, nullptr, &max_brightness);
        double brightness_contrast = max_brightness - region_brightness;

        // Good ball: max=200, mean=100, contrast=100 (bright center)
        // Mat grain: max=80, mean=70, contrast=10 (uniform texture)
        // Require at least 30 contrast for ball (helps reject mat texture)
        if (brightness_contrast < 30.0) {
            continue;
        }

        // === SMART SCORING ===
        // Prioritize: peak brightness > circularity > position > size
        double score = 0.0;

        // Peak brightness score (ball has bright center from light reflection)
        score += max_brightness * 1.5;

        // Brightness contrast score (smooth ball vs grainy mat)
        score += brightness_contrast * 2.0;

        // Mean brightness score
        score += region_brightness * 1.0;

        // Position score (ball is usually in bottom 2/3 of frame on hitting mat)
        double position_score = (static_cast<double>(y) / gray.rows) * 30.0;
        score += position_score;

        // Size score (ideal ball radius is 30-60px)
        if (r >= 30 && r <= 60) {
            score += 30.0;
        }

        if (score > best_score) {
            best_score = score;
            best_x = x;
            best_y = y;
            best_r = r;
        }
    }

    // Return best circle if found
    if (best_x >= 0) {
        return py::make_tuple(best_x, best_y, best_r);
    }

    // No ball detected
    return py::none();
}

/**
 * Calculate velocity of ball from position history
 * Used to distinguish between stationary ball (before shot) vs moving object (person/hand)
 *
 * Returns: average velocity in pixels per frame
 */
double calculate_velocity(py::list position_history) {
    if (position_history.size() < 2) {
        return 0.0;
    }

    std::vector<std::pair<int, int>> positions;

    // Extract positions from Python list
    for (const auto& item : position_history) {
        if (!item.is_none()) {
            auto pos = item.cast<py::tuple>();
            int x = pos[0].cast<int>();
            int y = pos[1].cast<int>();
            positions.push_back({x, y});
        }
    }

    if (positions.size() < 2) {
        return 0.0;
    }

    // Calculate total displacement
    double total_distance = 0.0;
    for (size_t i = 1; i < positions.size(); ++i) {
        int dx = positions[i].first - positions[i-1].first;
        int dy = positions[i].second - positions[i-1].second;
        double distance = std::sqrt(dx*dx + dy*dy);
        total_distance += distance;
    }

    // Average velocity = total distance / number of frame intervals
    return total_distance / (positions.size() - 1);
}

/**
 * Fast scene brightness check
 * Used to detect if camera is covered by hand (false trigger)
 *
 * Returns: mean brightness value (0-255)
 */
double get_scene_brightness(py::array_t<uint8_t> frame_array) {
    py::buffer_info buf = frame_array.request();

    if (buf.ndim != 3) {
        throw std::runtime_error("Input should be 3D numpy array");
    }

    cv::Mat frame(buf.shape[0], buf.shape[1], CV_8UC3, (uint8_t*)buf.ptr);
    cv::Mat gray;
    cv::cvtColor(frame, gray, cv::COLOR_RGB2GRAY);

    return cv::mean(gray)[0];
}

// ============================================
// Python Module Definition
// ============================================
PYBIND11_MODULE(fast_detection, m) {
    m.doc() = "Fast C++ ball detection for golf launch monitor (3-5x speedup)";

    m.def("detect_ball", &detect_ball,
          "Detect golf ball in RGB frame. Returns (x, y, radius) or None",
          py::arg("frame"));

    m.def("calculate_velocity", &calculate_velocity,
          "Calculate velocity from position history in pixels/frame",
          py::arg("position_history"));

    m.def("get_scene_brightness", &get_scene_brightness,
          "Get mean scene brightness (0-255)",
          py::arg("frame"));
}
