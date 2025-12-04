#include "TrajectoryTracker.h"
#include "CameraCalibration.h"
#include "BallDetector.h"
#include <QDebug>
#include <cmath>
#include <numeric>

TrajectoryTracker::TrajectoryTracker(QObject *parent)
    : QObject(parent)
{
    initializeKalmanFilter();
}

TrajectoryTracker::~TrajectoryTracker() = default;

void TrajectoryTracker::setCalibration(CameraCalibration *calibration) {
    m_calibration = calibration;
}

void TrajectoryTracker::setBallDetector(BallDetector *detector) {
    m_detector = detector;
}

// ============================================================================
// KALMAN FILTER INITIALIZATION
// ============================================================================

void TrajectoryTracker::initializeKalmanFilter() {
    // State: [x, y, vx, vy] - position and velocity in 2D
    // Measurement: [x, y] - observed position only
    m_kalmanFilter.init(4, 2, 0);

    // Transition matrix A
    // [1 0 dt  0]   [x  ]   [x + vx*dt]
    // [0 1  0 dt] × [y  ] = [y + vy*dt]
    // [0 0  1  0]   [vx ]   [vx       ]
    // [0 0  0  1]   [vy ]   [vy       ]
    cv::setIdentity(m_kalmanFilter.transitionMatrix);

    // Measurement matrix H (we only measure position)
    // [1 0 0 0]   [x ]   [x]
    // [0 1 0 0] × [y ] = [y]
    //             [vx]
    //             [vy]
    m_kalmanFilter.measurementMatrix = cv::Mat::zeros(2, 4, CV_32F);
    m_kalmanFilter.measurementMatrix.at<float>(0, 0) = 1.0f;
    m_kalmanFilter.measurementMatrix.at<float>(1, 1) = 1.0f;

    // Process noise covariance Q (uncertainty in model)
    cv::setIdentity(m_kalmanFilter.processNoiseCov, cv::Scalar::all(1e-2));

    // Measurement noise covariance R (uncertainty in measurements)
    cv::setIdentity(m_kalmanFilter.measurementNoiseCov, cv::Scalar::all(1e-1));

    // Error covariance P
    cv::setIdentity(m_kalmanFilter.errorCovPost, cv::Scalar::all(1.0));

    m_kalmanState = cv::Mat::zeros(4, 1, CV_32F);
    m_kalmanMeasurement = cv::Mat::zeros(2, 1, CV_32F);
}

void TrajectoryTracker::resetKalmanFilter(const cv::Point2f &initialPosition) {
    // Reset state to initial position with zero velocity
    m_kalmanState.at<float>(0) = initialPosition.x;
    m_kalmanState.at<float>(1) = initialPosition.y;
    m_kalmanState.at<float>(2) = 0.0f;  // vx
    m_kalmanState.at<float>(3) = 0.0f;  // vy

    m_kalmanFilter.statePost = m_kalmanState.clone();
    cv::setIdentity(m_kalmanFilter.errorCovPost, cv::Scalar::all(1.0));
}

// ============================================================================
// TRACKING CONTROL
// ============================================================================

void TrajectoryTracker::startTracking() {
    if (m_isTracking) {
        qWarning() << "Tracking already active";
        return;
    }

    m_isTracking = true;
    m_trackingStartTime = std::chrono::duration_cast<std::chrono::microseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
    m_trajectoryPoints.clear();
    m_consecutiveMisses = 0;
    m_launchMetricsCalculated = false;

    qDebug() << "Ball trajectory tracking started";
    emit trackingStarted();
    emit trackingStateChanged();
}

void TrajectoryTracker::stopTracking() {
    if (!m_isTracking) {
        return;
    }

    m_isTracking = false;

    // Calculate launch metrics from collected trajectory
    if (m_trajectoryPoints.size() >= 3) {
        calculateLaunchMetrics();
    }

    qDebug() << "Ball trajectory tracking stopped";
    qDebug() << "  Tracked frames:" << m_trajectoryPoints.size();
    qDebug() << "  Launch angle (V):" << m_launchAngleVertical << "°";
    qDebug() << "  Launch angle (H):" << m_launchAngleHorizontal << "°";
    qDebug() << "  Ball speed:" << ballSpeedMph() << "mph";

    emit trackingStopped(m_launchAngleVertical, m_launchAngleHorizontal, ballSpeedMph());
    emit trackingStateChanged();
}

