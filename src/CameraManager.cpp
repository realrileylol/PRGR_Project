#include "CameraManager.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#ifndef _WIN32
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#endif
#include <chrono>
#include <cmath>

CameraManager::CameraManager(FrameProvider *frameProvider, SettingsManager *settings, QObject *parent)
    : QObject(parent)
    , m_frameProvider(frameProvider)
    , m_settings(settings)
    , m_previewProcess(nullptr)
    , m_pipePath("/tmp/prgr_camera_pipe")
    , m_pipeFd(-1)
    , m_previewThread(nullptr)
    , m_previewActive(false)
    , m_recordingProcess(nullptr)
    , m_recordingActive(false)
    , m_previewWidth(320)
    , m_previewHeight(240)
    , m_activeCameraIndex(0)
    , m_autoExposureEnabled(false)
    , m_currentShutter(8000)  // Increased for better indoor lighting (was 4000 - too dark)
    , m_currentGain(16.0)      // Increased for better indoor lighting (was 12.0 - too dark)
    , m_framesSinceLastAdjustment(0)
    , m_currentFPS(0.0)
    , m_fpsLastUpdate(std::chrono::steady_clock::now())
    , m_fpsFrameCount(0)
    , m_simulationMode(false)
    , m_simTimer(nullptr)
    , m_simPhase(0.0)
    , m_simSourceCameraIndex(-1)
{
    // Create videos folder
    QString videosPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + "/PRGR_Videos";
    QDir().mkpath(videosPath);

    // Configure auto-exposure for golf ball tracking
    m_autoExposure.setTargetBrightness(100, 180, 140);  // Target medium brightness
    m_autoExposure.setShutterLimits(1000, 8000);  // 1ms to 8ms (prevent motion blur)
    m_autoExposure.setGainLimits(1.0, 16.0);  // 1x to 16x gain
    m_autoExposure.setAdjustmentSpeed(0.3);  // Moderate speed
}

CameraManager::~CameraManager() {
    stopPreview();
    stopRecording();
    cleanupNamedPipe();
}

bool CameraManager::createNamedPipe(const QString &pipePath) {
#ifdef _WIN32
    // Live capture requires Pi hardware (rpicam-vid + POSIX FIFOs). Desktop builds use Development Mode.
    Q_UNUSED(pipePath);
    qWarning() << "Live camera capture is not available on this platform - enable Development Mode";
    return false;
#else
    // Remove existing pipe if any
    unlink(pipePath.toLocal8Bit().constData());

    // Create named pipe (FIFO)
    if (mkfifo(pipePath.toLocal8Bit().constData(), 0666) == -1) {
        qWarning() << "Failed to create named pipe:" << strerror(errno);
        return false;
    }

    // qDebug() << "Created named pipe:" << pipePath;  // Suppress to reduce restart spam
    return true;
#endif
}

void CameraManager::cleanupNamedPipe() {
#ifndef _WIN32
    if (m_pipeFd >= 0) {
        close(m_pipeFd);
        m_pipeFd = -1;
    }

    if (!m_pipePath.isEmpty()) {
        unlink(m_pipePath.toLocal8Bit().constData());
    }
#endif
}

void CameraManager::setActiveCameraIndex(int index) {
    if (index < 0 || index > 1) {
        qWarning() << "Invalid camera index:" << index << "(must be 0 or 1)";
        return;
    }

    if (m_activeCameraIndex == index) {
        return;  // Already on this camera
    }

    qDebug() << "Switching camera from" << m_activeCameraIndex << "to" << index;

    // Remember if preview was active
    bool wasActive = m_previewActive.load();

    // Stop preview if active
    if (wasActive) {
        stopPreview();
    }

    // Change camera index
    m_activeCameraIndex = index;

    // Update FrameProvider rotation setting
    // Camera 0 = portrait (90° rotation), Camera 1 = landscape (no rotation)
    if (m_frameProvider) {
        m_frameProvider->setActiveCameraIndex(index);
    }

    emit activeCameraIndexChanged();

    // Restart preview if it was active
    if (wasActive) {
        startPreview();
    }
}

void CameraManager::setAutoExposureEnabled(bool enabled) {
    if (m_autoExposureEnabled == enabled) {
        return;
    }

    qDebug() << "Auto-exposure" << (enabled ? "ENABLED" : "DISABLED");
    m_autoExposureEnabled = enabled;

    if (enabled) {
        // Reset auto-exposure controller
        m_autoExposure.reset();
        m_framesSinceLastAdjustment = 0;
    }

    emit autoExposureEnabledChanged();
}

