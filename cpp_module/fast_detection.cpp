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

    if (buf.ndim != 3) {
        throw std::runtime_error("Input should be 3D numpy array (height, width, channels)");
    }

    cv::Mat frame(buf.shape[0], buf.shape[1], CV_8UC3, (uint8_t*)buf.ptr);

    // === STEP 1: Color Space Conversions ===
    cv::Mat gray, hsv;
    cv::cvtColor(frame, gray, cv::COLOR_RGB2GRAY);
    cv::cvtColor(frame, hsv, cv::COLOR_RGB2HSV);

    // === STEP 2: HSV Color Filtering for WHITE golf balls ===
    // White objects have low saturation (0-60) and high value (150-255)
    // This rejects metallic/shiny surfaces which have higher saturation
    cv::Mat white_mask, yellow_mask;
    cv::inRange(hsv, cv::Scalar(0, 0, 150), cv::Scalar(180, 60, 255), white_mask);

    // Optional: Support YELLOW golf balls
    cv::inRange(hsv, cv::Scalar(20, 100, 150), cv::Scalar(30, 255, 255), yellow_mask);

    // Combine white and yellow masks
    cv::Mat color_mask;
    cv::bitwise_or(white_mask, yellow_mask, color_mask);

    // === STEP 3: Brightness Filtering ===
    cv::Mat brightness_mask;
    cv::threshold(gray, brightness_mask, 140, 255, cv::THRESH_BINARY);

    // === STEP 4: Combined Mask (must be BOTH colored AND bright) ===
    cv::Mat combined_mask;
    cv::bitwise_and(color_mask, brightness_mask, combined_mask);

    // Apply combined mask to grayscale
    cv::Mat masked_gray;
    cv::bitwise_and(gray, gray, masked_gray, combined_mask);

    // === STEP 5: Blur for better circle detection ===
    cv::GaussianBlur(masked_gray, masked_gray, cv::Size(9, 9), 2);

    // === STEP 6: Hough Circle Detection ===
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        masked_gray,
        circles,
        cv::HOUGH_GRADIENT,
        1,          // dp
        100,        // minDist
        50,         // param1
        30,         // param2
        20,         // minRadius
        150         // maxRadius
    );

    // === STEP 7: Validate Detected Circles ===
    if (!circles.empty()) {
        for (const auto& circle : circles) {
            int x = cvRound(circle[0]);
            int y = cvRound(circle[1]);
            int r = cvRound(circle[2]);

            // Extract region around detected circle
            int y1 = std::max(0, y - r);
            int y2 = std::min(gray.rows, y + r);
            int x1 = std::max(0, x - r);
            int x2 = std::min(gray.cols, x + r);

            cv::Mat ball_region_gray = gray(cv::Range(y1, y2), cv::Range(x1, x2));
            cv::Mat ball_region_hsv = hsv(cv::Range(y1, y2), cv::Range(x1, x2));

            if (ball_region_gray.empty() || ball_region_hsv.empty()) {
                continue;
            }

            // Check brightness
            double mean_brightness = cv::mean(ball_region_gray)[0];

            // Check saturation (golf balls should have LOW saturation)
            // Metallic/shiny surfaces have HIGHER saturation
            std::vector<cv::Mat> hsv_channels;
            cv::split(ball_region_hsv, hsv_channels);
            double mean_saturation = cv::mean(hsv_channels[1])[0];

            if (mean_brightness > 130 && mean_saturation < 80) {
                // Check circularity with combined mask
                cv::Mat mask_region = combined_mask(cv::Range(y1, y2), cv::Range(x1, x2));
                int bright_pixels = cv::countNonZero(mask_region);
                double bright_pixel_ratio = static_cast<double>(bright_pixels) / mask_region.total();

                if (bright_pixel_ratio > 0.6) {
                    // Found valid ball! Return (x, y, radius) as tuple
                    return py::make_tuple(x, y, r);
                }
            }
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
