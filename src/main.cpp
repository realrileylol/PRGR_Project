#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDebug>

#include "SettingsManager.h"
#include "KLD2Manager.h"
#include "FrameProvider.h"
// TODO: Implement these
// #include "CameraManager.h"
// #include "CaptureManager.h"

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
    FrameProvider frameProvider;

    // TODO: Create CameraManager and CaptureManager when implemented
    // CameraManager cameraManager(&frameProvider, &settingsManager);
    // CaptureManager captureManager(&kld2Manager, &settingsManager);

    // Create QML engine
    QQmlApplicationEngine engine;

    // Register image provider for camera frames
    engine.addImageProvider(QLatin1String("frameprovider"), &frameProvider);

    // Expose managers to QML
    engine.rootContext()->setContextProperty("settingsManager", &settingsManager);
    engine.rootContext()->setContextProperty("kld2Manager", &kld2Manager);
    // TODO: Expose camera and capture managers
    // engine.rootContext()->setContextProperty("cameraManager", &cameraManager);
    // engine.rootContext()->setContextProperty("captureManager", &captureManager);

    // Load main QML file
    const QUrl url(QStringLiteral("qrc:/screens/AppWindow.qml"));
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
    qDebug() << "Settings initialized";
    qDebug() << "K-LD2 manager initialized";

    return app.exec();
}