void CameraManager::restartPreviewWithExposure(int shutter, double gain) {
    if (!m_previewActive.load()) {
        return;
    }

    // SAFETY: Enforce minimum/maximum limits to prevent camera crashes
    // Shutter < 2000µs can cause crashes, > 33000µs causes motion blur
    const int MIN_SAFE_SHUTTER = 2000;
    const int MAX_SAFE_SHUTTER = 33000;
    const double MIN_SAFE_GAIN = 1.0;
    const double MAX_SAFE_GAIN = 16.0;

    shutter = std::max(MIN_SAFE_SHUTTER, std::min(MAX_SAFE_SHUTTER, shutter));
    gain = std::max(MIN_SAFE_GAIN, std::min(MAX_SAFE_GAIN, gain));

    // qDebug() << "Restarting camera with new exposure: Shutter=" << shutter << "µs Gain=" << gain;  // Suppress (logged in AUTO-EXPOSURE line)

    // Store new exposure values
    m_currentShutter = shutter;
    m_currentGain = gain;

    // Stop current preview
    stopPreview();

    // Give it a moment to clean up
    QThread::msleep(100);

    // Restart with new settings
    startPreview();

    emit exposureChanged();
}

void CameraManager::setSimulationMode(bool enabled) {
    if (m_simulationMode == enabled) {
        return;
    }

    // Restart preview cleanly if mode changes while running
    bool wasActive = m_previewActive.load();
    if (wasActive) {
        stopPreview();
    }

    m_simulationMode = enabled;
    m_simSourceImage.release();      // Re-check for placeholder images on next start
    m_simSourceCameraIndex = -1;
    emit simulationModeChanged();
    qDebug() << "Camera simulation mode" << (enabled ? "ENABLED" : "DISABLED");

    if (wasActive) {
        startPreview();
    }
}

void CameraManager::generateSimulatedFrame() {
    const int width = m_previewWidth;
    const int height = m_previewHeight;

    // Optional user-supplied placeholder: drop a real capture at
    // ~/Pictures/PRGR_DevFrames/cam0.png (or cam1.png) and it replaces the synthetic scene
    if (m_simSourceCameraIndex != m_activeCameraIndex) {
        m_simSourceImage.release();
        m_simSourceCameraIndex = m_activeCameraIndex;

        QString placeholderPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
                                  + QString("/PRGR_DevFrames/cam%1.png").arg(m_activeCameraIndex);
        if (QFile::exists(placeholderPath)) {
            cv::Mat img = cv::imread(placeholderPath.toStdString(), cv::IMREAD_GRAYSCALE);
            if (!img.empty()) {
                cv::resize(img, m_simSourceImage, cv::Size(width, height));
                qDebug() << "Dev mode: using placeholder image" << placeholderPath;
            }
        }
    }

    cv::Mat frame;
    if (!m_simSourceImage.empty()) {
        frame = m_simSourceImage.clone();
    } else {
        // Synthetic scene: dark mat, white ball with fiducial dots, slow idle drift
        frame = cv::Mat(height, width, CV_8UC1, cv::Scalar(45));

        // Hitting mat area (lighter band across lower third)
        cv::rectangle(frame, cv::Point(0, height * 2 / 3), cv::Point(width, height),
                      cv::Scalar(70), cv::FILLED);

        // Ball: ~75 px diameter (8mm lens @ 5ft per optics guide), gentle bob
        const int ballRadius = 38;
        const int cx = width / 2 + static_cast<int>(8.0 * std::sin(m_simPhase * 0.3));
        const int cy = height * 2 / 3 - ballRadius + static_cast<int>(3.0 * std::sin(m_simPhase));
        cv::circle(frame, cv::Point(cx, cy), ballRadius, cv::Scalar(230), cv::FILLED);
        cv::circle(frame, cv::Point(cx, cy), ballRadius, cv::Scalar(120), 2);

        // Fiducial dots rotating slowly around the ball face (RPT-style)
        for (int i = 0; i < 5; i++) {
            double angle = m_simPhase * 0.5 + i * (2.0 * CV_PI / 5.0);
            int dx = static_cast<int>(ballRadius * 0.55 * std::cos(angle));
            int dy = static_cast<int>(ballRadius * 0.55 * std::sin(angle));
            cv::circle(frame, cv::Point(cx + dx, cy + dy), 4, cv::Scalar(30), cv::FILLED);
        }

        cv::putText(frame, "DEV MODE - SIMULATED", cv::Point(10, 24),
                    cv::FONT_HERSHEY_SIMPLEX, 0.55, cv::Scalar(200), 1);
        cv::putText(frame, QString("CAM %1").arg(m_activeCameraIndex).toStdString(),
                    cv::Point(10, 48), cv::FONT_HERSHEY_SIMPLEX, 0.55, cv::Scalar(200), 1);
    }

    m_simPhase += 0.1;

    if (m_frameProvider) {
        m_frameProvider->updateFrame(frame);
        emit frameReady();
    }

    // FPS tracking (same cadence as the real preview loop)
    m_fpsFrameCount++;
    auto now = std::chrono::steady_clock::now();
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - m_fpsLastUpdate).count();
    if (elapsed >= FPS_UPDATE_INTERVAL_MS) {
        m_currentFPS = (m_fpsFrameCount * 1000.0) / elapsed;
        emit fpsChanged();
        m_fpsFrameCount = 0;
        m_fpsLastUpdate = now;
    }
}

