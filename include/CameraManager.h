#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <QProcess>
#include <QFile>
#include <opencv2/opencv.hpp>
#include <atomic>

#include "FrameProvider.h"
#include "SettingsManager.h"
#include "AutoExposureController.h"

/**
 * @brief High-performance camera manager using rpicam-vid with named pipes
 *
 * Features:
 * - rpicam-vid outputs YUV420 to named pipe (FIFO)
 * - 120+ FPS at 320x240 (bypasses ISP overhead)
 * - Background thread reads pipe and extracts Y channel
 * - Separate recording mode with MP4 output
 * - Simple, reliable, no libcamera API complexity
 */
class CameraManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool previewActive READ previewActive NOTIFY previewActiveChanged)
    Q_PROPERTY(bool recordingActive READ recordingActive NOTIFY recordingActiveChanged)
    Q_PROPERTY(int activeCameraIndex READ activeCameraIndex WRITE setActiveCameraIndex NOTIFY activeCameraIndexChanged)
    Q_PROPERTY(bool autoExposureEnabled READ autoExposureEnabled WRITE setAutoExposureEnabled NOTIFY autoExposureEnabledChanged)
    Q_PROPERTY(int currentShutter READ currentShutter NOTIFY exposureChanged)
    Q_PROPERTY(double currentGain READ currentGain NOTIFY exposureChanged)

public:
    explicit CameraManager(FrameProvider *frameProvider, SettingsManager *settings, QObject *parent = nullptr);
    ~CameraManager();

    bool previewActive() const { return m_previewActive.load(); }
    bool recordingActive() const { return m_recordingActive; }
    int activeCameraIndex() const { return m_activeCameraIndex; }
    void setActiveCameraIndex(int index);
    bool autoExposureEnabled() const { return m_autoExposureEnabled; }
    void setAutoExposureEnabled(bool enabled);
    int currentShutter() const { return m_currentShutter; }
    double currentGain() const { return m_currentGain; }

public slots:
    void startPreview();
    void stopPreview();
    void startRecording();
    void stopRecording();
    void takeSnapshot();
    void takeSnapshotBurst(int count);

signals:
    void previewActiveChanged();
    void recordingActiveChanged();
    void activeCameraIndexChanged();
    void autoExposureEnabledChanged();
    void exposureChanged();
    void frameReady();
    void snapshotCaptured(const QString &filePath);
    void recordingSaved(const QString &filePath);
    void errorOccurred(const QString &error);

private:
    class PreviewThread;
    friend class PreviewThread;

    void previewLoop();
    cv::Mat extractYChannelFromYUV420(const uint8_t *data, int width, int height);
    bool createNamedPipe(const QString &pipePath);
    void cleanupNamedPipe();
    void restartPreviewWithExposure(int shutter, double gain);

    FrameProvider *m_frameProvider;
    SettingsManager *m_settings;

    // Preview via rpicam-vid + named pipe
    QProcess *m_previewProcess;
    QString m_pipePath;
    int m_pipeFd;  // File descriptor for pipe
    PreviewThread *m_previewThread;
    std::atomic<bool> m_previewActive;

    // Recording
    QProcess *m_recordingProcess;
    bool m_recordingActive;
    QString m_currentRecordingPath;

    // Frame dimensions
    int m_previewWidth;
    int m_previewHeight;

    // Camera selection (0 = camera 0, 1 = camera 1)
    int m_activeCameraIndex;

    // Auto-exposure control
    bool m_autoExposureEnabled;
    AutoExposureController m_autoExposure;
    int m_currentShutter;
    double m_currentGain;
    int m_framesSinceLastAdjustment;
    static constexpr int ADJUST_INTERVAL_FRAMES = 30;  // Check every 30 frames (~0.16s at 180fps)
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
