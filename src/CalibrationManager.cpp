#include "CalibrationManager.h"
#include <QDebug>
#include <cmath>
#include <numeric>

CalibrationManager::CalibrationManager(QObject *parent)
    : QObject(parent)
    , m_frameProvider(nullptr)
    , m_settings(nullptr)
    , m_isCalibrating(false)
    , m_pixelsPerMm(0.0)
    , m_ballRadiusPixels(0)
    , m_focalLengthMm(0.0)
    , m_ballCenterX(0)
    , m_ballCenterY(0)
    , m_status("Not calibrated")
    , m_progress(0)
    , m_currentSample(0)
{
    m_sampleTimer = new QTimer(this);
    m_sampleTimer->setInterval(SAMPLE_INTERVAL_MS);
    connect(m_sampleTimer, &QTimer::timeout, this, &CalibrationManager::captureSample);

    qDebug() << "CalibrationManager initialized - PiTrac-style multi-sample calibration";
}

void CalibrationManager::checkBallLocation() {
    qDebug() << "Checking ball location...";

    if (!m_frameProvider) {
        emit ballLocationChecked(false, 0, 0, 0);
        qWarning() << "No frame provider available";
        return;
    }

    // Get current frame
    QImage qimg = m_frameProvider->requestImage("", nullptr, QSize());
    if (qimg.isNull()) {
        emit ballLocationChecked(false, 0, 0, 0);
        qWarning() << "Failed to get frame from camera";
        return;
    }

    // Convert to cv::Mat
    cv::Mat frame(qimg.height(), qimg.width(), CV_8UC1);
    memcpy(frame.data, qimg.bits(), qimg.width() * qimg.height());

    // Detect ball
    cv::Vec3f ball = detectBall(frame);

    if (ball[2] > 0) {
        int x = cvRound(ball[0]);
        int y = cvRound(ball[1]);
        int radius = cvRound(ball[2]);
        qDebug() << "✓ Ball found at (" << x << "," << y << ") radius:" << radius << "pixels";
        emit ballLocationChecked(true, x, y, radius);
    } else {
        qDebug() << "✗ Ball not detected";
        emit ballLocationChecked(false, 0, 0, 0);
    }
}

void CalibrationManager::startAutoCalibration() {
    if (m_isCalibrating) {
        qWarning() << "Calibration already in progress";
        return;
    }

    if (!m_frameProvider) {
        m_status = "Error: No camera available";
        emit statusChanged();
        emit calibrationFailed("No frame provider available");
        return;
    }

    qDebug() << "Starting auto calibration (" << CALIBRATION_SAMPLES << "samples)...";

    m_isCalibrating = true;
    emit isCalibratingChanged();

    m_samples.clear();
    m_currentSample = 0;
    m_progress = 0;
    m_status = "Capturing sample 0/" + QString::number(CALIBRATION_SAMPLES);
    emit progressChanged();
    emit statusChanged();

    // Start capturing samples
    m_sampleTimer->start();
}

void CalibrationManager::captureSample() {
    if (!m_frameProvider) {
        m_sampleTimer->stop();
        m_isCalibrating = false;
        emit isCalibratingChanged();
        m_status = "Error: Lost camera connection";
        emit statusChanged();
        emit calibrationFailed("Frame provider unavailable");
        return;
    }

    // Get current frame
    QImage qimg = m_frameProvider->requestImage("", nullptr, QSize());
    if (qimg.isNull()) {
        qDebug() << "Warning: Failed to get frame for sample" << m_currentSample;
        return;  // Skip this sample, try again on next timer
    }

    // Convert to cv::Mat
    cv::Mat frame(qimg.height(), qimg.width(), CV_8UC1);
    memcpy(frame.data, qimg.bits(), qimg.width() * qimg.height());

    // Detect ball
    cv::Vec3f ball = detectBall(frame);

    if (ball[2] > 0) {
        m_samples.push_back(ball);
        m_currentSample++;
        m_progress = (m_currentSample * 100) / CALIBRATION_SAMPLES;
        m_status = "Captured sample " + QString::number(m_currentSample) + "/" + QString::number(CALIBRATION_SAMPLES);
        emit progressChanged();
        emit statusChanged();

        qDebug() << "Sample" << m_currentSample << ": Ball at (" << cvRound(ball[0]) << "," << cvRound(ball[1])
                 << ") radius:" << cvRound(ball[2]);

        if (m_currentSample >= CALIBRATION_SAMPLES) {
            m_sampleTimer->stop();
            finishCalibration();
        }
    } else {
        qDebug() << "Warning: Ball not detected in sample" << m_currentSample << ", retrying...";
    }
}