void CameraManager::startPreview() {
    if (m_previewActive.load()) {
        qWarning() << "Preview already active";
        return;
    }

    // ═══ DEVELOPMENT MODE: simulated frames, no rpicam-vid / hardware ═══
    if (m_simulationMode) {
        m_previewWidth = 640;
        m_previewHeight = 480;

        if (!m_simTimer) {
            m_simTimer = new QTimer(this);
            connect(m_simTimer, &QTimer::timeout, this, &CameraManager::generateSimulatedFrame);
        }
        m_simTimer->start(33);  // ~30 FPS display rate (matches real preview throttle)

        m_previewActive.store(true);
        emit previewActiveChanged();
        qDebug() << "Preview started in SIMULATION mode (camera" << m_activeCameraIndex << ", no hardware)";
        return;
    }

    // Load camera settings based on active camera index
    QString cameraPrefix = QString("camera%1").arg(m_activeCameraIndex);

    // Use current exposure values (for auto-exposure) or load from settings
    if (m_currentShutter == 0 || m_currentGain == 0) {
        // Increased defaults for better indoor lighting (was 4000µs/12.0x - too dark, brightness only 3.0/255)
        m_currentShutter = m_settings->getNumber(cameraPrefix + "/shutterSpeed", 8000);
        m_currentGain = m_settings->getDouble(cameraPrefix + "/gain", 16.0);
    }
    int shutterSpeed = m_currentShutter;
    double gain = m_currentGain;

    QString resolutionStr = m_settings->getString(cameraPrefix + "/resolution", "640x480");
    QString format = m_settings->getString(cameraPrefix + "/format", "YUV420");

    // Parse resolution
    QStringList resParts = resolutionStr.split('x');
    m_previewWidth = 320;
    m_previewHeight = 240;
    if (resParts.size() == 2) {
        m_previewWidth = resParts[0].toInt();
        m_previewHeight = resParts[1].toInt();
    }

    // IMPACT CAMERA (Camera 0) - High-speed spin capture configuration
    // Override for Camera 0: 640×480 @ 180 FPS (OPTIMAL - valid OV9281 VGA mode)
    if (m_activeCameraIndex == 0) {
        m_previewWidth = 640;   // VGA width (→ vertical after 90° rotation)
        m_previewHeight = 480;  // VGA height for 180 FPS (→ horizontal after 90° rotation)
    }

    // Determine frame rate based on resolution (OV9281 valid modes only)
    int frameRate = 120;  // Safe default
    if (m_previewWidth == 640 && m_previewHeight == 480) {
        frameRate = 180;  // VGA @ 180 FPS - OPTIMAL for golf ball tracking (OV9281 native mode)
    } else if (m_previewWidth == 1280 && m_previewHeight == 800) {
        frameRate = 115;  // Full resolution @ 115 FPS (max for OV9281)
    } else if (m_previewWidth == 320 && m_previewHeight == 240) {
        frameRate = 240;  // QVGA @ 240 FPS - maximum speed (valid OV9281 mode)
    } else {
        frameRate = 60;   // Conservative fallback for unknown resolutions
    }

    // CRITICAL: Shutter speed must be less than frame interval
    // Frame interval = 1000000µs / FPS
    int maxShutter = (1000000 / frameRate) - 100;  // Leave 100µs margin
    if (shutterSpeed > maxShutter) {
        qWarning() << "⚠️ Shutter speed" << shutterSpeed << "µs exceeds frame interval at" << frameRate
                   << "FPS. Capping to" << maxShutter << "µs";
        shutterSpeed = maxShutter;
        m_currentShutter = shutterSpeed;  // Update stored value
    }

    // SAFETY: Also set minimum shutter to avoid camera issues
    const int minShutter = 100;  // 100µs minimum
    if (shutterSpeed < minShutter) {
        qWarning() << "⚠️ Shutter speed" << shutterSpeed << "µs too low. Setting to" << minShutter << "µs";
        shutterSpeed = minShutter;
        m_currentShutter = shutterSpeed;
    }

    // SAFETY: Clamp gain to valid range (1.0 - 16.0 for most sensors)
    if (gain < 1.0) {
        qWarning() << "⚠️ Gain" << gain << "too low. Setting to 1.0";
        gain = 1.0;
        m_currentGain = gain;
    }
    if (gain > 16.0) {
        qWarning() << "⚠️ Gain" << gain << "too high. Capping to 16.0";
        gain = 16.0;
        m_currentGain = gain;
    }

    // Only log camera start during initial startup or manual changes (reduce auto-exposure restart spam)
    static bool firstStart = true;
    if (firstStart) {
        qDebug() << "Starting preview: Camera" << m_activeCameraIndex
                 << "- Resolution=" << m_previewWidth << "x" << m_previewHeight
                 << "Format=" << format << "Shutter=" << shutterSpeed << "µs"
                 << "Gain=" << gain << "x FPS=" << frameRate;
        firstStart = false;
    }

    // Create named pipe
    if (!createNamedPipe(m_pipePath)) {
        emit errorOccurred("Failed to create named pipe");
        return;
    }

    // Start rpicam-vid to output YUV420 to pipe
    m_previewProcess = new QProcess(this);

    QStringList args;
    args << "--camera" << QString::number(m_activeCameraIndex);  // Select camera index
    args << "--timeout" << "0";  // No timeout

    // Camera-specific configurations
    if (m_activeCameraIndex == 0) {
        // ═══════════════════════════════════════════════════════════════════
        // IMPACT CAMERA (Camera 0) - High-speed ball tracking @ 180 FPS
        // ═══════════════════════════════════════════════════════════════════
        //
        // Physical: 90° LEFT rotation, 7ft from ball, 12mm telephoto lens
        // Sensor output: 640×480 @ 180 FPS (VGA mode - OV9281 native, OPTIMAL)
        // NO digital crop - full sensor utilization
        // Real-world view: 480×640 portrait (after 90° rotation)
        // Ball size: ~34-40 px diameter (17-20 px radius)

        args << "--width" << QString::number(m_previewWidth);    // 640
        args << "--height" << QString::number(m_previewHeight);  // 480
        args << "--framerate" << QString::number(frameRate);     // 180 FPS
        args << "--shutter" << QString::number(shutterSpeed);
        args << "--gain" << QString::number(gain);
        args << "--codec" << "yuv420";  // YUV420, extract Y (luma) for grayscale

        qDebug() << "IMPACT CAMERA (Cam 0): Sensor" << m_previewWidth << "x" << m_previewHeight
                 << "@ " << frameRate << "FPS (VGA native mode)";
    } else if (m_activeCameraIndex == 1) {
        // ═══════════════════════════════════════════════════════════════════
        // TRACKING CAMERA (Camera 1) - Ball flight trajectory
        // ═══════════════════════════════════════════════════════════════════
        //
        // Purpose: Track ball launch, flight path, landing
        // Resolution: 640×480 or 1280×800 (lower FPS ok, need full trajectory)
        // NOTE: --roi removed - it causes black screen / software scaling issues
        args << "--width" << QString::number(m_previewWidth);
        args << "--height" << QString::number(m_previewHeight);
        args << "--framerate" << QString::number(frameRate);
        args << "--shutter" << QString::number(shutterSpeed);
        args << "--gain" << QString::number(gain);

        // NO ROI - use full sensor (--roi causes rpicam-vid to crash/black screen)
        args << "--codec" << "yuv420";  // YUV420 (color or convert to grayscale)
        qDebug() << "TRACKING CAMERA (Cam 1): YUV420, Full sensor @" << frameRate << "FPS";
    } else {
        // Default for any other camera
        args << "--width" << QString::number(m_previewWidth);
        args << "--height" << QString::number(m_previewHeight);
        args << "--framerate" << QString::number(frameRate);
        args << "--shutter" << QString::number(shutterSpeed);
        args << "--gain" << QString::number(gain);
        args << "--codec" << "yuv420";
    }

    args << "--output" << m_pipePath;  // Output to named pipe
    args << "--nopreview";  // No X11 preview window

    qDebug() << "📹 rpicam-vid command: rpicam-vid" << args.join(" ");

    // Monitor process errors
    connect(m_previewProcess, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        qWarning() << "Preview process error:" << error;
        if (m_previewActive.load()) {
            m_previewActive.store(false);
            emit errorOccurred("Camera preview process crashed");
        }
    });

    connect(m_previewProcess, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus exitStatus) {
        QString stderr_output = m_previewProcess->readAllStandardError();
        qWarning() << "Preview process finished unexpectedly - exit code:" << exitCode << "status:" << exitStatus;
        if (!stderr_output.isEmpty()) {
            qWarning() << "rpicam-vid stderr:" << stderr_output;
        }
        if (m_previewActive.load()) {
            m_previewActive.store(false);
            emit errorOccurred("Camera preview stopped unexpectedly");
        }
    });

    // Merge stderr to stdout so we can see error messages
    m_previewProcess->setProcessChannelMode(QProcess::MergedChannels);

    m_previewProcess->start("rpicam-vid", args);

    if (!m_previewProcess->waitForStarted(5000)) {
        emit errorOccurred("Failed to start rpicam-vid");
        delete m_previewProcess;
        m_previewProcess = nullptr;
        cleanupNamedPipe();
        return;
    }

    // qDebug() << "rpicam-vid started, opening pipe for reading...";  // Suppress spam

    // Start preview thread to read from pipe
    m_previewActive.store(true);
    m_previewThread = new PreviewThread(this);
    m_previewThread->start();

    emit previewActiveChanged();
    // qDebug() << "Preview active";  // Suppress spam
}

