#pragma once

#include <QObject>
#include <QTimer>
#include <opencv2/opencv.hpp>
#include <vector>

#include "FrameProvider.h"
#include "SettingsManager.h"

/**
 * @brief Camera calibration for pixel-to-mm conversion and ball detection tuning
 *
 * PiTrac-inspired multi-sample calibration approach:
 * - Captures 10 samples of ball at address position
 * - Detects ball center and radius in each sample
 * - Validates consistency across samples (std dev < 10%)
 * - Calculates pixels-per-mm, focal length, and ball position ROI
 * - Designed for rear-mounted MLM2-style setup
 */
class CalibrationManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isCalibrating READ isCalibrating NOTIFY isCalibratingChanged)
    Q_PROPERTY(double pixelsPerMm READ pixelsPerMm NOTIFY pixelsPerMmChanged)
    Q_PROPERTY(int ballRadiusPixels READ ballRadiusPixels NOTIFY ballRadiusPixelsChanged)
    Q_PROPERTY(double focalLengthMm READ focalLengthMm NOTIFY focalLengthMmChanged)
    Q_PROPERTY(int ballCenterX READ ballCenterX NOTIFY ballCenterChanged)
    Q_PROPERTY(int ballCenterY READ ballCenterY NOTIFY ballCenterChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)

public:
    explicit CalibrationManager(QObject *parent = nullptr);

    bool isCalibrating() const { return m_isCalibrating; }
    double pixelsPerMm() const { return m_pixelsPerMm; }
    int ballRadiusPixels() const { return m_ballRadiusPixels; }
    double focalLengthMm() const { return m_focalLengthMm; }
    int ballCenterX() const { return m_ballCenterX; }
    int ballCenterY() const { return m_ballCenterY; }
    QString status() const { return m_status; }
    int progress() const { return m_progress; }

    void setFrameProvider(FrameProvider *provider) { m_frameProvider = provider; }
    void setSettings(SettingsManager *settings) { m_settings = settings; }

public slots:
    // Step 1: Check if ball is visible (single frame test)
    void checkBallLocation();

    // Step 2: Auto calibration - PiTrac style (10 samples, validated)
    void startAutoCalibration();

    // Manual calibration - user provides ball radius in pixels
    void setManualCalibration(int ballRadiusPixels);

    // Reset calibration
    void resetCalibration();

signals:
    void isCalibratingChanged();
    void pixelsPerMmChanged();
    void ballRadiusPixelsChanged();
    void focalLengthMmChanged();
    void ballCenterChanged();
    void statusChanged();
    void progressChanged();

    void ballLocationChecked(bool found, int x, int y, int radius);
    void calibrationComplete(double pixelsPerMm, int ballRadiusPixels, double focalLength);
    void calibrationFailed(const QString &reason);

private slots:
    void captureSample();

private:
    // Standard golf ball diameter in mm
    static constexpr double GOLF_BALL_DIAMETER_MM = 42.67;
    static constexpr double GOLF_BALL_RADIUS_M = 0.021335; // meters

    // Camera sensor specs (OV9281)
    static constexpr double SENSOR_WIDTH_MM = 5.635;  // 1/4" sensor

    // Calibration parameters
    static constexpr int CALIBRATION_SAMPLES = 10;
    static constexpr int SAMPLE_INTERVAL_MS = 200;  // 200ms between samples
    static constexpr double MAX_STD_DEV_PERCENT = 10.0;  // Max 10% variation

    // Distance range (4.8 to 5.6 feet = 1.46 to 1.71 meters)
    static constexpr double MIN_DISTANCE_M = 1.46;
    static constexpr double MAX_DISTANCE_M = 1.71;

    FrameProvider *m_frameProvider;
    SettingsManager *m_settings;

    bool m_isCalibrating;
    double m_pixelsPerMm;
    int m_ballRadiusPixels;
    double m_focalLengthMm;
    int m_ballCenterX;
    int m_ballCenterY;
    QString m_status;
    int m_progress;

    // Multi-sample calibration state
    QTimer *m_sampleTimer;
    std::vector<cv::Vec3f> m_samples;  // Store detected balls (x, y, radius)
    int m_currentSample;

    // Detect ball in frame using Hough circles
    cv::Vec3f detectBall(const cv::Mat &frame);

    // Calculate statistics from samples
    double calculateMean(const std::vector<double> &values);
    double calculateStdDev(const std::vector<double> &values, double mean);

    // Calculate focal length from ball radius and distance
    double calculateFocalLength(int radiusPixels, int resolutionX, double distanceM);

    // Validate calibration results
    bool validateCalibration(const std::vector<cv::Vec3f> &samples);

    // Process completed calibration
    void finishCalibration();
};