void CalibrationManager::finishCalibration() {
    qDebug() << "Processing calibration with" << m_samples.size() << "samples...";

    if (m_samples.size() < CALIBRATION_SAMPLES / 2) {
        m_isCalibrating = false;
        emit isCalibratingChanged();
        m_status = "Failed: Too few samples";
        emit statusChanged();
        emit calibrationFailed("Insufficient valid samples. Only got " + QString::number(m_samples.size()) +
                              " out of " + QString::number(CALIBRATION_SAMPLES));
        return;
    }

    // Validate consistency
    if (!validateCalibration(m_samples)) {
        m_isCalibrating = false;
        emit isCalibratingChanged();
        m_status = "Failed: Inconsistent samples";
        emit statusChanged();
        emit calibrationFailed("Ball detection inconsistent across samples (>10% variation). Check lighting and focus.");
        return;
    }

    // Extract radius values
    std::vector<double> radii;
    std::vector<double> xPositions;
    std::vector<double> yPositions;
    for (const auto &sample : m_samples) {
        radii.push_back(sample[2]);
        xPositions.push_back(sample[0]);
        yPositions.push_back(sample[1]);
    }

    // Calculate averages
    double avgRadius = calculateMean(radii);
    double avgX = calculateMean(xPositions);
    double avgY = calculateMean(yPositions);

    m_ballRadiusPixels = cvRound(avgRadius);
    m_ballCenterX = cvRound(avgX);
    m_ballCenterY = cvRound(avgY);

    // Calculate pixels per mm
    double diameterPixels = avgRadius * 2.0;
    m_pixelsPerMm = diameterPixels / GOLF_BALL_DIAMETER_MM;

    // Calculate focal length (using middle of distance range: 5.2 feet = 1.585m)
    double estimatedDistance = (MIN_DISTANCE_M + MAX_DISTANCE_M) / 2.0;
    int resolutionX = m_settings ? m_settings->cameraResolution().split('x')[0].toInt() : 320;
    m_focalLengthMm = calculateFocalLength(m_ballRadiusPixels, resolutionX, estimatedDistance);

    // Log results
    qDebug() << "✓ Calibration successful!";
    qDebug() << "  Ball radius:" << m_ballRadiusPixels << "pixels";
    qDebug() << "  Ball center: (" << m_ballCenterX << "," << m_ballCenterY << ")";
    qDebug() << "  Pixels per mm:" << m_pixelsPerMm;
    qDebug() << "  Focal length:" << m_focalLengthMm << "mm";
    qDebug() << "  Estimated distance:" << estimatedDistance << "m (" << (estimatedDistance * 3.28084) << "feet)";

    // Save to settings
    if (m_settings) {
        m_settings->setNumber("calibration/ballRadiusPixels", m_ballRadiusPixels);
        m_settings->setDouble("calibration/pixelsPerMm", m_pixelsPerMm);
        m_settings->setDouble("calibration/focalLengthMm", m_focalLengthMm);
        m_settings->setNumber("calibration/ballCenterX", m_ballCenterX);
        m_settings->setNumber("calibration/ballCenterY", m_ballCenterY);
        m_settings->save();
    }

    m_isCalibrating = false;
    m_progress = 100;
    m_status = "Calibrated successfully";

    emit isCalibratingChanged();
    emit pixelsPerMmChanged();
    emit ballRadiusPixelsChanged();
    emit focalLengthMmChanged();
    emit ballCenterChanged();
    emit progressChanged();
    emit statusChanged();
    emit calibrationComplete(m_pixelsPerMm, m_ballRadiusPixels, m_focalLengthMm);
}