void CameraManager::stopPreview() {
    if (!m_previewActive.load()) {
        return;
    }

    // qDebug() << "Stopping preview...";  // Suppress spam
    m_previewActive.store(false);

    // Development Mode: just stop the frame timer
    if (m_simTimer && m_simTimer->isActive()) {
        m_simTimer->stop();
        emit previewActiveChanged();
        return;
    }

    // Wait for thread to finish
    if (m_previewThread) {
        m_previewThread->wait(2000);
        delete m_previewThread;
        m_previewThread = nullptr;
    }

    // Stop rpicam-vid process
    if (m_previewProcess) {
        m_previewProcess->terminate();
        if (!m_previewProcess->waitForFinished(2000)) {
            m_previewProcess->kill();
            m_previewProcess->waitForFinished(1000);
        }
        delete m_previewProcess;
        m_previewProcess = nullptr;
    }

    // Cleanup pipe
    cleanupNamedPipe();

    emit previewActiveChanged();
    // qDebug() << "Preview stopped";  // Suppress spam
}

void CameraManager::previewLoop() {
#ifdef _WIN32
    // POSIX pipe I/O is unavailable on Windows; simulation mode bypasses this loop entirely.
    m_previewActive.store(false);
    emit errorOccurred("Live camera preview requires Raspberry Pi hardware - enable Development Mode");
    return;
#else
    // qDebug() << "Preview loop starting, opening pipe for reading...";  // Suppress spam

    // Open pipe for reading (blocks until rpicam-vid opens it for writing)
    m_pipeFd = open(m_pipePath.toLocal8Bit().constData(), O_RDONLY);
    if (m_pipeFd < 0) {
        qWarning() << "Failed to open pipe:" << strerror(errno);
        m_previewActive.store(false);
        emit errorOccurred("Failed to open camera pipe");
        return;
    }

    // qDebug() << "Pipe opened, starting frame capture loop...";  // Suppress spam

    // Calculate frame size for YUV420
    // YUV420: Y (width*height) + U (width/2*height/2) + V (width/2*height/2)
    // Total = width*height*1.5
    const int frameSize = m_previewWidth * m_previewHeight * 3 / 2;

    std::vector<uint8_t> frameBuffer(frameSize);
    int frameCount = 0;
    int fpsCounter = 0;
    auto fpsStart = std::chrono::steady_clock::now();

    // Throttle display updates to 30 FPS to reduce QML overhead
    auto lastDisplayUpdate = std::chrono::steady_clock::now();
    const int displayUpdateIntervalMs = 33; // ~30 FPS for display

    while (m_previewActive.load()) {
        // Read one complete frame from pipe
        ssize_t bytesRead = 0;
        ssize_t totalRead = 0;

        while (totalRead < frameSize && m_previewActive.load()) {
            bytesRead = read(m_pipeFd, frameBuffer.data() + totalRead, frameSize - totalRead);

            if (bytesRead < 0) {
                if (errno == EINTR) {
                    continue;  // Interrupted, retry
                }
                qWarning() << "Pipe read error:" << strerror(errno);
                m_previewActive.store(false);
                break;
            } else if (bytesRead == 0) {
                // EOF - rpicam-vid closed pipe
                qDebug() << "Pipe EOF - rpicam-vid stopped";
                m_previewActive.store(false);
                break;
            }

            totalRead += bytesRead;
        }

        if (totalRead != frameSize) {
            qWarning() << "Incomplete frame read:" << totalRead << "bytes (expected" << frameSize << ")";
            continue;
        }

        // Extract Y channel from YUV420 (grayscale)
        cv::Mat frame = extractYChannelFromYUV420(frameBuffer.data(), m_previewWidth, m_previewHeight);

        // NO DIGITAL ZOOM - Use full 640×400 sensor (Rapsodo-style)
        // Full sensor: Maximum field of view for trajectory tracking
        // After 90° rotation: 400×640 portrait
        // Ball: ~30-33 px diameter @ 240 FPS (optimal for HoughCircles detection)

        // Debug first few frames (suppressed - too spammy during restarts)
        // if (frameCount < 3) {
        //     double minVal, maxVal;
        //     cv::minMaxLoc(frame, &minVal, &maxVal);
        //     qDebug() << "Frame" << frameCount << "shape:" << frame.cols << "x" << frame.rows
        //              << "type:" << frame.type() << "min/max:" << minVal << "/" << maxVal;
        // }
        frameCount++;

        // Update frame provider (thread-safe)
        // Always update the frame buffer for CaptureManager (120 FPS)
        if (m_frameProvider) {
            m_frameProvider->updateFrame(frame);

            // Only signal QML display updates at 30 FPS to reduce overhead
            auto now = std::chrono::steady_clock::now();
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - lastDisplayUpdate).count();
            if (elapsed >= displayUpdateIntervalMs) {
                emit frameReady();  // Notify QML to refresh
                lastDisplayUpdate = now;
            }
        }

        // ========== AUTO-EXPOSURE CONTROL ==========
        if (m_autoExposureEnabled && frameCount > 180) {  // Wait 1 second (180 frames) for camera to stabilize
            m_framesSinceLastAdjustment++;

            // Check every 30 frames (~0.16s at 180fps) to avoid excessive adjustments
            if (m_framesSinceLastAdjustment >= ADJUST_INTERVAL_FRAMES) {
                m_framesSinceLastAdjustment = 0;

                // Measure brightness and get adjustment recommendation
                auto result = m_autoExposure.update(frame.data, frame.cols, frame.rows, frame.step);

                if (result.adjusted) {
                    // CRITICAL: Prevent restart loop - minimum 5 seconds between camera restarts
                    static qint64 lastRestartTime = 0;
                    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
                    qint64 timeSinceLastRestart = currentTime - lastRestartTime;

                    if (timeSinceLastRestart < 5000 && lastRestartTime != 0) {
                        // Too soon - skip this adjustment to prevent restart loop
                        // Camera needs time to stabilize before checking brightness again
                        return;
                    }

                    // Throttle logging to every 5 seconds (avoid terminal spam)
                    static qint64 lastLogTime = 0;
                    if (currentTime - lastLogTime > 5000 || lastLogTime == 0) {
                        qDebug() << "AUTO-EXPOSURE: Brightness=" << result.brightness
                                 << "→ Shutter" << result.shutter_us << "µs Gain" << result.gain;
                        lastLogTime = currentTime;
                    }

                    // Restart camera with new exposure settings
                    lastRestartTime = currentTime;
                    QMetaObject::invokeMethod(this, [this, result]() {
                        restartPreviewWithExposure(result.shutter_us, result.gain);
                    }, Qt::QueuedConnection);
                }
            }
        }

        // FPS tracking (update every 1 second for GUI display)
        m_fpsFrameCount++;
        auto fpsNow = std::chrono::steady_clock::now();
        auto fpsElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(fpsNow - m_fpsLastUpdate).count();
        if (fpsElapsed >= FPS_UPDATE_INTERVAL_MS) {
            m_currentFPS = (m_fpsFrameCount * 1000.0) / fpsElapsed;  // Calculate actual FPS
            emit fpsChanged();
            m_fpsFrameCount = 0;
            m_fpsLastUpdate = fpsNow;
        }

        // Debug log every 5 seconds (reduced spam)
        fpsCounter++;
        auto logElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(fpsNow - fpsStart).count();
        if (logElapsed >= 5000) {
            qDebug() << "Camera" << m_activeCameraIndex << "FPS:" << m_currentFPS;
            fpsCounter = 0;
            fpsStart = fpsNow;
        }
    }

    // qDebug() << "Preview loop exiting";  // Suppress spam

    if (m_pipeFd >= 0) {
        close(m_pipeFd);
        m_pipeFd = -1;
    }