void TrajectoryTracker::reset() {
    m_isTracking = false;
    m_trajectoryPoints.clear();
    m_consecutiveMisses = 0;
    m_launchAngleVertical = 0.0;
    m_launchAngleHorizontal = 0.0;
    m_ballSpeedMps = 0.0;
    m_launchMetricsCalculated = false;

    emit trackingStateChanged();
    emit trackingDataChanged();
}

// ============================================================================
// TRACKING UPDATE
// ============================================================================

bool TrajectoryTracker::updateTracking(const cv::Point2f &ballPosition, int64_t timestamp, double confidence) {
    if (!m_isTracking) {
        qWarning() << "Cannot update tracking - not active";
        return false;
    }

    // Update Kalman filter dt based on frame interval
    if (!m_trajectoryPoints.empty()) {
        double dt = timeDeltaSeconds(m_trajectoryPoints.back().timestamp, timestamp);
        m_kalmanFilter.transitionMatrix.at<float>(0, 2) = dt;
        m_kalmanFilter.transitionMatrix.at<float>(1, 3) = dt;
    } else {
        // First detection - initialize Kalman filter
        resetKalmanFilter(ballPosition);
    }

    // Predict next state
    predictKalman();

    // Correct with measurement
    correctKalman(ballPosition);

    // Convert to 3D world coordinates
    cv::Point3f worldPosition = imageToWorld(ballPosition, timestamp);

    // Calculate velocity from Kalman state
    cv::Point3f velocity;
    if (m_calibration && m_calibration->isExtrinsicCalibrated()) {
        // Convert pixel velocity to m/s
        float vx_px = m_kalmanState.at<float>(2);
        float vy_px = m_kalmanState.at<float>(3);

        // Convert using pixels-per-meter from calibration
        double pixelsPerMm = m_calibration->pixelsPerMm();
        double metersPerPixel = 0.001 / pixelsPerMm;

        velocity.x = vx_px * metersPerPixel;
        velocity.y = vy_px * metersPerPixel;
        velocity.z = 0.0f;  // Will be calculated from trajectory
    }

    // Store trajectory point
    TrajectoryPoint point;
    point.position = worldPosition;
    point.imagePosition = ballPosition;
    point.velocity = velocity;
    point.timestamp = timestamp;
    point.confidence = confidence;

    m_trajectoryPoints.push_back(point);

    if (m_trajectoryPoints.size() > MAX_TRAJECTORY_POINTS) {
        m_trajectoryPoints.erase(m_trajectoryPoints.begin());
    }

    // Reset consecutive misses
    m_consecutiveMisses = 0;

    emit trackingDataChanged();
    return true;
}

void TrajectoryTracker::predictKalman() {
    m_kalmanState = m_kalmanFilter.predict();
}

void TrajectoryTracker::correctKalman(const cv::Point2f &measurement) {
    m_kalmanMeasurement.at<float>(0) = measurement.x;
    m_kalmanMeasurement.at<float>(1) = measurement.y;

    m_kalmanState = m_kalmanFilter.correct(m_kalmanMeasurement);
}

cv::Point3f TrajectoryTracker::predictNextPosition() const {
    if (m_trajectoryPoints.empty()) {
        return cv::Point3f(0, 0, 0);
    }

    if (m_trajectoryPoints.size() < 2) {
        return m_trajectoryPoints.back().position;
    }

    // Use Kalman prediction
    cv::Point2f predicted(m_kalmanState.at<float>(0), m_kalmanState.at<float>(1));

    // Convert to world coordinates
    if (m_calibration && m_calibration->isExtrinsicCalibrated()) {
        return m_calibration->pixelToWorld(predicted, 0.021335);
    }

    return cv::Point3f(predicted.x, predicted.y, 0);
}

