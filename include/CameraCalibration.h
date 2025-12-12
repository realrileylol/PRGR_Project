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

    // Ball zone calibration (defines hit box and tracking zones)
    Q_PROPERTY(bool isBallZoneCalibrated READ isBallZoneCalibrated NOTIFY ballZoneCalibrationChanged)
    Q_PROPERTY(double ballCenterX READ ballCenterX NOTIFY ballZoneCalibrationChanged)
    Q_PROPERTY(double ballCenterY READ ballCenterY NOTIFY ballZoneCalibrationChanged)
    Q_PROPERTY(double ballRadius READ ballRadius NOTIFY ballZoneCalibrationChanged)

    // Zone boundaries (4 corners of 12"×12" zone)
    Q_PROPERTY(bool isZoneDefined READ isZoneDefined NOTIFY zoneDefinedChanged)
    Q_PROPERTY(QList<QPointF> zoneCorners READ zoneCorners NOTIFY zoneDefinedChanged)
    Q_PROPERTY(QList<QPointF> markerCorners READ markerCorners NOTIFY extrinsicCalibrationChanged)

    // Background subtraction
    Q_PROPERTY(bool hasBaseline READ hasBaseline NOTIFY baselineCaptured)

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

    bool isBallZoneCalibrated() const { return m_isBallZoneCalibrated; }
    double ballCenterX() const { return m_ballCenterX; }
    double ballCenterY() const { return m_ballCenterY; }
    double ballRadius() const { return m_ballRadius; }

    bool isZoneDefined() const { return m_isZoneDefined; }
    QList<QPointF> zoneCorners() const { return m_zoneCorners; }
    QList<QPointF> markerCorners() const { return m_markerCorners; }  // Extrinsic calibration marker corners

    // Scale factor (pixels per mm at image plane)
    double pixelsPerMm() const;

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

    // Ball zone calibration (detect ball for hit box definition)
    Q_INVOKABLE void detectBallForZoneCalibration();
    Q_INVOKABLE void setBallEdgePoints(const QList<QPointF> &edgePoints);
    Q_INVOKABLE void setZoneCorners(const QList<QPointF> &corners);
    Q_INVOKABLE void useMarkerCornersForZone();  // Use extrinsic calibration markers as zone
    void setBallZone(double centerX, double centerY, double radius);

    // Live ball tracking for real-time overlay
    Q_INVOKABLE QVariantMap detectBallLive();

    // Video recording with overlays
    Q_INVOKABLE void startRecording();
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE bool isRecording() const { return m_isRecording; }

    // Screenshot capture with overlays
    Q_INVOKABLE QString captureScreenshot();

    // Reset tracking when it gets stuck on wrong object
    Q_INVOKABLE void resetTracking();

    // Ball zone state (for UI display)
    Q_INVOKABLE QString getBallZoneStateDisplay() const;
    Q_INVOKABLE bool isSystemReady() const;
    Q_INVOKABLE bool isSystemArmed() const;

    // Debug visualization mode
    Q_INVOKABLE void setDebugMode(bool enabled);
    Q_INVOKABLE bool isDebugMode() const { return m_debugMode; }

    // Background subtraction for eliminating texture circles
    Q_INVOKABLE void captureBaseline();  // Capture empty zone (no ball)
    Q_INVOKABLE QString saveBackgroundSubtractionView();  // Save screenshot of difference image
    bool hasBaseline() const { return m_hasBaseline; }  // Now a Q_PROPERTY above

    // Load/save calibration
    void loadCalibration();
    void saveCalibration();
    void resetCalibration();

