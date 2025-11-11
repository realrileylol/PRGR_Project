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
    // ULTRA-SENSITIVE: Lowered from 135 to 100 for maximum detection range
    cv::Mat bright_mask;
    cv::threshold(gray, bright_mask, 100, 255, cv::THRESH_BINARY);

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

    // === ADAPTIVE CIRCLE DETECTION (PiTrac-style) ===
    // Try multiple sensitivity levels to adapt to lighting conditions
    // ULTRA-SENSITIVE: Triple detection range for maximum ball detection
    std::vector<int> param2_values = {8, 6, 10, 5, 12, 15};  // Ultra-sensitive values
    std::vector<cv::Vec3f> all_circles;
    bool found_good_detection = false;

    for (int param2 : param2_values) {
        std::vector<cv::Vec3f> circles;
        cv::HoughCircles(
            blurred,
            circles,
            cv::HOUGH_GRADIENT,
            1,          // dp
            50,         // minDist (reduced from 70)
            18,         // param1 (reduced from 25)
            param2,     // ADAPTIVE: try different sensitivities
            5,          // minRadius (reduced from 10)
            250         // maxRadius (increased from 200)
        );

        if (!circles.empty()) {
            size_t num_circles = circles.size();
            // Ideal: 1-3 circles detected
            if (num_circles >= 1 && num_circles <= 3) {
                all_circles = circles;
                found_good_detection = true;
                break;  // Found good detection
            } else if (all_circles.empty()) {
                // Save first detection as fallback
                all_circles = circles;
            }
        }
    }

    // === CONCENTRIC CIRCLE REMOVAL (PiTrac-style) ===
    std::vector<cv::Vec3f> filtered_circles;
    if (!all_circles.empty()) {
        std::vector<std::pair<int, int>> used_centers;

        for (const auto& circle : all_circles) {
            int x = cvRound(circle[0]);
            int y = cvRound(circle[1]);
            int r = cvRound(circle[2]);

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
    }

    // === PITRAC-STYLE STRICT VALIDATION (adapted for monochrome) ===
    if (!filtered_circles.empty()) {
        int best_x = -1, best_y = -1, best_r = -1;
        double best_score = 0.0;

        for (const auto& circle : filtered_circles) {
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
            cv::Mat edge_region = edges(cv::Range(y1, y2), cv::Range(x1, x2));

            if (region.empty()) continue;

            // === 1. BRIGHTNESS VALIDATION ===
            cv::Scalar mean, stddev;
            cv::meanStdDev(region, mean, stddev);
            double mean_brightness = mean[0];
            if (mean_brightness < 85) continue;

            // === 2. CIRCULARITY VALIDATION ===
            cv::Mat thresh_region;
            cv::threshold(region, thresh_region, 85, 255, cv::THRESH_BINARY);

            std::vector<std::vector<cv::Point>> contours;
            cv::findContours(thresh_region, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

            if (contours.empty()) continue;

            // Get largest contour
            auto largest_contour = *std::max_element(contours.begin(), contours.end(),
                [](const std::vector<cv::Point>& a, const std::vector<cv::Point>& b) {
                    return cv::contourArea(a) < cv::contourArea(b);
                });

            double contour_area = cv::contourArea(largest_contour);
            double perimeter = cv::arcLength(largest_contour, true);
            if (perimeter == 0) continue;

            // Circularity = 4π × Area / Perimeter²
            double circularity = (4.0 * M_PI * contour_area) / (perimeter * perimeter);
            if (circularity < 0.75) continue;

            // === 3. ASPECT RATIO VALIDATION ===
            if (largest_contour.size() < 5) continue;

            cv::RotatedRect ellipse = cv::fitEllipse(largest_contour);
            double width = ellipse.size.width;
            double height = ellipse.size.height;
            if (width <= 0 || height <= 0) continue;

            double aspect_ratio = std::min(width, height) / std::max(width, height);
            if (aspect_ratio < 0.85) continue;

            // === 4. SOLIDITY VALIDATION ===
            std::vector<cv::Point> hull;
            cv::convexHull(largest_contour, hull);
            double hull_area = cv::contourArea(hull);
            if (hull_area <= 0) continue;

            double solidity = contour_area / hull_area;
            if (solidity < 0.90) continue;

            // === 5. UNIFORMITY VALIDATION ===
            double std_dev = stddev[0];
            double uniformity_score = 1.0 - std::min(std_dev / 100.0, 0.5);
            if (uniformity_score < 0.5) continue;

            // === 6. EDGE STRENGTH VALIDATION ===
            double edge_strength = edge_region.empty() ? 0.0 : cv::mean(edge_region)[0];
            double edge_score = std::min(edge_strength / 50.0, 1.0);
            if (edge_score < 0.1) continue;

            // === 7. SIZE PLAUSIBILITY ===
            if (r < 15 || r > 150) continue;

            // === FINAL SCORING ===
            double score = (circularity * 0.4 +
                          (mean_brightness / 255.0) * 0.3 +
                          uniformity_score * 0.2 +
                          edge_score * 0.1) * 100.0;

            if (score > best_score) {
                best_score = score;
                best_x = x;
                best_y = y;
                best_r = r;
            }
        }

        // Only return if high-quality match found
        if (best_x >= 0 && best_score > 40.0) {
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
