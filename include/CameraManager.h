#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <QProcess>
#include <opencv2/opencv.hpp>
#include <libcamera/libcamera.h>
#include <memory>
#include <atomic>

#include "FrameProvider.h"
#include "SettingsManager.h"

/**
 * @brief High-performance camera manager using libcamera
 *
 * Features:
 * - Direct libcamera C++ API for maximum performance
 * - 120+ FPS at 320x240 using lores stream (bypasses ISP)
 * - YUV420 Y-channel extraction for grayscale display
 * - Separate preview and recording modes
 * - rpicam-vid integration for MP4 recording
 */
class CameraManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool previewActive READ previewActive NOTIFY previewActiveChanged)
    Q_PROPERTY(bool recordingActive READ recordingActive NOTIFY recordingActiveChanged)

public:
    explicit CameraManager(FrameProvider *frameProvider, SettingsManager *settings, QObject *parent = nullptr);
    ~CameraManager();

    bool previewActive() const { return m_previewActive.load(); }
    bool recordingActive() const { return m_recordingActive; }

public slots:
    void startPreview();
    void stopPreview();
    void startRecording();
    void stopRecording();
    void takeSnapshot();

signals:
    void previewActiveChanged();
    void recordingActiveChanged();
    void frameReady();
    void snapshotCaptured(const QString &filePath);
    void errorOccurred(const QString &error);

private:
    class PreviewThread;
    friend class PreviewThread;

    void previewLoop();
    cv::Mat extractYChannelFromYUV420(const uint8_t *data, int width, int height);

    FrameProvider *m_frameProvider;
    SettingsManager *m_settings;

    // libcamera objects
    std::unique_ptr<libcamera::CameraManager> m_cameraManager;
    std::shared_ptr<libcamera::Camera> m_camera;
    std::unique_ptr<libcamera::FrameBufferAllocator> m_allocator;
    std::unique_ptr<libcamera::CameraConfiguration> m_config;

    // Preview thread
    PreviewThread *m_previewThread;
    std::atomic<bool> m_previewActive;

    // Recording
    QProcess *m_recordingProcess;
    bool m_recordingActive;
};

/**
 * @brief Worker thread for preview rendering
 */
class CameraManager::PreviewThread : public QThread {
    Q_OBJECT

public:
    explicit PreviewThread(CameraManager *manager) : m_manager(manager) {}
    void run() override { m_manager->previewLoop(); }

private:
    CameraManager *m_manager;
};
