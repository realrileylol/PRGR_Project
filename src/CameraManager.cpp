#include "CameraManager.h"
#include <QDebug>
#include <QDateTime>
#include <QDir>
#include <QStandardPaths>
#include <libcamera/control_ids.h>
#include <libcamera/property_ids.h>
#include <sys/mman.h>
#include <chrono>
#include <thread>

using namespace libcamera;

CameraManager::CameraManager(FrameProvider *frameProvider, SettingsManager *settings, QObject *parent)
    : QObject(parent)
    , m_frameProvider(frameProvider)
    , m_settings(settings)
    , m_cameraManager(nullptr)
    , m_camera(nullptr)
    , m_allocator(nullptr)
    , m_config(nullptr)
    , m_previewThread(nullptr)
    , m_previewActive(false)
    , m_recordingProcess(nullptr)
    , m_recordingActive(false)
{
    // Create videos folder
    QString videosPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + "/PRGR_Videos";
    QDir().mkpath(videosPath);
}

CameraManager::~CameraManager() {
    stopPreview();
    stopRecording();

    if (m_camera) {
        m_camera->release();
        m_camera.reset();
    }

    if (m_cameraManager) {
        m_cameraManager->stop();
        m_cameraManager.reset();
    }
}

void CameraManager::startPreview() {
    if (m_previewActive.load()) {
        qWarning() << "Preview already active";
        return;
    }

    // Initialize libcamera if not already done
    if (!m_cameraManager) {
        m_cameraManager = std::make_unique<CameraManager>();
        int ret = m_cameraManager->start();
        if (ret) {
            emit errorOccurred("Failed to start camera manager");
            return;
        }
    }

    // Get camera
    if (m_cameraManager->cameras().empty()) {
        emit errorOccurred("No cameras available");
        return;
    }

    m_camera = m_cameraManager->cameras()[0];
    if (m_camera->acquire()) {
        emit errorOccurred("Failed to acquire camera");
        return;
    }

    qDebug() << "Camera acquired:" << QString::fromStdString(m_camera->id());

    // Start preview thread
    m_previewActive.store(true);
    m_previewThread = new PreviewThread(this);
    m_previewThread->start();

    emit previewActiveChanged();
}

void CameraManager::stopPreview() {
    if (!m_previewActive.load()) {
        return;
    }

    qDebug() << "Stopping preview...";
    m_previewActive.store(false);

    if (m_previewThread) {
        m_previewThread->wait(2000);
        delete m_previewThread;
        m_previewThread = nullptr;
    }

    if (m_camera) {
        m_camera->stop();
        m_camera->release();
        m_camera.reset();
    }

    emit previewActiveChanged();
    qDebug() << "Preview stopped";
}

