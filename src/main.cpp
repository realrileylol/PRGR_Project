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

    // Connect calibration manager to frame provider and settings
    calibrationManager.setFrameProvider(&frameProvider);
    calibrationManager.setSettings(&settingsManager);

    // Connect camera calibration to frame provider and settings
    cameraCalibration.setFrameProvider(&frameProvider);
    cameraCalibration.setSettings(&settingsManager);

    // Connect ball detector to calibration
    ballDetector.setCalibration(&cameraCalibration);

    // Connect trajectory tracker to calibration and detector
    trajectoryTracker.setCalibration(&cameraCalibration);
    trajectoryTracker.setBallDetector(&ballDetector);

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
    engine.rootContext()->setContextProperty("cameraManager", &cameraManager);
    engine.rootContext()->setContextProperty("captureManager", &captureManager);

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
    qDebug() << "✓ CameraManager initialized (rpicam-vid @ 180 FPS)";
    qDebug() << "✓ CaptureManager initialized (hybrid radar + camera detection)";
    qDebug() << "✓ BallDetector initialized (multi-method with background subtraction)";
    qDebug() << "✓ TrajectoryTracker initialized (Kalman filter + launch angle)";
    qDebug() << "✓ CameraCalibration initialized (intrinsic + extrinsic)";

    return app.exec();
}
