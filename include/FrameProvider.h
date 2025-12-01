#pragma once

#include <QObject>
#include <QQuickImageProvider>
#include <QImage>
#include <QMutex>
#include <opencv2/opencv.hpp>

/**
 * @brief Thread-safe image provider for QML display
 *
 * Converts OpenCV Mat frames to QImage for real-time preview in QML.
 * Thread-safe frame updates from camera capture thread.
 */
class FrameProvider : public QObject, public QQuickImageProvider {
    Q_OBJECT

public:
    FrameProvider();
    ~FrameProvider() = default;

    // QQuickImageProvider interface
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

    // Thread-safe frame update
    void updateFrame(const cv::Mat &frame);

signals:
    void frameUpdated();

private:
    QImage cvMatToQImage(const cv::Mat &mat);

    QMutex m_mutex;
    QImage m_currentFrame;
};
