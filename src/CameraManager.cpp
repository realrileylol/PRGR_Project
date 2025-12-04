#include "CameraManager.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

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
{
    // Create videos folder
    QString videosPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + "/PRGR_Videos";
    QDir().mkpath(videosPath);
}

CameraManager::~CameraManager() {
    stopPreview();
    stopRecording();
    cleanupNamedPipe();
}

bool CameraManager::createNamedPipe(const QString &pipePath) {
    // Remove existing pipe if any
    unlink(pipePath.toLocal8Bit().constData());

    // Create named pipe (FIFO)
    if (mkfifo(pipePath.toLocal8Bit().constData(), 0666) == -1) {
        qWarning() << "Failed to create named pipe:" << strerror(errno);
        return false;
    }

    qDebug() << "Created named pipe:" << pipePath;
    return true;
}

void CameraManager::cleanupNamedPipe() {
    if (m_pipeFd >= 0) {
        close(m_pipeFd);
        m_pipeFd = -1;
    }

    if (!m_pipePath.isEmpty()) {
        unlink(m_pipePath.toLocal8Bit().constData());
    }
}

void CameraManager::startPreview() {
    if (m_previewActive.load()) {
        qWarning() << "Preview already active";
        return;
    }

    // Load camera settings
    int shutterSpeed = m_settings->cameraShutterSpeed();
    double gain = m_settings->cameraGain();
    QString resolutionStr = m_settings->cameraResolution();
    QString format = m_settings->cameraFormat();

    // Parse resolution
    QStringList resParts = resolutionStr.split('x');
    m_previewWidth = 320;
    m_previewHeight = 240;
    if (resParts.size() == 2) {
        m_previewWidth = resParts[0].toInt();
        m_previewHeight = resParts[1].toInt();
    }

    // Determine frame rate based on OV9281 resolution capabilities
    int frameRate = 120;  // Safe default
    if (m_previewWidth == 640 && m_previewHeight == 480) {
        frameRate = 180;  // VGA @ 180 FPS - OPTIMAL for golf ball tracking
    } else if (m_previewWidth == 640 && m_previewHeight == 400) {
        frameRate = 240;  // Wide VGA @ 240 FPS - maximum performance
    } else if (m_previewWidth == 1280 && m_previewHeight == 800) {
        frameRate = 120;  // Full resolution @ 120 FPS
    } else if (m_previewWidth == 320 && m_previewHeight == 240) {
        frameRate = 120;  // Low res high speed
    } else {
        frameRate = 60;   // Conservative fallback for unknown resolutions
    }

    qDebug() << "Starting preview: Resolution=" << m_previewWidth << "x" << m_previewHeight
             << "Format=" << format << "Shutter=" << shutterSpeed << "µs"
             << "Gain=" << gain << "x FPS=" << frameRate;

    // Create named pipe
    if (!createNamedPipe(m_pipePath)) {
        emit errorOccurred("Failed to create named pipe");
        return;
    }

    // Start rpicam-vid to output YUV420 to pipe
    m_previewProcess = new QProcess(this);

    QStringList args;
    args << "--timeout" << "0";  // No timeout
    args << "--width" << QString::number(m_previewWidth);
    args << "--height" << QString::number(m_previewHeight);
    args << "--framerate" << QString::number(frameRate);
    args << "--shutter" << QString::number(shutterSpeed);
    args << "--gain" << QString::number(gain);
    args << "--codec" << "yuv420";  // Raw YUV420 output
    args << "--output" << m_pipePath;  // Output to named pipe
    args << "--nopreview";  // No X11 preview window

    qDebug() << "Starting rpicam-vid with args:" << args.join(" ");

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
        qWarning() << "Preview process finished unexpectedly - exit code:" << exitCode << "status:" << exitStatus;
        if (m_previewActive.load()) {
            m_previewActive.store(false);
            emit errorOccurred("Camera preview stopped unexpectedly");
        }
    });

    m_previewProcess->start("rpicam-vid", args);

    if (!m_previewProcess->waitForStarted(5000)) {
        emit errorOccurred("Failed to start rpicam-vid");
        delete m_previewProcess;
        m_previewProcess = nullptr;
        cleanupNamedPipe();
        return;
    }

    qDebug() << "rpicam-vid started, opening pipe for reading...";

    // Start preview thread to read from pipe
    m_previewActive.store(true);
    m_previewThread = new PreviewThread(this);
    m_previewThread->start();

    emit previewActiveChanged();
    qDebug() << "Preview active";
}

void CameraManager::stopPreview() {
    if (!m_previewActive.load()) {
        return;
    }

    qDebug() << "Stopping preview...";
    m_previewActive.store(false);

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
    qDebug() << "Preview stopped";
}

void CameraManager::previewLoop() {
    qDebug() << "Preview loop starting, opening pipe for reading...";

    // Open pipe for reading (blocks until rpicam-vid opens it for writing)
    m_pipeFd = open(m_pipePath.toLocal8Bit().constData(), O_RDONLY);
    if (m_pipeFd < 0) {
        qWarning() << "Failed to open pipe:" << strerror(errno);
        m_previewActive.store(false);
        emit errorOccurred("Failed to open camera pipe");
        return;
    }

    qDebug() << "Pipe opened, starting frame capture loop...";

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

        // Extract Y channel from YUV420
        cv::Mat frame = extractYChannelFromYUV420(frameBuffer.data(), m_previewWidth, m_previewHeight);

        // Debug first few frames
        if (frameCount < 3) {
            double minVal, maxVal;
            cv::minMaxLoc(frame, &minVal, &maxVal);
            qDebug() << "Frame" << frameCount << "shape:" << frame.cols << "x" << frame.rows
                     << "type:" << frame.type() << "min/max:" << minVal << "/" << maxVal;
        }
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

        // FPS tracking
        fpsCounter++;
        auto fpsNow = std::chrono::steady_clock::now();
        auto fpsElapsed = std::chrono::duration_cast<std::chrono::milliseconds>(fpsNow - fpsStart).count();
        if (fpsElapsed >= 1000) {
            qDebug() << "Preview FPS:" << fpsCounter;
            fpsCounter = 0;
            fpsStart = fpsNow;
        }
    }

    qDebug() << "Preview loop exiting";

    if (m_pipeFd >= 0) {
        close(m_pipeFd);
        m_pipeFd = -1;
    }
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
