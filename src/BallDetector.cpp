#include "BallDetector.h"
#include "CameraCalibration.h"
#include <QDebug>
#include <cmath>
#include <algorithm>

BallDetector::BallDetector(QObject *parent)
    : QObject(parent)
{
    // Initialize background subtractor (MOG2 is good for varying conditions)
    m_backgroundSubtractor = cv::createBackgroundSubtractorMOG2(500, 16, true);
}

BallDetector::~BallDetector() = default;

void BallDetector::setCalibration(CameraCalibration *calibration) {
    m_calibration = calibration;
    emit calibrationChanged();
}

// ============================================================================
// PARAMETER SETTERS
// ============================================================================

void BallDetector::setMinBallRadius(int radius) {
    if (m_minBallRadius != radius) {
        m_minBallRadius = radius;
        emit parametersChanged();
    }
}

void BallDetector::setMaxBallRadius(int radius) {
    if (m_maxBallRadius != radius) {
        m_maxBallRadius = radius;
        emit parametersChanged();
    }
}

void BallDetector::setCircularityThreshold(double threshold) {
    if (m_circularityThreshold != threshold) {
        m_circularityThreshold = threshold;
        emit parametersChanged();
    }
}

void BallDetector::setBackgroundSubtractionEnabled(bool enabled) {
    m_backgroundSubtractionEnabled = enabled;
}

void BallDetector::setDetectionMethod(const QString &method) {
    if (m_detectionMethod != method) {
        m_detectionMethod = method;
        emit detectionMethodChanged();
    }
}

// ============================================================================
// BACKGROUND MANAGEMENT
// ============================================================================

void BallDetector::captureBackground(const cv::Mat &frame) {
    if (frame.empty()) {
        qWarning() << "Cannot capture empty background";
        return;
    }

    m_background = frame.clone();

    // Reset background subtractor with new background
    m_backgroundSubtractor = cv::createBackgroundSubtractorMOG2(500, 16, true);

    // Train background subtractor with multiple copies of background
    for (int i = 0; i < 10; i++) {
        cv::Mat dummy;
        m_backgroundSubtractor->apply(m_background, dummy, 1.0);  // High learning rate
    }

    qDebug() << "Background captured for ball detection";
    emit backgroundCaptured();
}

cv::Mat BallDetector::applyBackgroundSubtraction(const cv::Mat &frame) {
    if (m_background.empty()) {
        // No background available, return original
        return frame.clone();
    }

    // Simple frame difference for fast operation
    cv::Mat diff;
    cv::absdiff(frame, m_background, diff);

    // Threshold to create binary mask
    cv::Mat mask;
    cv::threshold(diff, mask, 25, 255, cv::THRESH_BINARY);

    // Morphological operations to clean up noise
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
    cv::morphologyEx(mask, mask, cv::MORPH_OPEN, kernel);   // Remove small noise
    cv::morphologyEx(mask, mask, cv::MORPH_CLOSE, kernel);  // Fill small holes

    return mask;
}

// ============================================================================
// PREPROCESSING
// ============================================================================

cv::Mat BallDetector::preprocessFrame(const cv::Mat &frame) {
    cv::Mat processed = frame.clone();

    // Apply Gaussian blur to reduce noise
    cv::GaussianBlur(processed, processed, cv::Size(5, 5), 1.5);

    // Enhance contrast using CLAHE (Contrast Limited Adaptive Histogram Equalization)
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    clahe->apply(processed, processed);

    return processed;
}

// ============================================================================
// DETECTION METHODS
// ============================================================================

BallDetector::BallDetection BallDetector::detectBall(const cv::Mat &frame, int64_t timestamp) {
    if (frame.empty()) {
        return BallDetection();
    }

    // Choose detection method
    if (m_detectionMethod == "hough") {
        return detectWithHoughCircles(frame);
    } else if (m_detectionMethod == "blob") {
        return detectWithBlobDetector(frame);
    } else if (m_detectionMethod == "contour") {
        return detectWithContours(frame);
    } else {
        // Auto mode - try multiple methods and pick best
        return detectAuto(frame);
    }
}

