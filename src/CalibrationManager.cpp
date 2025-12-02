#include "CalibrationManager.h"
#include <QDebug>

CalibrationManager::CalibrationManager(QObject *parent)
    : QObject(parent)
    , m_isCalibrating(false)
    , m_pixelsPerMm(0.0)
    , m_ballRadiusPixels(0)
{
}

void CalibrationManager::calibrateFromFrame(const cv::Mat &frame) {
    if (frame.empty()) {
        emit calibrationFailed("Empty frame");
        return;
    }

    m_isCalibrating = true;
    emit isCalibratingChanged();

    qDebug() << "Starting automatic ball calibration...";

    // Detect ball in frame
    cv::Vec3f ball = detectBallForCalibration(frame);

    if (ball[2] > 0) {
        // Successfully detected ball
        int radiusPixels = cvRound(ball[2]);
        double diameterPixels = radiusPixels * 2.0;

        // Calculate pixels per mm: pixels / mm
        m_pixelsPerMm = diameterPixels / GOLF_BALL_DIAMETER_MM;
        m_ballRadiusPixels = radiusPixels;

        qDebug() << "✓ Calibration successful:";
        qDebug() << "  Ball radius:" << radiusPixels << "pixels";
        qDebug() << "  Ball diameter:" << diameterPixels << "pixels";
        qDebug() << "  Pixels per mm:" << m_pixelsPerMm;
        qDebug() << "  Golf ball diameter:" << GOLF_BALL_DIAMETER_MM << "mm";

        emit pixelsPerMmChanged();
        emit ballRadiusPixelsChanged();
        emit calibrationComplete(m_pixelsPerMm, m_ballRadiusPixels);
    } else {
        qWarning() << "✗ Calibration failed: Could not detect ball";
        emit calibrationFailed("Could not detect ball in frame. Ensure ball is visible and well-lit.");
    }

    m_isCalibrating = false;
    emit isCalibratingChanged();
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

    emit pixelsPerMmChanged();
    emit ballRadiusPixelsChanged();
    emit calibrationComplete(m_pixelsPerMm, m_ballRadiusPixels);
}

void CalibrationManager::resetCalibration() {
    m_pixelsPerMm = 0.0;
    m_ballRadiusPixels = 0;

    emit pixelsPerMmChanged();
    emit ballRadiusPixelsChanged();

    qDebug() << "Calibration reset";
}

cv::Vec3f CalibrationManager::detectBallForCalibration(const cv::Mat &frame) {
    cv::Mat processFrame = frame.clone();

    // Apply Gaussian blur to reduce noise
    cv::GaussianBlur(processFrame, processFrame, cv::Size(9, 9), 2, 2);

    // Detect circles using Hough Circle Transform
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        processFrame,
        circles,
        cv::HOUGH_GRADIENT,
        1,              // dp: inverse ratio of accumulator resolution
        frame.rows / 8, // minDist: minimum distance between circle centers
        100,            // param1: Canny edge threshold
        30,             // param2: accumulator threshold for circle detection
        10,             // minRadius: minimum circle radius
        50              // maxRadius: maximum circle radius
    );

    if (!circles.empty()) {
        // Return the first (most prominent) circle
        qDebug() << "Detected" << circles.size() << "circles, using first one";
        qDebug() << "  Center: (" << cvRound(circles[0][0]) << "," << cvRound(circles[0][1]) << ")";
        qDebug() << "  Radius:" << cvRound(circles[0][2]) << "pixels";
        return circles[0];
    }

    return cv::Vec3f(0, 0, 0); // No ball detected
}
