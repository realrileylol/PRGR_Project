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

    // === BRIGHTNESS DETECTION (works on monochrome!) ===
    // Golf balls are bright white - threshold to isolate bright regions
    cv::Mat bright_mask;
    cv::threshold(gray, bright_mask, 150, 255, cv::THRESH_BINARY);

    // Clean up noise with morphological operations
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5));
    cv::morphologyEx(bright_mask, bright_mask, cv::MORPH_OPEN, kernel);   // Remove noise
    cv::morphologyEx(bright_mask, bright_mask, cv::MORPH_CLOSE, kernel);  // Fill gaps

    // === EDGE DETECTION (sharp circular edges) ===
    cv::Mat edges;
    cv::Canny(gray, edges, 50, 150);

    // Combine bright regions + edges for robust detection
    cv::Mat combined;
    cv::bitwise_or(bright_mask, edges, combined);

    // Blur for smoother circle detection
    cv::Mat blurred;
    cv::GaussianBlur(combined, blurred, cv::Size(5, 5), 2);

    // === HOUGH CIRCLE DETECTION ===
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        blurred,
        circles,
        cv::HOUGH_GRADIENT,
        1,          // dp
        80,         // minDist (reduced for better detection)
        30,         // param1 (lower = more sensitive)
        20,         // param2 (lower = more sensitive)
        15,         // minRadius (smaller for distant balls)
        200         // maxRadius (larger for close balls)
    );

    // === VALIDATE AND SCORE CIRCLES ===
    if (!circles.empty()) {
        int best_x = -1, best_y = -1, best_r = -1;
        double best_score = 0.0;

        for (const auto& circle : circles) {
            int x = cvRound(circle[0]);
            int y = cvRound(circle[1]);
            int r = cvRound(circle[2]);

            // Check bounds
            if (x - r < 0 || x + r >= gray.cols) continue;
            if (y - r < 0 || y + r >= gray.rows) continue;

            // Extract ball region for validation
            int y1 = std::max(0, y - r);
            int y2 = std::min(gray.rows, y + r);
            int x1 = std::max(0, x - r);
            int x2 = std::min(gray.cols, x + r);

            cv::Mat region = gray(cv::Range(y1, y2), cv::Range(x1, x2));

            if (region.empty()) continue;

            // VALIDATION: Golf balls are bright AND uniform
            cv::Scalar mean, stddev;
            cv::meanStdDev(region, mean, stddev);
            double mean_brightness = mean[0];
            double std_dev = stddev[0];

            // Must be bright (>130) to be a golf ball
            if (mean_brightness > 130) {
                // Score based on brightness and uniformity
                // Low std dev = uniform texture = more likely a ball
                double uniformity_score = 1.0 - std::min(std_dev / 100.0, 0.5);
                double score = mean_brightness * uniformity_score;

                if (score > best_score) {
                    best_score = score;
                    best_x = x;
                    best_y = y;
                    best_r = r;
                }
            }
        }

        if (best_x >= 0) {
            // Found valid ball! Return (x, y, radius) as tuple
            return py::make_tuple(best_x, best_y, best_r);
        }
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
