#include "CaptureManager.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <QProcess>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <chrono>
#include <thread>

CaptureManager::CaptureManager(KLD2Manager *kld2, SettingsManager *settings, QObject *parent)
    : QObject(parent)
    , m_kld2Manager(kld2)
    , m_settings(settings)
    , m_captureThread(nullptr)
    , m_isRunning(false)
    , m_stopping(false)
    , m_kld2Triggered(false)
    , m_kld2ImpactDetected(false)
    , m_waitingForImpact(false)
    , m_useKLD2Trigger(true)
    , m_width(320)
    , m_height(240)
{
    // Connect K-LD2 signals for hybrid detection
    if (m_kld2Manager) {
        connect(m_kld2Manager, &KLD2Manager::clubApproaching,
                this, &CaptureManager::onKLD2ClubDetected);
        connect(m_kld2Manager, &KLD2Manager::impactDetected,
                this, &CaptureManager::onKLD2Impact);
    }

    // Create captures folder
    QString capturesPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + "/PRGR_Captures";
    QDir().mkpath(capturesPath);

    qDebug() << "CaptureManager initialized - hybrid radar + camera verification enabled";
}

CaptureManager::~CaptureManager() {
    stopCapture();
}

void CaptureManager::onKLD2ClubDetected() {
    qDebug() << "⛳ K-LD2: Club approaching - monitoring for impact...";
    m_kld2Triggered.store(true);
    m_waitingForImpact.store(true);
}

void CaptureManager::onKLD2Impact() {
    qDebug() << "🏌️ K-LD2: Impact timing detected - verifying ball movement with camera...";
    m_kld2ImpactDetected.store(true);
}

void CaptureManager::startCapture() {
    if (m_isRunning.load()) {
        qWarning() << "Capture already running";
        return;
    }

    qDebug() << "Starting ball capture at 200 FPS...";

    // Reset state
    m_kld2Triggered.store(false);
    m_kld2ImpactDetected.store(false);
    m_waitingForImpact.store(false);
    m_stopping.store(false);

    // Start K-LD2 radar if available
    if (m_kld2Manager && m_useKLD2Trigger) {
        qDebug() << "Starting K-LD2 radar for impact detection...";
        if (!m_kld2Manager->start()) {
            qWarning() << "K-LD2 failed to start - using camera-only detection";
            m_useKLD2Trigger = false;
        }
    }

    // Start capture thread
    m_isRunning.store(true);
    m_captureThread = new CaptureThread(this);
    m_captureThread->start();

    emit isRunningChanged();
    emit statusChanged("Capture started - waiting for ball...", "green");
}

void CaptureManager::stopCapture() {
    if (!m_isRunning.load()) {
        return;
    }

    qDebug() << "Stopping capture...";
    m_stopping.store(true);
    m_isRunning.store(false);

    if (m_captureThread) {
        m_captureThread->wait(5000);
        delete m_captureThread;
        m_captureThread = nullptr;
    }

    // Stop K-LD2
    if (m_kld2Manager) {
        m_kld2Manager->stop();
    }

    emit isRunningChanged();
    emit statusChanged("Capture stopped", "gray");
    qDebug() << "Capture stopped";
}