cv::Vec3f CalibrationManager::detectBall(const cv::Mat &frame) {
    if (frame.empty()) {
        return cv::Vec3f(0, 0, 0);
    }

    cv::Mat blurred;
    cv::GaussianBlur(frame, blurred, cv::Size(9, 9), 2, 2);

    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        blurred,
        circles,
        cv::HOUGH_GRADIENT,
        1,              // dp
        frame.rows / 8, // minDist
        100,            // param1 (Canny threshold)
        30,             // param2 (accumulator threshold)
        8,              // minRadius
        50              // maxRadius
    );

    if (!circles.empty()) {
        return circles[0];  // Return most prominent circle
    }

    return cv::Vec3f(0, 0, 0);  // No ball detected
}

double CalibrationManager::calculateMean(const std::vector<double> &values) {
    if (values.empty()) return 0.0;
    return std::accumulate(values.begin(), values.end(), 0.0) / values.size();
}

double CalibrationManager::calculateStdDev(const std::vector<double> &values, double mean) {
    if (values.empty()) return 0.0;

    double variance = 0.0;
    for (double value : values) {
        variance += (value - mean) * (value - mean);
    }
    variance /= values.size();

    return std::sqrt(variance);
}

double CalibrationManager::calculateFocalLength(int radiusPixels, int resolutionX, double distanceM) {
    // PiTrac formula:
    // f = (distance × sensor_width × (2 × radius_px / resolution_x)) / (2 × ball_radius_m)

    double focalMm = (distanceM * SENSOR_WIDTH_MM * (2.0 * radiusPixels / resolutionX)) / (2.0 * GOLF_BALL_RADIUS_M);
    return focalMm;
}

bool CalibrationManager::validateCalibration(const std::vector<cv::Vec3f> &samples) {
    if (samples.size() < 3) {
        return false;  // Need at least 3 samples for statistics
    }

    // Extract radius values
    std::vector<double> radii;
    for (const auto &sample : samples) {
        radii.push_back(sample[2]);
    }

    // Calculate mean and std deviation
    double mean = calculateMean(radii);
    double stdDev = calculateStdDev(radii, mean);

    // Calculate coefficient of variation (CV) as percentage
    double cv = (stdDev / mean) * 100.0;

    qDebug() << "Validation: mean radius =" << mean << "pixels, std dev =" << stdDev << "(" << cv << "%)";

    // Pass if variation is less than 10%
    if (cv > MAX_STD_DEV_PERCENT) {
        qWarning() << "Calibration failed validation: variation" << cv << "% exceeds" << MAX_STD_DEV_PERCENT << "%";
        return false;
    }

    return true;
}

void CalibrationManager::setManualCalibration(int ballRadiusPixels) {
    if (ballRadiusPixels <= 0) {
        emit calibrationFailed("Invalid ball radius");
        return;
    }

    m_ballRadiusPixels = ballRadiusPixels;
    double diameterPixels = ballRadiusPixels * 2.0;
    m_pixelsPerMm = diameterPixels / GOLF_BALL_DIAMETER_MM;

    qDebug() << "Manual calibration set:";
    qDebug() << "  Ball radius:" << ballRadiusPixels << "pixels";
    qDebug() << "  Pixels per mm:" << m_pixelsPerMm;

    m_status = "Manually calibrated";
    emit statusChanged();
    emit pixelsPerMmChanged();
    emit ballRadiusPixelsChanged();
    emit calibrationComplete(m_pixelsPerMm, m_ballRadiusPixels, 0.0);
}

void CalibrationManager::resetCalibration() {
    m_pixelsPerMm = 0.0;
    m_ballRadiusPixels = 0;
    m_focalLengthMm = 0.0;
    m_ballCenterX = 0;
    m_ballCenterY = 0;
    m_status = "Not calibrated";
    m_progress = 0;

    emit pixelsPerMmChanged();
    emit ballRadiusPixelsChanged();
    emit focalLengthMmChanged();
    emit ballCenterChanged();
    emit statusChanged();
    emit progressChanged();

    qDebug() << "Calibration reset";
}
