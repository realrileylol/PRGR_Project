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

    // === BRIGHTNESS DETECTION (works on monochrome!) ===
    // Golf balls are bright white - threshold to isolate bright regions
    // Adjusted for actual lighting conditions (diagnostics showed 100 works better than 150)
    cv::Mat bright_mask;
    cv::threshold(enhanced_gray, bright_mask, 100, 255, cv::THRESH_BINARY);

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

    // === ADAPTIVE CIRCLE DETECTION (PiTrac-style) ===
    // Try multiple param2 values to adapt to lighting conditions
    std::vector<int> param2_values = {20, 18, 22, 16, 24, 15, 26};  // Start with known good value
    std::vector<cv::Vec3f> circles;

    for (int param2 : param2_values) {
        circles.clear();
        cv::HoughCircles(
            blurred,
            circles,
            cv::HOUGH_GRADIENT,
            1,          // dp
            80,         // minDist
            30,         // param1
            param2,     // ADAPTIVE: try different sensitivities
            15,         // minRadius
            200         // maxRadius
        );

        // Stop if we found 1-4 circles (ideal range)
        if (!circles.empty() && circles.size() >= 1 && circles.size() <= 4) {
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

            // === CIRCLE SCORING (adapted for very dark camera conditions) ===
            cv::Scalar mean, stddev;
            cv::meanStdDev(region, mean, stddev);
            double mean_brightness = mean[0];
            double std_dev = stddev[0];

            // For dark camera conditions, score based on:
            // 1. Uniformity (low std deviation = consistent circular region)
            // 2. Size appropriateness
            // 3. Slight brightness preference if available

            // Uniformity is key - golf balls have consistent appearance
            double uniformity_score = 1.0 - std::min(std_dev / 100.0, 0.5);

            // Size score - prefer mid-size circles (too small = noise, too large = false detection)
            double size_score = 1.0 - std::abs(r - 25) / 100.0;  // Prefer ~25px radius

            // Brightness bonus (but not required for dark conditions)
            double brightness_score = std::min(mean_brightness / 100.0, 1.0);

            // Keep reasonable size bounds
            if (r < 15 || r > 200) continue;

            // Combined score: uniformity most important, then size, then brightness
            double score = (uniformity_score * 0.5 +
                          size_score * 0.3 +
                          brightness_score * 0.2) * 100.0;

            if (score > best_score) {
                best_score = score;
                best_x = x;
                best_y = y;
                best_r = r;
            }
        }

        // === CIRCLE REFINEMENT (PiTrac-style) ===
        // Refine best detection with 1.5× radius search region
        if (best_x >= 0) {
            int search_radius = static_cast<int>(best_r * 1.5);
            int roi_x1 = std::max(0, best_x - search_radius);
            int roi_y1 = std::max(0, best_y - search_radius);
            int roi_x2 = std::min(enhanced_gray.cols, best_x + search_radius);
            int roi_y2 = std::min(enhanced_gray.rows, best_y + search_radius);

            cv::Mat roi = enhanced_gray(cv::Range(roi_y1, roi_y2), cv::Range(roi_x1, roi_x2));

            if (!roi.empty()) {
                // Apply refined Canny for precise edge detection
                cv::Mat refined_edges, refined_blur;
                cv::Canny(roi, refined_edges, 55, 110);
                cv::GaussianBlur(refined_edges, refined_blur, cv::Size(7, 7), 2);

                // Search for circles in refined region with tighter radius bounds
                int min_r = static_cast<int>(best_r * 0.85);
                int max_r = static_cast<int>(best_r * 1.10);

                std::vector<cv::Vec3f> refined_circles;
                cv::HoughCircles(
                    refined_blur,
                    refined_circles,
                    cv::HOUGH_GRADIENT,
                    1,          // dp
                    30,         // minDist
                    30,         // param1
                    15,         // param2 (more sensitive for refinement)
                    min_r,
                    max_r
                );

                // Average multiple refined detections for better accuracy
                if (!refined_circles.empty()) {
                    int avg_x = 0, avg_y = 0, avg_r = 0;
                    int count = std::min(4, static_cast<int>(refined_circles.size()));

                    for (int i = 0; i < count; i++) {
                        avg_x += cvRound(refined_circles[i][0]);
                        avg_y += cvRound(refined_circles[i][1]);
                        avg_r += cvRound(refined_circles[i][2]);
                    }

                    // Convert back to full image coordinates
                    int final_x = roi_x1 + (avg_x / count);
                    int final_y = roi_y1 + (avg_y / count);
                    int final_r = avg_r / count;

                    return py::make_tuple(final_x, final_y, final_r);
                }
            }

            // Return original if refinement fails
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