cv::Point3f TrajectoryTracker::imageToWorld(const cv::Point2f &imagePoint, int64_t timestamp) {
    if (m_calibration && m_calibration->isExtrinsicCalibrated()) {
        // Use calibration to convert pixel to world coordinates
        return m_calibration->pixelToWorld(imagePoint, 0.021335);  // Golf ball radius
    }

    // Fallback: return 2D position with z=0
    return cv::Point3f(imagePoint.x, imagePoint.y, 0.0f);
}

// ============================================================================
// LAUNCH METRICS CALCULATION
// ============================================================================

void TrajectoryTracker::calculateLaunchMetrics() {
    if (m_trajectoryPoints.size() < 3) {
        qWarning() << "Not enough trajectory points for launch calculation";
        return;
    }

    // Calculate initial velocity from first few frames
    cv::Point3f initialVelocity = calculateInitialVelocity();

    // Calculate launch angles
    auto [launchAngleV, launchAngleH] = calculateLaunchAngles(initialVelocity);
    m_launchAngleVertical = launchAngleV;
    m_launchAngleHorizontal = launchAngleH;

    // Calculate ball speed
    m_ballSpeedMps = calculateBallSpeed(initialVelocity);

    m_launchMetricsCalculated = true;

    emit launchAngleChanged();
    emit ballSpeedChanged();
}

cv::Point3f TrajectoryTracker::calculateInitialVelocity() {
    // Use first 5-10 frames for initial velocity calculation
    int nFrames = std::min(10, (int)m_trajectoryPoints.size());

    if (nFrames < 3) {
        return cv::Point3f(0, 0, 0);
    }

    // Linear regression on position vs time to get velocity
    std::vector<double> times, x_positions, y_positions;

    int64_t t0 = m_trajectoryPoints[0].timestamp;

    for (int i = 0; i < nFrames; i++) {
        double t = timeDeltaSeconds(t0, m_trajectoryPoints[i].timestamp);
        times.push_back(t);
        x_positions.push_back(m_trajectoryPoints[i].position.x);
        y_positions.push_back(m_trajectoryPoints[i].position.y);
    }

    // Calculate velocity as slope of position vs time
    double vx = 0, vy = 0;

    if (!times.empty() && times.back() > 0.001) {
        // Simple linear fit: v = Δposition / Δtime
        vx = (x_positions.back() - x_positions.front()) / times.back();
        vy = (y_positions.back() - y_positions.front()) / times.back();
    }

    return cv::Point3f(vx, vy, 0);
}

std::pair<double, double> TrajectoryTracker::calculateLaunchAngles(const cv::Point3f &velocity) {
    // Vertical launch angle (angle above horizontal)
    double horizontalSpeed = std::sqrt(velocity.x * velocity.x + velocity.y * velocity.y);
    double verticalAngle = std::atan2(velocity.z, horizontalSpeed) * 180.0 / M_PI;

    // For 2D case (z=0), estimate from parabolic trajectory
    if (std::abs(velocity.z) < 0.01 && m_trajectoryPoints.size() >= 5) {
        // Fit parabola to y-positions
        std::vector<cv::Point2f> points;
        for (size_t i = 0; i < std::min(size_t(10), m_trajectoryPoints.size()); i++) {
            points.push_back(cv::Point2f(
                m_trajectoryPoints[i].position.x,
                m_trajectoryPoints[i].position.y
            ));
        }

        // Estimate vertical component from trajectory curvature
        // For now, use typical golf launch angle of 10-15 degrees
        verticalAngle = 12.0;  // Default estimate
    }

    // Horizontal launch angle (angle from target line)
    double horizontalAngle = std::atan2(velocity.y, velocity.x) * 180.0 / M_PI;

    return {verticalAngle, horizontalAngle};
}

double TrajectoryTracker::calculateBallSpeed(const cv::Point3f &velocity) {
    // Total 3D velocity magnitude
    return std::sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z);
}