#endif
}

cv::Mat CameraManager::extractYChannelFromYUV420(const uint8_t *data, int width, int height) {
    // YUV420 format: Y plane (height × width), then U plane (height/2 × width/2), then V plane
    // For grayscale, we only need the Y plane (first height × width bytes)

    // Create Mat from Y channel data (make a copy since data will be reused)
    cv::Mat yChannel(height, width, CV_8UC1);
    memcpy(yChannel.data, data, width * height);

    return yChannel;
}

void CameraManager::startRecording() {
    if (m_recordingActive) {
        qWarning() << "Recording already active";
        return;
    }

    if (m_simulationMode) {
        emit errorOccurred("Recording unavailable in Development Mode (no camera hardware)");
        return;
    }

    // Stop preview if running
    if (m_previewActive.load()) {
        qDebug() << "Stopping preview before recording...";
        stopPreview();
        QThread::msleep(500);
    }

    // Load settings from Camera Settings screen
    int frameRate = m_settings->cameraFrameRate();
    int shutterSpeed = m_settings->cameraShutterSpeed();
    double gain = m_settings->cameraGain();
    QString resolutionStr = m_settings->cameraResolution();

    // Parse resolution
    QStringList resParts = resolutionStr.split('x');
    int width = 640;
    int height = 480;
    if (resParts.size() == 2) {
        width = resParts[0].toInt();
        height = resParts[1].toInt();
    }

    // Generate filename
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString videosPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + "/PRGR_Videos";
    QString filename = QString("video_%1.mp4").arg(timestamp);
    QString filepath = videosPath + "/" + filename;

    qDebug() << "Starting recording to:" << filepath;

    // Ensure directory exists
    QDir().mkpath(videosPath);

    // Start rpicam-vid process for recording
    m_recordingProcess = new QProcess(this);

    // Capture process output for debugging
    m_recordingProcess->setProcessChannelMode(QProcess::MergedChannels);
    connect(m_recordingProcess, &QProcess::readyReadStandardOutput, this, [this]() {
        QString output = m_recordingProcess->readAllStandardOutput();
        qDebug() << "rpicam-vid output:" << output.trimmed();
    });

    QStringList args;
    args << "-t" << "0";  // No timeout (manual stop)
    args << "--width" << QString::number(width);
    args << "--height" << QString::number(height);
    args << "--framerate" << QString::number(frameRate);
    args << "--shutter" << QString::number(shutterSpeed);
    args << "--gain" << QString::number(gain);
    args << "--codec" << "h264";
    args << "-o" << filepath;
    args << "-n";  // No preview

    qDebug() << "Recording at" << frameRate << "FPS with shutter" << shutterSpeed << "µs gain" << gain;
    qDebug() << "rpicam-vid recording args:" << args.join(" ");

    m_recordingProcess->start("rpicam-vid", args);

    if (!m_recordingProcess->waitForStarted(5000)) {
        QString error = m_recordingProcess->errorString();
        qCritical() << "Failed to start recording process:" << error;
        qCritical() << "Process error:" << m_recordingProcess->readAllStandardError();
        emit errorOccurred("Failed to start recording: " + error);
        delete m_recordingProcess;
        m_recordingProcess = nullptr;
        return;
    }

    m_currentRecordingPath = filepath;
    m_recordingActive = true;
    emit recordingActiveChanged();
    qDebug() << "Recording started - PID:" << m_recordingProcess->processId();
}

