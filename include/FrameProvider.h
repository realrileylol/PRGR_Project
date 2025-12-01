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

private:
    QImage cvMatToQImage(const cv::Mat &mat);

    QMutex m_mutex;
    QImage m_currentFrame;
};
