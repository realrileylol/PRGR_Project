#include "FrameProvider.h"
#include <QMutexLocker>

FrameProvider::FrameProvider()
    : QQuickImageProvider(QQuickImageProvider::Image)
{
    // Initialize with black image
    m_currentFrame = QImage(320, 240, QImage::Format_Grayscale8);
    m_currentFrame.fill(Qt::black);
}

QImage FrameProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    Q_UNUSED(id);
    Q_UNUSED(requestedSize);

    QMutexLocker locker(&m_mutex);

    if (size) {
        *size = m_currentFrame.size();
    }

    return m_currentFrame;
}

void FrameProvider::updateFrame(const cv::Mat &frame) {
    if (frame.empty()) {
        return;
    }

    // ========== CAMERA ROTATION ==========
    // Camera is physically rotated 90° right/clockwise (portrait mode)
    // Rotate frame to correct orientation for all downstream processing
    cv::Mat rotatedFrame;
    cv::rotate(frame, rotatedFrame, cv::ROTATE_90_CLOCKWISE);

    QMutexLocker locker(&m_mutex);
    m_currentMat = rotatedFrame.clone();  // Store rotated cv::Mat for processing
    m_currentFrame = cvMatToQImage(rotatedFrame);
    // Note: QML will poll for updates via requestImage()
}

cv::Mat FrameProvider::getLatestFrame() {
    QMutexLocker locker(&m_mutex);
    return m_currentMat.clone();  // Return copy for thread safety
}

QImage FrameProvider::cvMatToQImage(const cv::Mat &mat) {
    switch (mat.type()) {
    case CV_8UC1: {
        // Grayscale image
        QImage image(mat.data, mat.cols, mat.rows, static_cast<int>(mat.step),
                     QImage::Format_Grayscale8);
        return image.copy(); // Deep copy to own the data
    }
    case CV_8UC3: {
        // BGR image -> RGB
        cv::Mat rgb;
        cv::cvtColor(mat, rgb, cv::COLOR_BGR2RGB);
        QImage image(rgb.data, rgb.cols, rgb.rows, static_cast<int>(rgb.step),
                     QImage::Format_RGB888);
        return image.copy(); // Deep copy
    }
    case CV_8UC4: {
        // BGRA image -> RGBA
        cv::Mat rgba;
        cv::cvtColor(mat, rgba, cv::COLOR_BGRA2RGBA);
        QImage image(rgba.data, rgba.cols, rgba.rows, static_cast<int>(rgba.step),
                     QImage::Format_RGBA8888);
        return image.copy(); // Deep copy
    }
    default:
        qWarning() << "Unsupported cv::Mat format:" << mat.type();
        return QImage();
    }
}
