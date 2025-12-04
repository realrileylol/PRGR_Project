#ifndef TRAJECTORYTRACKER_H
#define TRAJECTORYTRACKER_H

#include <QObject>
#include <opencv2/opencv.hpp>
#include <opencv2/video/tracking.hpp>
#include <vector>
#include <deque>

class CameraCalibration;
class BallDetector;

/**
 * Kalman filter-based ball trajectory tracking for MLM2 Pro-quality measurements
 *
 * Features:
 * - Kalman filter for smooth trajectory prediction and noise filtering
 * - Launch angle calculation (vertical and horizontal)
 * - Ball speed calculation from camera (backup to radar)
 * - Trajectory fitting (parabolic/ballistic model)
 * - Impact detection and post-impact tracking
 */
class TrajectoryTracker : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isTracking READ isTracking NOTIFY trackingStateChanged)
    Q_PROPERTY(double launchAngleVertical READ launchAngleVertical NOTIFY launchAngleChanged)
    Q_PROPERTY(double launchAngleHorizontal READ launchAngleHorizontal NOTIFY launchAngleChanged)
    Q_PROPERTY(double ballSpeedMps READ ballSpeedMps NOTIFY ballSpeedChanged)
    Q_PROPERTY(double ballSpeedMph READ ballSpeedMph NOTIFY ballSpeedChanged)
    Q_PROPERTY(int trackedFrames READ trackedFrames NOTIFY trackingDataChanged)

public:
    explicit TrajectoryTracker(QObject *parent = nullptr);
    ~TrajectoryTracker() override;

    void setCalibration(CameraCalibration *calibration);
    void setBallDetector(BallDetector *detector);

    // Getters
    bool isTracking() const { return m_isTracking; }
    double launchAngleVertical() const { return m_launchAngleVertical; }
    double launchAngleHorizontal() const { return m_launchAngleHorizontal; }
    double ballSpeedMps() const { return m_ballSpeedMps; }
    double ballSpeedMph() const { return m_ballSpeedMps * 2.23694; }  // m/s to mph
    int trackedFrames() const { return m_trajectoryPoints.size(); }

    struct TrajectoryPoint {
        cv::Point3f position;         // 3D position (meters)
        cv::Point2f imagePosition;    // 2D image position (pixels)
        cv::Point3f velocity;         // 3D velocity (m/s)
        int64_t timestamp;            // Microseconds
        double confidence;            // Detection confidence

        TrajectoryPoint() : timestamp(0), confidence(0) {}
    };

    /**
     * Get complete trajectory data
     */
    std::vector<TrajectoryPoint> getTrajectory() const { return m_trajectoryPoints; }

    /**
     * Get predicted ball position at next frame
     */
    cv::Point3f predictNextPosition() const;

    /**
     * Get trajectory summary for display
     */
    QString getTrajectorySum mary() const;

public slots:
    /**
     * Start tracking - call when ball is detected at address
     */
    void startTracking();

    /**
     * Update tracking with new ball detection
     * Returns true if tracking successful
     */
    bool updateTracking(const cv::Point2f &ballPosition, int64_t timestamp, double confidence = 1.0);

    /**
     * Stop tracking and calculate final metrics
     */
    void stopTracking();

    /**
     * Reset tracker state
     */
    void reset();

signals:
    void trackingStateChanged();
    void launchAngleChanged();
    void ballSpeedChanged();
    void trackingDataChanged();

    void trackingStarted();
    void trackingStopped(double launchAngleV, double launchAngleH, double speedMph);
    void impactDetected(int64_t timestamp);

private:
    CameraCalibration *m_calibration = nullptr;
    BallDetector *m_detector = nullptr;

    // Tracking state
    bool m_isTracking = false;
    int64_t m_trackingStartTime = 0;

    // Kalman filter (4 state vars: x, y, vx, vy in 2D)
    // Will extend to 6 states (x, y, z, vx, vy, vz) if using 3D calibration
    cv::KalmanFilter m_kalmanFilter;
    cv::Mat m_kalmanState;       // Current state [x, y, vx, vy]
    cv::Mat m_kalmanMeasurement; // Measurement [x, y]

    // Trajectory data
    std::vector<TrajectoryPoint> m_trajectoryPoints;
    static constexpr int MAX_TRAJECTORY_POINTS = 100;

    // Launch metrics
    double m_launchAngleVertical = 0.0;    // Degrees above horizontal
    double m_launchAngleHorizontal = 0.0;  // Degrees left/right of target line
    double m_ballSpeedMps = 0.0;           // Meters per second
    bool m_launchMetricsCalculated = false;

    // Detection state
    int m_consecutiveMisses = 0;
    static constexpr int MAX_CONSECUTIVE_MISSES = 5;  // Stop tracking after 5 missed frames

    // Initialization
    void initializeKalmanFilter();
    void resetKalmanFilter(const cv::Point2f &initialPosition);

    // Tracking updates
    void predictKalman();
    void correctKalman(const cv::Point2f &measurement);
    cv::Point3f imageToWorld(const cv::Point2f &imagePoint, int64_t timestamp);

    // Launch metrics calculation
    void calculateLaunchMetrics();
    void fitTrajectory();
    cv::Point3f calculateInitialVelocity();
    std::pair<double, double> calculateLaunchAngles(const cv::Point3f &velocity);
    double calculateBallSpeed(const cv::Point3f &velocity);

    // Trajectory fitting
    struct ParabolicFit {
        double a, b, c;  // y = ax² + bx + c
        double rSquared; // Goodness of fit
    };
    ParabolicFit fitParabola(const std::vector<cv::Point2f> &points);

    // Utilities
    double timeDeltaSeconds(int64_t t1, int64_t t2) const;
    static constexpr double GRAVITY = 9.81;  // m/s²
};

#endif // TRAJECTORYTRACKER_H
