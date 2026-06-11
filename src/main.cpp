#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDebug>

#include "SettingsManager.h"
#include "KLD2Manager.h"
#include "FrameProvider.h"
#include "CameraManager.h"
#include "CaptureManager.h"
#include "SoundManager.h"
#include "CalibrationManager.h"
#include "CameraCalibration.h"
#include "BallDetector.h"
#include "TrajectoryTracker.h"
#include "BallTracker.h"
#include "ProfileManager.h"
#include "HistoryManager.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    // Set application metadata
    app.setOrganizationName("PRGR");
    app.setOrganizationDomain("prgr.com");
    app.setApplicationName("Launch Monitor");

    // Set Qt Quick style
    QQuickStyle::setStyle("Material");

    // Create managers
    SettingsManager settingsManager;
    KLD2Manager kld2Manager;
    SoundManager soundManager;
    CalibrationManager calibrationManager;
    CameraCalibration cameraCalibration;
    BallDetector ballDetector;
    TrajectoryTracker trajectoryTracker;
    FrameProvider frameProvider;
    CameraManager cameraManager(&frameProvider, &settingsManager);
    CaptureManager captureManager(&kld2Manager, &settingsManager);
    BallTracker ballTracker(&cameraManager, &cameraCalibration);
    ProfileManager profileManager;
    HistoryManager historyManager;

    // Connect calibration manager to frame provider and settings
    calibrationManager.setFrameProvider(&frameProvider);
    calibrationManager.setSettings(&settingsManager);

    // Connect camera calibration to frame provider and settings
    cameraCalibration.setFrameProvider(&frameProvider);
    cameraCalibration.setSettings(&settingsManager);

    // NO DIGITAL ZOOM - Use full 640×480 sensor @ 180 FPS (OV9281 VGA mode - OPTIMAL)
    // Ball ~34-40 px diameter (17-20 px radius)
    cameraCalibration.setCropParameters(0, 0, 640, 480);

    // Connect ball detector to calibration
    ballDetector.setCalibration(&cameraCalibration);

    // Connect trajectory tracker to calibration and detector
    trajectoryTracker.setCalibration(&cameraCalibration);
    trajectoryTracker.setBallDetector(&ballDetector);

    // Connect ball tracker to radar for hybrid triggering (prevents false triggers from club)
    ballTracker.setRadar(&kld2Manager);
    ballTracker.setFrameProvider(&frameProvider);

    // Development Mode: simulated camera + radar, no hardware required
    // Toggled in Settings, persisted across restarts
    if (settingsManager.getBool("developer/developmentMode", false)) {
        cameraManager.setSimulationMode(true);
        kld2Manager.setSimulationMode(true);
        qDebug() << "⚠ DEVELOPMENT MODE ACTIVE: camera & radar are simulated";
    }

    // Create QML engine
    QQmlApplicationEngine engine;

    // Register image provider for camera frames
    engine.addImageProvider(QLatin1String("frameprovider"), &frameProvider);

    // Expose managers to QML
    engine.rootContext()->setContextProperty("settingsManager", &settingsManager);
    engine.rootContext()->setContextProperty("kld2Manager", &kld2Manager);
    engine.rootContext()->setContextProperty("soundManager", &soundManager);
    engine.rootContext()->setContextProperty("calibrationManager", &calibrationManager);
    engine.rootContext()->setContextProperty("cameraCalibration", &cameraCalibration);
    engine.rootContext()->setContextProperty("ballDetector", &ballDetector);
    engine.rootContext()->setContextProperty("trajectoryTracker", &trajectoryTracker);
    engine.rootContext()->setContextProperty("ballTracker", &ballTracker);
    engine.rootContext()->setContextProperty("cameraManager", &cameraManager);
    engine.rootContext()->setContextProperty("captureManager", &captureManager);
    engine.rootContext()->setContextProperty("profileManager", &profileManager);
    engine.rootContext()->setContextProperty("historyManager", &historyManager);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
            QCoreApplication::exit(-1);
        }
    }, Qt::QueuedConnection);

    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Failed to load QML";
        return -1;
    }

    qDebug() << "PRGR Launch Monitor started";
    qDebug() << "Qt version:" << qVersion();
    qDebug() << "✓ SettingsManager initialized";
    qDebug() << "✓ KLD2Manager initialized";
    qDebug() << "✓ CameraManager initialized (rpicam-vid @ 187 FPS)";
    qDebug() << "✓ CaptureManager initialized (hybrid radar + camera detection)";
    qDebug() << "✓ BallDetector initialized (multi-method with background subtraction)";
    qDebug() << "✓ TrajectoryTracker initialized (Kalman filter + launch angle)";
    qDebug() << "✓ BallTracker initialized (high-speed tracking with adaptive search)";
    qDebug() << "✓ CameraCalibration initialized (intrinsic + extrinsic)";
    qDebug() << "✓ ProfileManager initialized (JSON persistence)";
    qDebug() << "✓ HistoryManager initialized (shot history tracking)";

    return app.exec();
}