void CameraManager::previewLoop() {
    qDebug() << "Preview loop starting...";

    // Load camera settings
    int shutterSpeed = m_settings->cameraShutterSpeed();
    double gain = m_settings->cameraGain();
    QString resolutionStr = m_settings->cameraResolution();
    QString format = m_settings->cameraFormat();

    // Parse resolution
    QStringList resParts = resolutionStr.split('x');
    int width = 320, height = 240;
    if (resParts.size() == 2) {
        width = resParts[0].toInt();
        height = resParts[1].toInt();
    }

    // Determine frame rate based on resolution and format
    int frameRate = 120;  // Default high-speed
    if (format == "RAW") {
        frameRate = (width == 320 && height == 240) ? 120 : 60;
    } else {
        frameRate = (width == 320 && height == 240) ? 60 : 30;
    }

    qDebug() << "Preview settings: Resolution=" << width << "x" << height
             << "Format=" << format << "Shutter=" << shutterSpeed << "µs"
             << "Gain=" << gain << "x FPS=" << frameRate;

    // Configure camera
    // For RAW mode, use lores stream to bypass ISP
    m_config = m_camera->generateConfiguration({StreamRole::VideoRecording});
    if (!m_config) {
        emit errorOccurred("Failed to generate camera configuration");
        m_previewActive.store(false);
        return;
    }

    StreamConfiguration &streamConfig = m_config->at(0);

    if (format == "RAW") {
        // Use lores stream for direct sensor access (bypasses ISP)
        streamConfig.size.width = width;
        streamConfig.size.height = height;
        streamConfig.pixelFormat = formats::YUV420;  // OV9281 outputs YUV420
        streamConfig.bufferCount = 2;  // Minimal buffering
    } else {
        // Standard ISP-processed mode
        streamConfig.size.width = width;
        streamConfig.size.height = height;
        streamConfig.pixelFormat = formats::YUV420;
        streamConfig.bufferCount = 4;
    }

    // Validate and apply configuration
    CameraConfiguration::Status configStatus = m_config->validate();
    if (configStatus == CameraConfiguration::Invalid) {
        emit errorOccurred("Invalid camera configuration");
        m_previewActive.store(false);
        return;
    }

    if (m_camera->configure(m_config.get())) {
        emit errorOccurred("Failed to configure camera");
        m_previewActive.store(false);
        return;
    }

    qDebug() << "Camera configured: Stream size="
             << streamConfig.size.width << "x" << streamConfig.size.height
             << "Format=" << QString::fromStdString(streamConfig.pixelFormat.toString());

    // Allocate buffers
    m_allocator = std::make_unique<FrameBufferAllocator>(m_camera);
    Stream *stream = streamConfig.stream();

    int ret = m_allocator->allocate(stream);
    if (ret < 0) {
        emit errorOccurred("Failed to allocate buffers");
        m_previewActive.store(false);
        return;
    }

    qDebug() << "Allocated" << m_allocator->buffers(stream).size() << "buffers";

    // Set camera controls
    ControlList controls;
    controls.set(controls::FrameDurationLimits, Span<const int64_t, 2>({
        static_cast<int64_t>(1000000 / frameRate),  // Min frame duration (max FPS)
        static_cast<int64_t>(1000000 / frameRate)   // Max frame duration (min FPS)
    }));
    controls.set(controls::ExposureTime, shutterSpeed);
    controls.set(controls::AnalogueGain, static_cast<float>(gain));

    // Create requests
    std::vector<std::unique_ptr<Request>> requests;
    for (const std::unique_ptr<FrameBuffer> &buffer : m_allocator->buffers(stream)) {
        std::unique_ptr<Request> request = m_camera->createRequest();
        if (!request) {
            emit errorOccurred("Failed to create request");
            m_previewActive.store(false);
            return;
        }

        if (request->addBuffer(stream, buffer.get())) {
            emit errorOccurred("Failed to add buffer to request");
            m_previewActive.store(false);
            return;
        }

        request->controls() = controls;
        requests.push_back(std::move(request));
    }

    // Start camera
    if (m_camera->start()) {
        emit errorOccurred("Failed to start camera");
        m_previewActive.store(false);
        return;
    }

    qDebug() << "Camera started - entering preview loop";

    // Queue initial requests
    for (std::unique_ptr<Request> &request : requests) {
        m_camera->queueRequest(request.get());
    }

    // FPS tracking
    int fpsCounter = 0;
    auto fpsStart = std::chrono::steady_clock::now();
    int frameCount = 0;

    // Main preview loop
    while (m_previewActive.load()) {
        // Wait for completed request
        Request *request = nullptr;
        {
            // Simple polling for completed requests
            // In production, use camera's request completion signal
            std::this_thread::sleep_for(std::chrono::microseconds(1000));
            continue;  // TODO: Implement proper request completion handling
        }

        // Process frame
        FrameBuffer *buffer = request->buffers().begin()->second;
        const FrameBuffer::Plane &plane = buffer->planes()[0];

        // Map buffer to user space
        void *mem = mmap(nullptr, plane.length, PROT_READ, MAP_SHARED, plane.fd.get(), 0);
        if (mem == MAP_FAILED) {
            qWarning() << "Failed to mmap buffer";
            continue;
        }

        // Extract Y channel from YUV420 (if RAW mode)
        cv::Mat frame;
        if (format == "RAW") {
            frame = extractYChannelFromYUV420(static_cast<const uint8_t*>(mem), width, height);
        } else {
            // For non-RAW, also extract Y channel from YUV420
            frame = extractYChannelFromYUV420(static_cast<const uint8_t*>(mem), width, height);
        }

        munmap(mem, plane.length);

        // Debug first few frames
        if (frameCount < 3) {
            qDebug() << "Frame" << frameCount << "shape:" << frame.cols << "x" << frame.rows
                     << "type:" << frame.type() << "min/max:" <<
                     cv::minMaxLoc(frame).first << "/" << cv::minMaxLoc(frame).second;
        }
        frameCount++;

        // Update frame provider (thread-safe)
        if (m_frameProvider) {
            m_frameProvider->updateFrame(frame);
            emit frameReady();
        }

        // FPS tracking
        fpsCounter++;
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(now - fpsStart).count();
        if (elapsed >= 1000) {
            qDebug() << "Preview FPS:" << fpsCounter;
            fpsCounter = 0;
            fpsStart = now;
        }

        // Requeue request
        request->reuse(Request::ReuseBuffers);
        request->controls() = controls;
        m_camera->queueRequest(request);
    }

    qDebug() << "Preview loop exiting";
    m_camera->stop();
}