BallDetector::BallDetection BallDetector::detectBallWithBackground(const cv::Mat &frame, int64_t timestamp) {
    if (!m_backgroundSubtractionEnabled || m_background.empty()) {
        return detectBall(frame, timestamp);
    }

    // Apply background subtraction
    cv::Mat foreground = applyBackgroundSubtraction(frame);

    // Detect on foreground mask
    BallDetection detection = detectBall(foreground, timestamp);

    // If detection found, verify it's valid
    if (detection.radius > 0) {
        detection.timestamp = timestamp;
        addToHistory(detection);

        // Convert to world coordinates if calibrated
        if (m_calibration && m_calibration->isExtrinsicCalibrated()) {
            detection.worldPosition = m_calibration->pixelToWorld(detection.center, 0.021335);  // Golf ball radius
        }
    }

    return detection;
}

BallDetector::BallDetection BallDetector::detectWithHoughCircles(const cv::Mat &frame) {
    cv::Mat processed = preprocessFrame(frame);

    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(processed, circles, cv::HOUGH_GRADIENT, 1,
                     processed.rows / 16,  // Min distance between centers
                     100,  // Canny upper threshold
                     15,   // Accumulator threshold (lower = more detections)
                     m_minBallRadius, m_maxBallRadius);

    if (circles.empty()) {
        return BallDetection();
    }

    // Use first circle (highest accumulator value)
    cv::Vec3f best = circles[0];
    BallDetection detection(cv::Point2f(best[0], best[1]), best[2], 0.8f, 0);

    // Calculate confidence based on circularity
    detection.confidence = calculateConfidence(detection, frame);

    return detection;
}

BallDetector::BallDetection BallDetector::detectWithBlobDetector(const cv::Mat &frame) {
    cv::Mat processed = preprocessFrame(frame);

    // Setup blob detector parameters
    cv::SimpleBlobDetector::Params params;
    params.filterByArea = true;
    params.minArea = M_PI * m_minBallRadius * m_minBallRadius;
    params.maxArea = M_PI * m_maxBallRadius * m_maxBallRadius;

    params.filterByCircularity = true;
    params.minCircularity = m_circularityThreshold;

    params.filterByConvexity = true;
    params.minConvexity = 0.8f;

    params.filterByInertia = true;
    params.minInertiaRatio = 0.6f;

    cv::Ptr<cv::SimpleBlobDetector> detector = cv::SimpleBlobDetector::create(params);

    std::vector<cv::KeyPoint> keypoints;
    detector->detect(processed, keypoints);

    if (keypoints.empty()) {
        return BallDetection();
    }

    // Use largest blob
    auto largest = std::max_element(keypoints.begin(), keypoints.end(),
        [](const cv::KeyPoint &a, const cv::KeyPoint &b) {
            return a.size < b.size;
        });

    BallDetection detection(largest->pt, largest->size / 2.0f, 0.85f, 0);
    detection.confidence = calculateConfidence(detection, frame);

    return detection;
}

