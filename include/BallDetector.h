#ifndef BALLDETECTOR_H
#define BALLDETECTOR_H

#include <QObject>
#include <opencv2/opencv.hpp>
#include <vector>
#include <deque>

class CameraCalibration;

/**
 * Advanced ball detection system for MLM2 Pro-quality tracking
 *
 * Features:
 * - Background subtraction for robust detection in varying conditions
 * - Multi-method detection (HoughCircles, blob detection, contour analysis)
 * - Adaptive thresholding based on lighting conditions
 * - False positive filtering via size/circularity constraints
 * - Temporal consistency checking across frames
 */
class BallDetector : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isCalibrated READ isCalibrated NOTIFY calibrationChanged)
    Q_PROPERTY(QString detectionMethod READ detectionMethod NOTIFY detectionMethodChanged)
    Q_PROPERTY(int minBallRadius READ minBallRadius WRITE setMinBallRadius NOTIFY parametersChanged)
    Q_PROPERTY(int maxBallRadius READ maxBallRadius WRITE setMaxBallRadius NOTIFY parametersChanged)
    Q_PROPERTY(double circularityThreshold READ circularityThreshold WRITE setCircularityThreshold NOTIFY parametersChanged)

public:
    explicit BallDetector(QObject *parent = nullptr);
    ~BallDetector() override;

    void setCalibration(CameraCalibration *calibration);

    // Getters
    bool isCalibrated() const { return m_calibration != nullptr; }
    QString detectionMethod() const { return m_detectionMethod; }
    int minBallRadius() const { return m_minBallRadius; }
    int maxBallRadius() const { return m_maxBallRadius; }
    double circularityThreshold() const { return m_circularityThreshold; }

    // Setters
    void setMinBallRadius(int radius);
    void setMaxBallRadius(int radius);
    void setCircularityThreshold(double threshold);

    // Detection methods
    struct BallDetection {
        cv::Point2f center;           // Ball center in pixels
        float radius;                 // Ball radius in pixels
        float confidence;             // Detection confidence 0-1
        cv::Point3f worldPosition;    // 3D position (if calibrated)
        int64_t timestamp;            // Frame timestamp (microseconds)

        BallDetection() : radius(0), confidence(0), timestamp(0) {}
        BallDetection(cv::Point2f c, float r, float conf, int64_t ts)
            : center(c), radius(r), confidence(conf), timestamp(ts) {}
    };

    /**
     * Detect ball in a single frame
     * Returns detection with confidence score
     */
    BallDetection detectBall(const cv::Mat &frame, int64_t timestamp = 0);

    /**
     * Detect ball with background subtraction
     * More robust for stationary cameras
     */
    BallDetection detectBallWithBackground(const cv::Mat &frame, int64_t timestamp = 0);

    /**
     * Track ball across multiple frames
     * Returns true if ball found and tracked
     */
    bool trackBall(const cv::Mat &frame, int64_t timestamp = 0);

    /**
     * Get recent ball detections for trajectory analysis
     */
    std::vector<BallDetection> getRecentDetections(int count = 10) const;

    /**
     * Clear detection history
     */
    void reset();

public slots:
    /**
     * Capture clean background for subtraction
     * Call this before shot when ball is not in frame
     */
    void captureBackground(const cv::Mat &frame);

    /**
     * Enable/disable background subtraction
     */
    void setBackgroundSubtractionEnabled(bool enabled);

    /**
     * Set detection method: "hough", "blob", "contour", "auto"
     */
    void setDetectionMethod(const QString &method);

signals:
    void calibrationChanged();
    void detectionMethodChanged();
    void parametersChanged();
    void ballDetected(cv::Point2f center, float radius, float confidence);
    void backgroundCaptured();

private:
    CameraCalibration *m_calibration = nullptr;

    // Detection parameters
    QString m_detectionMethod = "auto";  // auto, hough, blob, contour
    int m_minBallRadius = 4;             // Minimum ball radius (pixels) - 640×480
    int m_maxBallRadius = 15;            // Maximum ball radius (pixels)
    double m_circularityThreshold = 0.7; // Minimum circularity (0-1)

    // Background subtraction
    bool m_backgroundSubtractionEnabled = false;
    cv::Mat m_background;
    cv::Ptr<cv::BackgroundSubtractor> m_backgroundSubtractor;

    // Detection history for temporal filtering
    std::deque<BallDetection> m_detectionHistory;
    static constexpr int MAX_HISTORY = 50;  // Keep last 50 detections

    // Detection methods
    BallDetection detectWithHoughCircles(const cv::Mat &frame);
    BallDetection detectWithBlobDetector(const cv::Mat &frame);
    BallDetection detectWithContours(const cv::Mat &frame);
    BallDetection detectAuto(const cv::Mat &frame);

    // Preprocessing
    cv::Mat preprocessFrame(const cv::Mat &frame);
    cv::Mat applyBackgroundSubtraction(const cv::Mat &frame);

    // Validation and filtering
    bool isValidBallCandidate(const cv::Point2f &center, float radius, const cv::Mat &frame);
    float calculateCircularity(const std::vector<cv::Point> &contour);
    float calculateConfidence(const BallDetection &detection, const cv::Mat &frame);
    BallDetection filterWithHistory(const BallDetection &detection);

    // Utilities
    void addToHistory(const BallDetection &detection);
    cv::Point2f predictNextPosition() const;
};

#endif // BALLDETECTOR_H