signals:
    void intrinsicCalibrationChanged();
    void extrinsicCalibrationChanged();
    void ballZoneCalibrationChanged();
    void zoneDefinedChanged();
    void statusChanged();
    void progressChanged();

    void calibrationFrameCaptured(int frameCount, bool validFrame);
    void calibrationComplete(const QString &summary);
    void calibrationFailed(const QString &reason);
    void ballDetectedForZone(double centerX, double centerY, double radius, double confidence);
    void baselineCaptured();  // Emitted when background baseline is captured

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

    // Ball zone calibration data (defines tracking zones)
    bool m_isBallZoneCalibrated = false;
    double m_ballCenterX = 0.0;    // Ball center X in pixels
    double m_ballCenterY = 0.0;    // Ball center Y in pixels
    double m_ballRadius = 0.0;     // Ball radius in pixels

    // Zone boundaries (4 corners of 12"×12" zone)
    bool m_isZoneDefined = false;
    QList<QPointF> m_zoneCorners;  // 4 corner points in pixels
    QList<QPointF> m_markerCorners;  // Extrinsic calibration marker corners (4 points in pixels)

    // Intrinsic calibration state
    int m_boardWidth = 0;
    int m_boardHeight = 0;
    float m_squareSize = 0.0f;
    std::vector<std::vector<cv::Point2f>> m_imagePoints;
    std::vector<std::vector<cv::Point3f>> m_objectPoints;

    // Live ball tracking state (temporal tracking)
    bool m_liveTrackingInitialized = false;
    double m_lastBallX = 0.0;
    double m_lastBallY = 0.0;
    double m_lastBallRadius = 0.0;
    double m_smoothedBallX = 0.0;
    double m_smoothedBallY = 0.0;
    int m_trackingConfidence = 0;  // Consecutive successful detections
    int m_missedFrames = 0;        // Consecutive failed detections

    // Velocity tracking for prediction (handle club occlusion)
    double m_ballVelocityX = 0.0;  // Pixels per frame
    double m_ballVelocityY = 0.0;  // Pixels per frame
    qint64 m_lastDetectionTime = 0;  // Timestamp of last successful detection

    // Kalman filter for professional-grade tracking (same as TrackMan/GCQuad)
    cv::KalmanFilter m_kalmanFilter;
    bool m_kalmanInitialized = false;

    // Ball zone state machine (like Bushnell/GCQuad/TrackMan ready system)
    enum class BallZoneState {
        NO_BALL,                // No ball detected anywhere
        BALL_OUT_OF_ZONE,      // Ball detected but outside 12×12 zone
        BALL_IN_ZONE_MOVING,   // Ball inside zone but still moving
        BALL_IN_ZONE_STABLE,   // Ball inside zone and stationary (stabilizing)
        READY,                 // Ball stable in zone for required time - ARMED
        IMPACT_DETECTED,       // Ball just left zone (impact occurred)
        POST_IMPACT            // Capturing post-impact data
    };

    BallZoneState m_ballZoneState = BallZoneState::NO_BALL;

    // Stability detection
    std::deque<cv::Point2f> m_ballPositionHistory;  // Recent positions for stability check
    const size_t m_stabilityHistorySize = 15;       // 0.5 seconds at 30 FPS
    const double m_stabilityThreshold = 2.0;        // Max 2px movement for "stable"
    qint64 m_stableStartTime = 0;                   // When ball became stable
    const qint64 m_readyRequiredMs = 1000;          // 1 second stable = READY

    // Impact detection
    bool m_isArmed = false;                         // True when in READY state
    qint64 m_impactTime = 0;                        // Timestamp of impact detection

    // Video recording
    bool m_isRecording = false;
    cv::VideoWriter m_videoWriter;
    QString m_recordingPath;
    int m_recordedFrames = 0;

    // Debug visualization
    bool m_debugMode = true;  // Start in debug mode to diagnose tracking issues
    cv::Mat m_lastDebugFrame;  // Store last debug frame for screenshot

    // Background subtraction (eliminate texture circles)
    bool m_hasBaseline = false;
    cv::Mat m_baselineFrame;  // Empty zone (no ball) - used for background subtraction
    cv::Mat m_lastDifferenceFrame;  // Store difference image for screenshot

    // Helper methods
    bool detectCheckerboard(const cv::Mat &image, std::vector<cv::Point2f> &corners);
    cv::Mat createUndistortMap();
    void calculateCameraPose();
    QString formatCalibrationSummary() const;

    // Ball zone state machine helpers
    bool isBallStable() const;
    QString getBallZoneStateString() const;
    void updateBallZoneState(bool ballDetected, bool inZone, double ballX, double ballY);

    // OV9281 sensor specs (for validation)
    static constexpr double SENSOR_WIDTH_MM = 5.635;   // 1/4" sensor physical width
    static constexpr double SENSOR_HEIGHT_MM = 3.516;  // 1/4" sensor physical height
};

#endif // CAMERACALIBRATION_H