BallDetector::BallDetection BallDetector::detectWithContours(const cv::Mat &frame) {
    cv::Mat processed = preprocessFrame(frame);

    // Threshold to binary
    cv::Mat binary;
    cv::threshold(processed, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binary, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    BallDetection bestDetection;
    float bestScore = 0;

    for (const auto &contour : contours) {
        // Check area is in valid range
        double area = cv::contourArea(contour);
        double minArea = M_PI * m_minBallRadius * m_minBallRadius;
        double maxArea = M_PI * m_maxBallRadius * m_maxBallRadius;

        if (area < minArea || area > maxArea) {
            continue;
        }

        // Calculate circularity
        float circularity = calculateCircularity(contour);
        if (circularity < m_circularityThreshold) {
            continue;
        }

        // Fit minimum enclosing circle
        cv::Point2f center;
        float radius;
        cv::minEnclosingCircle(contour, center, radius);

        // Check radius is in range
        if (radius < m_minBallRadius || radius > m_maxBallRadius) {
            continue;
        }

        // Calculate score (circularity weighted)
        float score = circularity * (1.0f - std::abs(radius - (m_minBallRadius + m_maxBallRadius) / 2.0f) / m_maxBallRadius);

        if (score > bestScore) {
            bestScore = score;
            bestDetection = BallDetection(center, radius, circularity, 0);
        }
    }

    return bestDetection;
}

BallDetector::BallDetection BallDetector::detectAuto(const cv::Mat &frame) {
    // Try all methods and pick best confidence
    BallDetection hough = detectWithHoughCircles(frame);
    BallDetection blob = detectWithBlobDetector(frame);
    BallDetection contour = detectWithContours(frame);

    // Return detection with highest confidence
    if (hough.confidence >= blob.confidence && hough.confidence >= contour.confidence) {
        return hough;
    } else if (blob.confidence >= contour.confidence) {
        return blob;
    } else {
        return contour;
    }
}

// ============================================================================
// VALIDATION AND FILTERING
// ============================================================================

bool BallDetector::isValidBallCandidate(const cv::Point2f &center, float radius, const cv::Mat &frame) {
    // Check if center is within frame bounds
    if (center.x < 0 || center.x >= frame.cols || center.y < 0 || center.y >= frame.rows) {
        return false;
    }

    // Check radius is in valid range
    if (radius < m_minBallRadius || radius > m_maxBallRadius) {
        return false;
    }

    return true;
}

float BallDetector::calculateCircularity(const std::vector<cv::Point> &contour) {
    double area = cv::contourArea(contour);
    double perimeter = cv::arcLength(contour, true);

    if (perimeter < 0.01) {
        return 0.0f;
    }

    // Circularity = 4π × area / perimeter²
    // Perfect circle = 1.0
    float circularity = (4.0 * M_PI * area) / (perimeter * perimeter);
    return std::min(circularity, 1.0f);
}

float BallDetector::calculateConfidence(const BallDetection &detection, const cv::Mat &frame) {
    if (!isValidBallCandidate(detection.center, detection.radius, frame)) {
        return 0.0f;
    }

    float confidence = detection.confidence;

    // Boost confidence if detection is consistent with history
    if (!m_detectionHistory.empty()) {
        cv::Point2f predicted = predictNextPosition();
        float distance = cv::norm(detection.center - predicted);
        float maxExpectedMovement = 50.0f;  // pixels per frame @ 180 FPS

        if (distance < maxExpectedMovement) {
            float consistency = 1.0f - (distance / maxExpectedMovement);
            confidence = 0.7f * confidence + 0.3f * consistency;
        } else {
            // Far from predicted - reduce confidence
            confidence *= 0.5f;
        }
    }

    return std::min(confidence, 1.0f);
}

BallDetector::BallDetection BallDetector::filterWithHistory(const BallDetection &detection) {
    if (m_detectionHistory.empty()) {
        return detection;
    }

    // Smooth detection using weighted average with previous detections
    BallDetection filtered = detection;

    // Weight recent detections more
    float totalWeight = 1.0f;
    cv::Point2f weightedCenter = detection.center;

    int count = std::min(3, (int)m_detectionHistory.size());
    for (int i = 0; i < count; i++) {
        float weight = 1.0f / (i + 2);  // Decreasing weights: 0.5, 0.33, 0.25
        weightedCenter += m_detectionHistory[i].center * weight;
        totalWeight += weight;
    }

    filtered.center = weightedCenter / totalWeight;
    return filtered;
}

// ============================================================================
// TRACKING
// ============================================================================

bool BallDetector::trackBall(const cv::Mat &frame, int64_t timestamp) {
    BallDetection detection = m_backgroundSubtractionEnabled
        ? detectBallWithBackground(frame, timestamp)
        : detectBall(frame, timestamp);

    if (detection.radius > 0 && detection.confidence > 0.5f) {
        // Apply temporal filtering
        detection = filterWithHistory(detection);

        // Add to history
        addToHistory(detection);

        // Convert to world coordinates if calibrated
        if (m_calibration && m_calibration->isExtrinsicCalibrated()) {
            detection.worldPosition = m_calibration->pixelToWorld(detection.center, 0.021335);
        }

        emit ballDetected(detection.center, detection.radius, detection.confidence);
        return true;
    }

    return false;
}

void BallDetector::addToHistory(const BallDetection &detection) {
    m_detectionHistory.push_front(detection);

    if (m_detectionHistory.size() > MAX_HISTORY) {
        m_detectionHistory.pop_back();
    }
}

cv::Point2f BallDetector::predictNextPosition() const {
    if (m_detectionHistory.size() < 2) {
        return m_detectionHistory.empty() ? cv::Point2f(0, 0) : m_detectionHistory[0].center;
    }

    // Simple linear prediction based on last two positions
    cv::Point2f velocity = m_detectionHistory[0].center - m_detectionHistory[1].center;
    return m_detectionHistory[0].center + velocity;
}

std::vector<BallDetector::BallDetection> BallDetector::getRecentDetections(int count) const {
    std::vector<BallDetection> result;
    int n = std::min(count, (int)m_detectionHistory.size());

    for (int i = 0; i < n; i++) {
        result.push_back(m_detectionHistory[i]);
    }

    return result;
}

void BallDetector::reset() {
    m_detectionHistory.clear();
    qDebug() << "Ball detector reset";
}
