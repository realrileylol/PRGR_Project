#pragma once

#include <QObject>
#include <QThread>
#include <QString>
#include <opencv2/opencv.hpp>
#include <deque>
#include <memory>
#include <atomic>

#include "KLD2Manager.h"
#include "SettingsManager.h"

/**
 * @brief High-speed ball capture and impact detection manager
 *
 * Features:
 * - 200 FPS ball tracking at 320x240
 * - Hybrid radar + camera impact verification
 * - Circular buffer for pre-impact frame capture
 * - Template matching + Kalman filter tracking
 * - Practice swing elimination
 */
class CaptureManager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)

public:
    explicit CaptureManager(KLD2Manager *kld2, SettingsManager *settings, QObject *parent = nullptr);
    ~CaptureManager();

    bool isRunning() const { return m_isRunning.load(); }

public slots:
    void startCapture();
    void stopCapture();

signals:
    void isRunningChanged();
    void statusChanged(const QString &message, const QString &color);
    void shotCaptured(int shotNumber);
    void replayReady(const QString &gifPath);
    void errorOccurred(const QString &error);

private slots:
    void onKLD2ClubDetected();
    void onKLD2Impact();

private:
    class CaptureThread;
    friend class CaptureThread;

    void captureLoop();
    cv::Mat captureFrame();
    cv::Mat extractYChannelFromYUV420(const uint8_t *data, int width, int height);

    // Ball detection
    struct BallDetection {
        int x, y, radius;
        float confidence;
    };

    BallDetection detectBall(const cv::Mat &frame);
    bool isSameBall(const BallDetection &a, const BallDetection &b);
    bool detectImpact(const BallDetection &original, const BallDetection &current,
                      int threshold, int axis, int direction);

    // Replay creation
    bool createReplayVideo(const std::vector<cv::Mat> &frames, const QString &path, int fps, float speedMultiplier);
    bool createReplayGif(const std::vector<cv::Mat> &frames, const QString &path, int fps, float speedMultiplier);

    KLD2Manager *m_kld2Manager;
    SettingsManager *m_settings;

    // Capture thread
    CaptureThread *m_captureThread;
    std::atomic<bool> m_isRunning;
    std::atomic<bool> m_stopping;

    // K-LD2 state
    std::atomic<bool> m_kld2Triggered;
    std::atomic<bool> m_kld2ImpactDetected;
    std::atomic<bool> m_waitingForImpact;
    bool m_useKLD2Trigger;

    // Circular frame buffer
    std::deque<cv::Mat> m_frameBuffer;
    static constexpr int BUFFER_SIZE = 40;

    // Resolution
    int m_width, m_height;
};

/**
 * @brief Worker thread for capture loop
 */
class CaptureManager::CaptureThread : public QThread {
    Q_OBJECT

public:
    explicit CaptureThread(CaptureManager *manager) : m_manager(manager) {}
    void run() override { m_manager->captureLoop(); }

private:
    CaptureManager *m_manager;
};
