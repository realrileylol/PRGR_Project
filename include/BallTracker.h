#pragma once

#include <QObject>
#include <QTimer>
#include <QMutex>
#include <opencv2/opencv.hpp>
#include <deque>
#include <chrono>

class CameraManager;
class CameraCalibration;
class KLD2Manager;

// Tracked ball position with timestamp
struct BallPosition {
    cv::Point2f pixelPos;           // 2D position in image (pixels)
    cv::Point3f worldPos;           // 3D position in world coordinates (mm)
    std::chrono::high_resolution_clock::time_point timestamp;
    double confidence;              // 0.0 - 1.0
    int frameNumber;
    cv::Mat frame;                  // Optional: store the frame for analysis
};

// Tracking state machine
enum class TrackingState {
    IDLE,           // Not tracking, waiting to arm
    ARMED,          // Monitoring for ball movement
    TRIGGERED,      // Ball motion detected, capturing frames
    TRACKING,       // Actively tracking ball across frames
    ANALYZING,      // Tracking complete, analyzing trajectory
    COMPLETE        // Analysis done, results available
};

class BallTracker : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isTracking READ isTracking NOTIFY trackingStateChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(int capturedFrames READ capturedFrames NOTIFY capturedFramesChanged)

public:
    explicit BallTracker(CameraManager *cameraManager,
                        CameraCalibration *calibration,
                        QObject *parent = nullptr);
    ~BallTracker() override;

    // Set KLD2 radar for hybrid triggering (optional but recommended)
    void setRadar(KLD2Manager *radar) { m_radar = radar; }

    bool isTracking() const { return m_state != TrackingState::IDLE; }
    QString status() const { return m_status; }
    int capturedFrames() const { return m_trackedPositions.size(); }

    // Get tracking results
    std::vector<BallPosition> getTrajectory() const { return m_trackedPositions; }

public slots:
    // Control tracking
    Q_INVOKABLE void armTracking();      // Start monitoring for hit
    Q_INVOKABLE void disarmTracking();   // Stop monitoring
    Q_INVOKABLE void resetTracking();    // Clear results and reset

    // Configuration
    void setMotionThreshold(double threshold);
    void setMinTrackingFrames(int frames);
    void setMaxTrackingFrames(int frames);
    void setSearchExpansionRate(double rate);

signals:
    void trackingStateChanged();
    void statusChanged();
    void capturedFramesChanged();

    void ballAtRest(cv::Point2f position);           // Ball detected and stationary
    void hitDetected(cv::Point2f position);          // Ball motion detected
    void trackingComplete(int frameCount);           // Tracking finished
    void trajectoryReady(std::vector<BallPosition> trajectory);  // Analysis complete

    void trackingFailed(QString reason);             // Error occurred

private slots:
    void processFrame();

private:
    // Core tracking functions
    void detectStationaryBall(const cv::Mat &frame);
    bool detectMotion(const cv::Mat &currentFrame, const cv::Mat &referenceFrame);
    bool detectBall(const cv::Mat &frame, const cv::Rect &searchRegion, cv::Point2f &ballPos);
    cv::Rect getSearchRegion(const cv::Point2f &lastPos, int framesSinceHit);
    double calculateConfidence(const cv::Mat &frame, const cv::Point2f &pos);

    // Helper functions
    cv::Mat preprocessFrame(const cv::Mat &frame);
    void updateBackgroundModel(const cv::Mat &frame);
    cv::Point2f predictNextPosition(const std::vector<BallPosition> &positions);
    bool validatePosition(const cv::Point2f &pos, const cv::Point2f &predicted);
    void setState(TrackingState newState);
    void setStatus(const QString &status);

    // Analysis functions
    void analyzeTrajectory();
    cv::Point3f pixelToWorld(const cv::Point2f &pixel);

private:
    CameraManager *m_cameraManager;
    CameraCalibration *m_calibration;
    KLD2Manager *m_radar;  // Optional: use radar for more reliable triggering

    // Tracking state
    TrackingState m_state;
    QString m_status;
    QTimer *m_processTimer;
    QMutex m_dataMutex;

    // Circular frame buffer (for pre-trigger frames)
    static const int BUFFER_SIZE = 30;  // ~160ms at 187fps
    std::deque<cv::Mat> m_frameBuffer;
    std::deque<std::chrono::high_resolution_clock::time_point> m_timestampBuffer;

    // Background/reference frames
    cv::Mat m_referenceFrame;       // Frame with ball at rest
    cv::Mat m_backgroundModel;      // Running average background
    int m_framesSinceArmed;

    // Ball detection
    cv::Point2f m_stationaryBallPos;
    cv::Point2f m_lastBallPos;
    std::chrono::high_resolution_clock::time_point m_hitTime;
    int m_frameNumber;

    // Tracked trajectory
    std::vector<BallPosition> m_trackedPositions;

    // Configuration parameters
    double m_motionThreshold;       // Pixel intensity difference threshold
    int m_minTrackingFrames;        // Minimum frames to capture (10-15)
    int m_maxTrackingFrames;        // Maximum frames before timeout (50-60)
    double m_searchExpansionRate;   // How much to expand search region per frame (1.2 = 20% growth)
    int m_minBallArea;              // Minimum blob area (pixels)
    int m_maxBallArea;              // Maximum blob area (pixels)
    double m_maxFrameToFrameDistance; // Max ball movement between frames (pixels)

    // Calibration data (cached)
    cv::Point2f m_ballZoneCenter;
    double m_ballZoneRadius;
    std::vector<cv::Point2f> m_zoneCorners;
};
