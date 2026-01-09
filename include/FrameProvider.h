#pragma once

#include <QQuickImageProvider>
#include <QImage>
#include <QMutex>
#include <opencv2/opencv.hpp>

/**
 * @brief Thread-safe image provider for QML display
 *
 * Converts OpenCV Mat frames to QImage for real-time preview in QML.
 * Thread-safe frame updates from camera capture thread.
 *
 * Note: QQuickImageProvider cannot inherit from QObject,
 * so we use direct method calls instead of signals.
 */
class FrameProvider : public QQuickImageProvider {
public:
    FrameProvider();
    ~FrameProvider() = default;

    // QQuickImageProvider interface
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // Thread-safe frame update
    void updateFrame(const cv::Mat &frame);

    // Get latest frame for processing
    cv::Mat getLatestFrame();

    // Get latest frame BEFORE rotation (for ball detection with crop coords)
    cv::Mat getLatestFrameUnrotated();

    // Set active camera index for rotation handling
    void setActiveCameraIndex(int index);

private:
    QImage cvMatToQImage(const cv::Mat &mat);

    QMutex m_mutex;
    QImage m_currentFrame;
    cv::Mat m_currentMat;         // Rotated cv::Mat for display
    cv::Mat m_currentMatUnrotated;  // Unrotated cv::Mat for ball detection
    int m_activeCameraIndex;      // 0 = camera 0 (portrait), 1 = camera 1 (landscape)
};