void CameraManager::stopRecording() {
    if (!m_recordingActive || !m_recordingProcess) {
        return;
    }

    qDebug() << "Stopping recording...";

    // Send SIGINT (Ctrl+C) for graceful shutdown to finalize MP4 properly
    // Using terminate() which sends SIGTERM - rpicam-vid handles this gracefully
    m_recordingProcess->terminate();

    // Wait up to 5 seconds for graceful shutdown
    if (!m_recordingProcess->waitForFinished(5000)) {
        qWarning() << "Recording process didn't stop gracefully, forcing kill";
        m_recordingProcess->kill();
        m_recordingProcess->waitForFinished(2000);
    }

    qDebug() << "Recording process exit code:" << m_recordingProcess->exitCode();
    qDebug() << "Recording process output:" << m_recordingProcess->readAll();

    delete m_recordingProcess;
    m_recordingProcess = nullptr;

    m_recordingActive = false;
    emit recordingActiveChanged();

    // Wait for file system flush
    QThread::msleep(1000);

    // Check if file was created and has content
    QFileInfo fileInfo(m_currentRecordingPath);
    if (fileInfo.exists()) {
        qint64 fileSize = fileInfo.size();
        qDebug() << "Recording saved:" << m_currentRecordingPath << "Size:" << fileSize << "bytes";

        if (fileSize > 0) {
            emit recordingSaved(m_currentRecordingPath);
        } else {
            qWarning() << "Recording file is empty (0 bytes)!";
            emit errorOccurred("Recording failed - file is empty");
        }
    } else {
        qWarning() << "Recording file was not created!";
        emit errorOccurred("Recording failed - file not created");
    }

    // Restart preview
    qDebug() << "Restarting preview after recording...";
    QThread::msleep(500);
    startPreview();

    qDebug() << "Recording stopped";
}

