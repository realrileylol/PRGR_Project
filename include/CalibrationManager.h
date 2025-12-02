#pragma once

#include <QObject>
#include <opencv2/opencv.hpp>

/**
 * @brief Camera calibration for pixel-to-mm conversion and ball detection tuning
 *
 * Uses known golf ball diameter (42.67mm) to calculate pixels-per-mm ratio.
 * Helps tune detection parameters for rear-mounted camera setup.
 */
class CalibrationManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isCalibrating READ isCalibrating NOTIFY isCalibratingChanged)
    Q_PROPERTY(double pixelsPerMm READ pixelsPerMm NOTIFY pixelsPerMmChanged)
    Q_PROPERTY(int ballRadiusPixels READ ballRadiusPixels NOTIFY ballRadiusPixelsChanged)

public:
    explicit CalibrationManager(QObject *parent = nullptr);

    bool isCalibrating() const { return m_isCalibrating; }
    double pixelsPerMm() const { return m_pixelsPerMm; }
    int ballRadiusPixels() const { return m_ballRadiusPixels; }

public slots:
    // Calibrate using a frame with ball at address position
    void calibrateFromFrame(const cv::Mat &frame);

    // Manual calibration - user provides ball radius in pixels
    void setManualCalibration(int ballRadiusPixels);

    // Reset calibration
    void resetCalibration();

signals:
    void isCalibratingChanged();
    void pixelsPerMmChanged();
    void ballRadiusPixelsChanged();
    void calibrationComplete(double pixelsPerMm, int ballRadiusPixels);
    void calibrationFailed(const QString &reason);

private:
    // Standard golf ball diameter in mm
    static constexpr double GOLF_BALL_DIAMETER_MM = 42.67;

    bool m_isCalibrating;
    double m_pixelsPerMm;  // Conversion factor
    int m_ballRadiusPixels; // Expected ball radius in pixels

    // Detect ball in calibration frame
    cv::Vec3f detectBallForCalibration(const cv::Mat &frame);
};