void TrajectoryTracker::fitTrajectory() {
    // Fit parabolic trajectory for better launch angle estimation
    if (m_trajectoryPoints.size() < 5) {
        return;
    }

    std::vector<cv::Point2f> points;
    for (const auto &tp : m_trajectoryPoints) {
        points.push_back(cv::Point2f(tp.position.x, tp.position.y));
    }

    ParabolicFit fit = fitParabola(points);

    // Use parabola derivative at t=0 to get initial angle
    // y = ax² + bx + c
    // dy/dx = 2ax + b
    // At x=0: dy/dx = b
    double initialSlope = fit.b;
    double verticalAngle = std::atan(initialSlope) * 180.0 / M_PI;

    if (fit.rSquared > 0.9) {  // Good fit
        m_launchAngleVertical = verticalAngle;
        emit launchAngleChanged();
    }
}

TrajectoryTracker::ParabolicFit TrajectoryTracker::fitParabola(const std::vector<cv::Point2f> &points) {
    ParabolicFit result = {0, 0, 0, 0};

    if (points.size() < 3) {
        return result;
    }

    // Least squares fit: y = ax² + bx + c
    int n = points.size();
    double sumX = 0, sumX2 = 0, sumX3 = 0, sumX4 = 0;
    double sumY = 0, sumXY = 0, sumX2Y = 0;

    for (const auto &p : points) {
        double x = p.x;
        double y = p.y;
        double x2 = x * x;
        double x3 = x2 * x;
        double x4 = x2 * x2;

        sumX += x;
        sumX2 += x2;
        sumX3 += x3;
        sumX4 += x4;
        sumY += y;
        sumXY += x * y;
        sumX2Y += x2 * y;
    }

    // Solve 3×3 system using Cramer's rule
    double denom = n * (sumX2 * sumX4 - sumX3 * sumX3) -
                   sumX * (sumX * sumX4 - sumX3 * sumX2) +
                   sumX2 * (sumX * sumX3 - sumX2 * sumX2);

    if (std::abs(denom) < 1e-10) {
        return result;
    }

    result.a = (n * (sumX2Y * sumX2 - sumXY * sumX3) -
                sumX * (sumY * sumX2 - sumXY * sumX) +
                sumX2 * (sumY * sumX3 - sumX2Y * sumX)) / denom;

    result.b = (sumY * (sumX2 * sumX4 - sumX3 * sumX3) -
                sumX * (n * sumX4 - sumX2 * sumX2) +
                sumXY * (sumX * sumX3 - sumX2 * sumX2)) / denom;

    result.c = (sumY - result.a * sumX2 - result.b * sumX) / n;

    // Calculate R²
    double meanY = sumY / n;
    double ssTotal = 0, ssRes = 0;

    for (const auto &p : points) {
        double yPred = result.a * p.x * p.x + result.b * p.x + result.c;
        ssRes += (p.y - yPred) * (p.y - yPred);
        ssTotal += (p.y - meanY) * (p.y - meanY);
    }

    result.rSquared = (ssTotal > 0) ? (1.0 - ssRes / ssTotal) : 0.0;

    return result;
}

// ============================================================================
// UTILITIES
// ============================================================================

double TrajectoryTracker::timeDeltaSeconds(int64_t t1, int64_t t2) const {
    return std::abs(t2 - t1) / 1000000.0;  // Convert microseconds to seconds
}

QString TrajectoryTracker::getTrajectorySummary() const {
    QString summary;
    summary += QString("Tracked frames: %1\n").arg(m_trajectoryPoints.size());
    summary += QString("Launch angle (V): %1°\n").arg(m_launchAngleVertical, 0, 'f', 1);
    summary += QString("Launch angle (H): %1°\n").arg(m_launchAngleHorizontal, 0, 'f', 1);
    summary += QString("Ball speed: %1 mph (%2 m/s)\n")
                   .arg(ballSpeedMph(), 0, 'f', 1)
                   .arg(m_ballSpeedMps, 0, 'f', 1);

    return summary;
}
