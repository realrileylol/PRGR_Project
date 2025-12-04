#ifndef CAMERACALIBRATION_H
#define CAMERACALIBRATION_H

#include <QObject>
#include <QString>
#include <QImage>
#include <opencv2/opencv.hpp>
#include <vector>

class FrameProvider;
class SettingsManager;

/**
 * Full OpenCV camera calibration for MLM2 Pro-grade accuracy
 *
 * Handles:
 * - Intrinsic calibration (focal length, principal point, lens distortion)
 * - Extrinsic calibration (camera pose relative to ground plane)
 * - Distortion correction for all ball tracking
 */
class CameraCalibration : public QObject {
    Q_OBJECT

    // Calibration status properties
    Q_PROPERTY(bool isIntrinsicCalibrated READ isIntrinsicCalibrated NOTIFY intrinsicCalibrationChanged)
    Q_PROPERTY(bool isExtrinsicCalibrated READ isExtrinsicCalibrated NOTIFY extrinsicCalibrationChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)

    // Intrinsic parameters (camera-specific, calibrate once)
    Q_PROPERTY(double focalLengthX READ focalLengthX NOTIFY intrinsicCalibrationChanged)
    Q_PROPERTY(double focalLengthY READ focalLengthY NOTIFY intrinsicCalibrationChanged)
    Q_PROPERTY(double principalPointX READ principalPointX NOTIFY intrinsicCalibrationChanged)
    Q_PROPERTY(double principalPointY READ principalPointY NOTIFY intrinsicCalibrationChanged)

    // Extrinsic parameters (setup-specific, calibrate per position)
    Q_PROPERTY(double cameraHeight READ cameraHeight NOTIFY extrinsicCalibrationChanged)
    Q_PROPERTY(double cameraTiltAngle READ cameraTiltAngle NOTIFY extrinsicCalibrationChanged)
    Q_PROPERTY(double cameraDistance READ cameraDistance NOTIFY extrinsicCalibrationChanged)

public:
    explicit CameraCalibration(QObject *parent = nullptr);
    ~CameraCalibration() override;

    void setFrameProvider(FrameProvider *provider);
    void setSettings(SettingsManager *settings);

    // Getters
    bool isIntrinsicCalibrated() const { return m_isIntrinsicCalibrated; }
    bool isExtrinsicCalibrated() const { return m_isExtrinsicCalibrated; }
    QString status() const { return m_status; }
    int progress() const { return m_progress; }

    double focalLengthX() const { return m_fx; }
    double focalLengthY() const { return m_fy; }
    double principalPointX() const { return m_cx; }
    double principalPointY() const { return m_cy; }

    double cameraHeight() const { return m_cameraHeight; }
    double cameraTiltAngle() const { return m_cameraTilt; }
    double cameraDistance() const { return m_cameraDistance; }

    // Calibration matrices
    cv::Mat getCameraMatrix() const { return m_cameraMatrix.clone(); }
    cv::Mat getDistortionCoeffs() const { return m_distCoeffs.clone(); }
    cv::Mat getRotationMatrix() const { return m_rotationMatrix.clone(); }
    cv::Mat getTranslationVector() const { return m_translationVector.clone(); }

    // Apply calibration to correct distortion
    cv::Mat undistortImage(const cv::Mat &image) const;
    cv::Point2f undistortPoint(const cv::Point2f &point) const;

    // Convert pixel coordinates to real-world coordinates
    cv::Point3f pixelToWorld(const cv::Point2f &pixel, double assumedHeight = 0.0) const;
    cv::Point2f worldToPixel(const cv::Point3f &worldPoint) const;

public slots:
    // Intrinsic calibration (checkerboard method)
    void startIntrinsicCalibration(int boardWidth, int boardHeight, float squareSize);
    void captureCalibrationFrame();  // Call this 20-30 times with different board angles
    void finishIntrinsicCalibration();
    void cancelIntrinsicCalibration();

    // Extrinsic calibration (ground plane method)
    void startExtrinsicCalibration();
    void setGroundPlanePoints(const QList<QPointF> &imagePoints, const QList<QPointF> &worldPoints);
    void finishExtrinsicCalibration();

    // Load/save calibration
    void loadCalibration();
    void saveCalibration();
    void resetCalibration();

signals:
    void intrinsicCalibrationChanged();
    void extrinsicCalibrationChanged();
    void statusChanged();
    void progressChanged();

    void calibrationFrameCaptured(int frameCount, bool validFrame);
    void calibrationComplete(const QString &summary);
    void calibrationFailed(const QString &reason);

private:
    FrameProvider *m_frameProvider = nullptr;
    SettingsManager *m_settings = nullptr;

    // Calibration state
    bool m_isIntrinsicCalibrated = false;
    bool m_isExtrinsicCalibrated = false;
    QString m_status = "Not calibrated";
    int m_progress = 0;

    // Intrinsic calibration data (camera-specific)
    cv::Mat m_cameraMatrix;        // 3×3 matrix [fx 0 cx; 0 fy cy; 0 0 1]
    cv::Mat m_distCoeffs;          // Distortion coefficients [k1 k2 p1 p2 k3]
    double m_fx = 0.0;             // Focal length X (pixels)
    double m_fy = 0.0;             // Focal length Y (pixels)
    double m_cx = 0.0;             // Principal point X (pixels)
    double m_cy = 0.0;             // Principal point Y (pixels)

    // Extrinsic calibration data (setup-specific)
    cv::Mat m_rotationMatrix;      // 3×3 rotation matrix (camera orientation)
    cv::Mat m_translationVector;   // 3×1 translation vector (camera position)
    cv::Mat m_homography;          // 3×3 ground plane homography
    double m_cameraHeight = 0.0;   // Height above ground (meters)
    double m_cameraTilt = 0.0;     // Tilt angle (degrees)
    double m_cameraDistance = 0.0; // Distance to ball (meters)

    // Intrinsic calibration state
    int m_boardWidth = 0;
    int m_boardHeight = 0;
    float m_squareSize = 0.0f;
    std::vector<std::vector<cv::Point2f>> m_imagePoints;
    std::vector<std::vector<cv::Point3f>> m_objectPoints;

    // Helper methods
    bool detectCheckerboard(const cv::Mat &image, std::vector<cv::Point2f> &corners);
    cv::Mat createUndistortMap();
    void calculateCameraPose();
    QString formatCalibrationSummary() const;

    // OV9281 sensor specs (for validation)
    static constexpr double SENSOR_WIDTH_MM = 5.635;   // 1/4" sensor physical width
    static constexpr double SENSOR_HEIGHT_MM = 3.516;  // 1/4" sensor physical height
};

#endif // CAMERACALIBRATION_H