void CameraManager::takeSnapshot() {
    qDebug() << "Taking snapshot...";

    // Development Mode: save the current simulated frame directly
    if (m_simulationMode) {
        QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
        QString snapshotsPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + "/PRGR_Snapshots";
        QDir().mkpath(snapshotsPath);
        QString filepath = snapshotsPath + QString("/snapshot_sim_%1.jpg").arg(timestamp);

        cv::Mat frame = m_frameProvider ? m_frameProvider->getLatestFrame() : cv::Mat();
        if (!frame.empty() && cv::imwrite(filepath.toStdString(), frame)) {
            qDebug() << "Simulated snapshot saved:" << filepath;
            emit snapshotCaptured(filepath);
        } else {
            emit errorOccurred("Snapshot failed (no simulated frame available)");
        }
        return;
    }

    bool previewWasRunning = m_previewActive.load();

    // Stop preview if running
    if (previewWasRunning) {
        stopPreview();
        QThread::msleep(500);
    }

    // Generate filename
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString snapshotsPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation) + "/PRGR_Snapshots";
    QDir().mkpath(snapshotsPath);
    QString filename = QString("snapshot_%1.jpg").arg(timestamp);
    QString filepath = snapshotsPath + "/" + filename;

    // Use rpicam-still for snapshot
    QProcess stillProcess;
    QStringList args;
    args << "--output" << filepath;
    args << "--timeout" << "1";  // 1ms timeout (immediate capture)
    args << "--nopreview";

    stillProcess.start("rpicam-still", args);

    if (stillProcess.waitForFinished(5000)) {
        qDebug() << "Snapshot saved:" << filepath;
        emit snapshotCaptured(filepath);
    } else {
        qWarning() << "Snapshot failed";
        emit errorOccurred("Snapshot capture failed");
    }

    // Restart preview
    if (previewWasRunning) {
        QThread::msleep(500);
        startPreview();
    }
}
void CameraManager::takeSnapshotBurst(int count) {
    qDebug() << "Taking" << count << "burst snapshots with GIF creation...";

    if (!m_frameProvider) {
        qWarning() << "No frame provider available";
        return;
    }

    // Generate folder name with timestamp
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString burstPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation)
                        + "/PRGR_Snapshots/burst_" + timestamp;
    QDir().mkpath(burstPath);

    std::vector<cv::Mat> frames;

    qDebug() << "Capturing" << count << "frames at ~120 FPS...";

    // Capture frames from live preview
    for (int i = 0; i < count; i++) {
        // Get current frame from frame provider
        QImage qimg = m_frameProvider->requestImage("", nullptr, QSize());

        if (!qimg.isNull()) {
            // Convert QImage to cv::Mat
            cv::Mat frame(qimg.height(), qimg.width(), CV_8UC1);
            memcpy(frame.data, qimg.bits(), qimg.width() * qimg.height());

            frames.push_back(frame.clone());

            // Save individual frame as JPEG
            QString framePath = QString("%1/frame_%2.jpg").arg(burstPath).arg(i, 3, 10, QChar('0'));
            cv::imwrite(framePath.toStdString(), frame);
        }

        // Small delay for frame rate control (~120 FPS = 8ms)
        QThread::msleep(8);
    }

    qDebug() << "Captured" << frames.size() << "frames, creating GIF...";

    // Create GIF from captured frames
    QString gifPath = burstPath + "/burst_animation.gif";

    if (!frames.empty()) {
        // Use ffmpeg to create GIF from JPEG sequence
        QProcess ffmpeg;
        QStringList args;
        args << "-framerate" << "30";  // 30 FPS for smooth playback
        args << "-pattern_type" << "glob";
        args << "-i" << burstPath + "/frame_*.jpg";
        args << "-vf" << "scale=320:-1:flags=lanczos";
        args << "-y";  // Overwrite
        args << gifPath;

        ffmpeg.start("ffmpeg", args);
        if (ffmpeg.waitForFinished(10000)) {
            qDebug() << "✓ GIF created:" << gifPath;
        } else {
            qDebug() << "Note: ffmpeg not available or failed. Frames saved as JPEGs.";
        }
    }

    qDebug() << "✓ Burst snapshot complete!";
    qDebug() << "  " << frames.size() << "frames saved to:" << burstPath;
    if (QFile::exists(gifPath)) {
        qDebug() << "  GIF created:" << gifPath;
    }

    emit snapshotCaptured(burstPath);
}