void CaptureManager::captureLoop() {
    qDebug() << "Capture loop starting...";

    // Reload settings from disk to get latest Camera Settings values
    m_settings->load();

    // Load settings
    QString resolutionStr = m_settings->cameraResolution();
    QStringList resParts = resolutionStr.split('x');
    if (resParts.size() == 2) {
        m_width = resParts[0].toInt();
        m_height = resParts[1].toInt();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // IMPACT CAMERA - HIGH-SPEED SPIN CAPTURE CONFIGURATION
    // ═══════════════════════════════════════════════════════════════════════
    //
    // Physical Setup:
    //   - Distance: 6.5-8.5 ft from ball (optimal: 7 ft)
    //   - Camera orientation: 90° LEFT rotation (ribbon connector → RIGHT)
    //   - Lens: 12-16mm telephoto (ball fills 8-16% of frame at 7ft)
    //
    // Sensor Configuration (OV9281):
    //   - Mode: 640×400 @ 240 FPS (valid sensor mode, no ROI)
    //   - Real-world view: 400×640 portrait (after 90° rotation)
    //     → 400 px horizontal (focused on ball)
    //     → 640 px vertical (tall, tracks ball rising)
    //
    // Target Performance:
    //   - Frame rate: 240 FPS (native sensor mode)
    //   - Capture window: ~15-20ms (4-5 frames of ball)
    //   - Ball size: 20-40 px diameter at 7ft (with 12-16mm lens)

    m_width = 640;   // Sensor width (→ vertical in real world after rotation)
    m_height = 400;  // Sensor height (→ horizontal in real world after rotation)
    int frameRate = 240;  // 640×400 @ 240 FPS (valid OV9281 mode)
    int shutterSpeed = m_settings->cameraShutterSpeed();
    double gain = m_settings->cameraGain();

    // Ball detection settings
    int minRadius = m_settings->getNumber("detection/minRadius", 5);
    int maxRadius = m_settings->getNumber("detection/maxRadius", 50);
    int impactThreshold = m_settings->getNumber("detection/impactThreshold", 10);
    int impactAxis = m_settings->getNumber("detection/impactAxis", 1);  // Y-axis
    int impactDirection = m_settings->getNumber("detection/impactDirection", 1);  // Positive

    qDebug() << "Capture settings: Resolution=" << m_width << "x" << m_height
             << "FPS=" << frameRate << "Shutter=" << shutterSpeed
             << "Gain=" << gain;

    // Create named pipe for rpicam-vid
    QString pipePath = "/tmp/prgr_capture_pipe";
    unlink(pipePath.toLocal8Bit().constData());
    if (mkfifo(pipePath.toLocal8Bit().constData(), 0666) == -1) {
        qWarning() << "Failed to create capture pipe:" << strerror(errno);
        emit errorOccurred("Failed to create capture pipe");
        m_isRunning.store(false);
        return;
    }

    // Start rpicam-vid for capture
    QProcess *captureProcess = new QProcess();
    QStringList args;
    args << "--timeout" << "0";

    // IMPACT CAMERA - Use valid OV9281 sensor mode (640×400 @ 240 FPS)
    args << "--width" << QString::number(m_width);    // 640
    args << "--height" << QString::number(m_height);  // 400
    args << "--framerate" << QString::number(frameRate);
    args << "--shutter" << QString::number(shutterSpeed);
    args << "--gain" << QString::number(gain);

    // YUV420 codec - extract Y (luma) plane for monochrome spin detection
    // rpicam-vid does NOT support MONO8 codec
    args << "--codec" << "yuv420";
    args << "--output" << pipePath;
    args << "--nopreview";  // Preview disabled for maximum FPS

    qDebug() << "IMPACT CAMERA:" << m_width << "x" << m_height
             << "→ real-world 400×640 portrait @ target" << frameRate << "FPS"
             << "| Shutter:" << shutterSpeed << "µs, Gain:" << gain << "| Distance: 7ft";

    captureProcess->start("rpicam-vid", args);
    if (!captureProcess->waitForStarted(5000)) {
        emit errorOccurred("Failed to start capture process");
        delete captureProcess;
        unlink(pipePath.toLocal8Bit().constData());
        m_isRunning.store(false);
        return;
    }

    // Open pipe for reading
    int pipeFd = open(pipePath.toLocal8Bit().constData(), O_RDONLY);
    if (pipeFd < 0) {
        qWarning() << "Failed to open capture pipe:" << strerror(errno);
        captureProcess->kill();
        delete captureProcess;
        unlink(pipePath.toLocal8Bit().constData());
        m_isRunning.store(false);
        return;
    }

    qDebug() << "Capture pipe opened, starting ball detection loop...";

    // Frame buffer for YUV420 (1.5 bytes per pixel)
    const int frameSize = m_width * m_height * 3 / 2;
    std::vector<uint8_t> frameBuffer(frameSize);

    // Ball tracking state
    BallDetection originalBall = {-1, -1, -1, 0.0f};
    BallDetection currentBall;
    bool ballLocked = false;
    int shotNumber = 1;

    // Main capture loop
    while (m_isRunning.load()) {
        // Read frame
        ssize_t bytesRead = 0;
        ssize_t totalRead = 0;

        while (totalRead < frameSize && m_isRunning.load()) {
            bytesRead = read(pipeFd, frameBuffer.data() + totalRead, frameSize - totalRead);
            if (bytesRead < 0) {
                if (errno == EINTR) continue;
                qWarning() << "Pipe read error:" << strerror(errno);
                m_isRunning.store(false);
                break;
            } else if (bytesRead == 0) {
                m_isRunning.store(false);
                break;
            }
            totalRead += bytesRead;
        }

        if (totalRead != frameSize) continue;

        // Extract Y channel from YUV420 (grayscale)
        cv::Mat frame = extractYChannelFromYUV420(frameBuffer.data(), m_width, m_height);

        // Add to circular buffer
        m_frameBuffer.push_back(frame.clone());
        if (m_frameBuffer.size() > BUFFER_SIZE) {
            m_frameBuffer.pop_front();
        }

        // Detect ball
        currentBall = detectBall(frame);

        // Ball locking logic
        if (!ballLocked && currentBall.radius > 0) {
            // Found a ball - lock onto it
            originalBall = currentBall;
            ballLocked = true;
            emit statusChanged(QString("Ball locked at (%1, %2) - waiting for shot...")
                             .arg(currentBall.x).arg(currentBall.y), "green");
            qDebug() << "🎯 Ball locked at" << currentBall.x << currentBall.y
                     << "radius" << currentBall.radius;
        }

        // Check for impact if ball is locked
        if (ballLocked && isSameBall(originalBall, currentBall)) {
            // Hybrid detection mode
            if (m_useKLD2Trigger) {
                // Check if radar detected impact
                if (m_kld2ImpactDetected.load()) {
                    qDebug() << "🔍 K-LD2 impact flag detected, verifying ball movement...";
                    // Verify ball actually moved
                    bool ballMoved = detectImpact(originalBall, currentBall,
                                                  impactThreshold, impactAxis, impactDirection);

                    if (ballMoved) {
                        // ✅ CONFIRMED IMPACT
                        qDebug() << "✅ CONFIRMED IMPACT: Radar + Camera both agree!";
                        qDebug() << "   Ball moved from" << originalBall.x << originalBall.y
                                << "to" << currentBall.x << currentBall.y;

                        // Save replay
                        emit statusChanged("Capturing impact...", "red");

                        std::vector<cv::Mat> replayFrames(m_frameBuffer.begin(), m_frameBuffer.end());

                        // Capture 20 more post-impact frames
                        for (int i = 0; i < 20 && m_isRunning.load(); i++) {
                            cv::Mat postFrame = captureFrame();
                            if (!postFrame.empty()) {
                                replayFrames.push_back(postFrame);
                            }
                            std::this_thread::sleep_for(std::chrono::milliseconds(5));
                        }

                        qDebug() << "📸 Total frames captured:" << replayFrames.size();

                        // Generate replay files
                        QString capturesPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + "/PRGR_Captures";
                        QString videoFile = QString("%1/shot_%2_replay.mp4").arg(capturesPath).arg(shotNumber, 3, 10, QChar('0'));
                        QString gifFile = QString("%1/shot_%2_replay.gif").arg(capturesPath).arg(shotNumber, 3, 10, QChar('0'));

                        if (createReplayVideo(replayFrames, videoFile, frameRate, 0.025f)) {
                            qDebug() << "✅ Video saved:" << videoFile;
                        }

                        if (createReplayGif(replayFrames, gifFile, frameRate, 0.025f)) {
                            qDebug() << "✅ GIF saved:" << gifFile;
                            emit replayReady(QFileInfo(gifFile).absoluteFilePath());
                        }

                        emit shotCaptured(shotNumber);
                        shotNumber++;

                        // Reset for next shot
                        ballLocked = false;
                        originalBall = {-1, -1, -1, 0.0f};
                        m_kld2Triggered.store(false);
                        m_kld2ImpactDetected.store(false);
                        m_waitingForImpact.store(false);
                        m_frameBuffer.clear();

                        emit statusChanged("Ready for next shot", "green");

                    } else {
                        // ⚠️ PRACTICE SWING
                        qDebug() << "⚠️ PRACTICE SWING: Radar detected club but ball didn't move";

                        // Reset and wait for next swing
                        m_kld2Triggered.store(false);
                        m_kld2ImpactDetected.store(false);
                        m_waitingForImpact.store(false);
                    }
                }
            } else {
                // Camera-only mode
                if (detectImpact(originalBall, currentBall, impactThreshold, impactAxis, impactDirection)) {
                    qDebug() << "Camera detected impact!";
                    // Same replay logic as above...
                }
            }
        }
    }

    // Cleanup
    close(pipeFd);
    captureProcess->terminate();
    captureProcess->waitForFinished(2000);
    delete captureProcess;
    unlink(pipePath.toLocal8Bit().constData());

    qDebug() << "Capture loop exited";
}

cv::Mat CaptureManager::captureFrame() {
    // This is called from capture loop, frame is already being read
    // Just return an empty mat since we're using the main loop
    return cv::Mat();
}

cv::Mat CaptureManager::extractYChannelFromYUV420(const uint8_t *data, int width, int height) {
    cv::Mat yChannel(height, width, CV_8UC1);
    memcpy(yChannel.data, data, width * height);
    return yChannel;
}

CaptureManager::BallDetection CaptureManager::detectBall(const cv::Mat &frame) {
    BallDetection result = {-1, -1, -1, 0.0f};

    if (frame.empty()) {
        return result;
    }

    // Blur to reduce noise
    cv::Mat blurred;
    cv::GaussianBlur(frame, blurred, cv::Size(9, 9), 2, 2);

    // Detect circles using HoughCircles
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(blurred, circles, cv::HOUGH_GRADIENT, 1,
                     frame.rows / 16,  // Min distance between circles
                     100,              // Canny high threshold
                     30,               // Accumulator threshold
                     5,                // Min radius
                     50);              // Max radius

    if (!circles.empty()) {
        // Take the strongest detection
        cv::Vec3f c = circles[0];
        result.x = cvRound(c[0]);
        result.y = cvRound(c[1]);
        result.radius = cvRound(c[2]);
        result.confidence = 1.0f;
    }

    return result;
}

bool CaptureManager::isSameBall(const BallDetection &a, const BallDetection &b) {
    if (a.radius < 0 || b.radius < 0) return false;

    int dx = a.x - b.x;
    int dy = a.y - b.y;
    int distance = std::sqrt(dx*dx + dy*dy);

    // Ball is "same" if within 50 pixels
    return distance < 50;
}

bool CaptureManager::detectImpact(const BallDetection &original, const BallDetection &current,
                                  int threshold, int axis, int direction) {
    if (original.radius < 0 || current.radius < 0) return false;

    int movement = 0;
    if (axis == 0) {
        // X-axis
        movement = (current.x - original.x) * direction;
    } else {
        // Y-axis
        movement = (current.y - original.y) * direction;
    }

    return movement > threshold;
}

bool CaptureManager::createReplayVideo(const std::vector<cv::Mat> &frames, const QString &path,
                                       int fps, float speedMultiplier) {
    if (frames.empty()) return false;

    int slowFps = static_cast<int>(fps * speedMultiplier);
    if (slowFps < 1) slowFps = 1;

    cv::VideoWriter writer(path.toStdString(),
                          cv::VideoWriter::fourcc('m', 'p', '4', 'v'),
                          slowFps,
                          cv::Size(frames[0].cols, frames[0].rows),
                          false);  // Grayscale

    if (!writer.isOpened()) {
        qWarning() << "Failed to create video writer:" << path;
        return false;
    }

    for (const cv::Mat &frame : frames) {
        writer.write(frame);
    }

    writer.release();
    return true;
}

bool CaptureManager::createReplayGif(const std::vector<cv::Mat> &frames, const QString &path,
                                     int fps, float speedMultiplier) {
    if (frames.empty()) return false;

    // Create temporary PNGs
    QDir tempDir = QDir::temp();
    QString tempPath = tempDir.filePath("prgr_gif_frames");
    QDir().mkpath(tempPath);

    for (size_t i = 0; i < frames.size(); i++) {
        QString framePath = QString("%1/frame_%2.png").arg(tempPath).arg(i, 4, 10, QChar('0'));
        cv::imwrite(framePath.toStdString(), frames[i]);
    }

    // Use ImageMagick convert to create GIF
    int delay = static_cast<int>(100.0f / (fps * speedMultiplier));

    QProcess convert;
    QStringList args;
    args << "-delay" << QString::number(delay);
    args << "-loop" << "0";
    args << QString("%1/frame_*.png").arg(tempPath);
    args << path;

    convert.start("convert", args);
    bool success = convert.waitForFinished(10000);

    // Cleanup temp files
    QDir(tempPath).removeRecursively();

    return success && QFile::exists(path);
}