cv::Mat CameraManager::extractYChannelFromYUV420(const uint8_t *data, int width, int height) {
    // YUV420 format: Y plane (height × width), then U plane (height/2 × width/2), then V plane
    // For grayscale, we only need the Y plane (first height × width bytes)

    // Create Mat pointing to Y channel data
    cv::Mat yChannel(height, width, CV_8UC1, const_cast<uint8_t*>(data));

    // Return a copy (data will be unmapped after this function returns)
    return yChannel.clone();
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

    // Load settings
    int frameRate = m_settings->cameraFrameRate();
    int shutterSpeed = m_settings->cameraShutterSpeed();
    double gain = m_settings->cameraGain();

    // Generate filename
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString videosPath = QStandardPaths::writableLocation(QStandardPaths::MoviesLocation) + "/PRGR_Videos";
    QString filename = QString("video_%1.mp4").arg(timestamp);
    QString filepath = videosPath + "/" + filename;

    // Calculate bitrate (5 Mbps for Pi 4B)
    int bitrate = 5000000;

    qDebug() << "Starting recording to:" << filepath;

    // Start rpicam-vid process
    m_recordingProcess = new QProcess(this);

    QStringList args;
    args << "--timeout" << "0";  // No timeout (manual stop)
    args << "--width" << "640";
    args << "--height" << "480";
    args << "--framerate" << QString::number(frameRate);
    args << "--shutter" << QString::number(shutterSpeed);
    args << "--gain" << QString::number(gain);
    args << "--output" << filepath;
    args << "--codec" << "libav";
    args << "--libav-format" << "mp4";
    args << "--bitrate" << QString::number(bitrate);
    args << "--intra" << QString::number(frameRate);  // Keyframe interval
    args << "--profile" << "high";
    args << "--level" << "4.2";

    m_recordingProcess->start("rpicam-vid", args);

    if (!m_recordingProcess->waitForStarted(5000)) {
        emit errorOccurred("Failed to start recording process");
        delete m_recordingProcess;
        m_recordingProcess = nullptr;
        return;
    }

    m_recordingActive = true;
    emit recordingActiveChanged();
    qDebug() << "Recording started";
}

void CameraManager::stopRecording() {
    if (!m_recordingActive || !m_recordingProcess) {
        return;
    }

    qDebug() << "Stopping recording...";

    // Send SIGINT for graceful shutdown (allows MP4 finalization)
    m_recordingProcess->terminate();  // Sends SIGTERM, then SIGKILL if needed

    if (!m_recordingProcess->waitForFinished(5000)) {
        qWarning() << "Recording process did not finish, forcing kill";
        m_recordingProcess->kill();
        m_recordingProcess->waitForFinished(2000);
    }

    delete m_recordingProcess;
    m_recordingProcess = nullptr;

    m_recordingActive = false;
    emit recordingActiveChanged();

    // Wait for file system flush
    QThread::msleep(500);

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

    // TODO: Implement snapshot capture using libcamera still capture
    qDebug() << "Snapshot not yet implemented";
    emit errorOccurred("Snapshot feature not yet implemented");

    // Restart preview
    if (previewWasRunning) {
        QThread::msleep(500);
        startPreview();
    }
}
