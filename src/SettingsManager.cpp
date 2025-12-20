#include "SettingsManager.h"
#include <QStandardPaths>
#include <QDir>
#include <QFile>
#include <QDebug>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_cameraShutterSpeed(4000)
    , m_cameraGain(12.0)
    , m_cameraFrameRate(180)
    , m_cameraResolution("640x480")
    , m_cameraFormat("YUV420")
{
    // Use JSON format for human-readable settings
    QString settingsPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(settingsPath);

    QString fullPath = settingsPath + "/settings.json";
    bool settingsExist = QFile::exists(fullPath);
    m_settings = new QSettings(fullPath, QSettings::IniFormat, this);

    qDebug() << "Settings file location:" << fullPath;
    qDebug() << "Settings file exists:" << settingsExist;

    // Only write defaults if settings don't exist yet
    if (!settingsExist || !m_settings->contains("camera/shutterSpeed")) {
        qDebug() << "Creating default settings...";
        loadDefaults();
    }

    load();

    // Debug: Print loaded settings
    qDebug() << "Loaded camera settings:";
    qDebug() << "  FPS:" << m_cameraFrameRate;
    qDebug() << "  Gain:" << m_cameraGain;
    qDebug() << "  Shutter:" << m_cameraShutterSpeed;
    qDebug() << "  Format:" << m_cameraFormat;
}

void SettingsManager::loadDefaults() {
    // Camera 0 defaults (Top camera - ball tracking @ 180 FPS portrait mode)
    m_settings->setValue("camera0/shutterSpeed", 4000);      // 4ms for brightness
    m_settings->setValue("camera0/gain", 12.0);              // Higher gain for brightness
    m_settings->setValue("camera0/frameRate", 180);          // 180 FPS @ 640×480 (good zoom level)
    m_settings->setValue("camera0/resolution", "640x480");   // VGA - portrait mode = 480×640
    m_settings->setValue("camera0/format", "YUV420");        // Standard format

    // Camera 1 defaults (Bottom camera - launch angle @ 115 FPS)
    m_settings->setValue("camera1/shutterSpeed", 4000);      // 4ms for brightness (tune later)
    m_settings->setValue("camera1/gain", 12.0);              // Higher gain for brightness (tune later)
    m_settings->setValue("camera1/frameRate", 115);          // 115 FPS @ 1280×800 (max quality)
    m_settings->setValue("camera1/resolution", "1280x800");  // Full sensor resolution
    m_settings->setValue("camera1/format", "YUV420");        // Standard format

    // Legacy camera settings (for backward compatibility - map to camera0)
    m_settings->setValue("camera/shutterSpeed", 4000);
    m_settings->setValue("camera/gain", 12.0);
    m_settings->setValue("camera/frameRate", 180);
    m_settings->setValue("camera/resolution", "640x480");
    m_settings->setValue("camera/format", "YUV420");

    // Ball detection defaults (for 640×480 rotated to 480×640: ball is 8-12 pixels diameter)
    m_settings->setValue("detection/minRadius", 4);     // Minimum 4 pixel radius (8px diameter)
    m_settings->setValue("detection/maxRadius", 15);    // Maximum 15 pixel radius (30px diameter)
    m_settings->setValue("detection/impactThreshold", 10);
    m_settings->setValue("detection/impactAxis", 1);        // Y-axis
    m_settings->setValue("detection/impactDirection", 1);   // Positive direction

    // K-LD2 radar defaults
    m_settings->setValue("kld2/minTriggerSpeed", 20.0);     // 20 mph minimum
    m_settings->setValue("kld2/debugMode", false);

    m_settings->sync();
}

void SettingsManager::load() {
    m_cameraShutterSpeed = m_settings->value("camera/shutterSpeed", 4000).toInt();
    m_cameraGain = m_settings->value("camera/gain", 12.0).toDouble();
    m_cameraFrameRate = m_settings->value("camera/frameRate", 180).toInt();
    m_cameraResolution = m_settings->value("camera/resolution", "640x480").toString();
    m_cameraFormat = m_settings->value("camera/format", "YUV420").toString();

    emit settingsChanged();
}

void SettingsManager::save() {
    m_settings->setValue("camera/shutterSpeed", m_cameraShutterSpeed);
    m_settings->setValue("camera/gain", m_cameraGain);
    m_settings->setValue("camera/frameRate", m_cameraFrameRate);
    m_settings->setValue("camera/resolution", m_cameraResolution);
    m_settings->setValue("camera/format", m_cameraFormat);

    m_settings->sync();
    emit settingsChanged();
}

void SettingsManager::resetToDefaults() {
    loadDefaults();
    load();
}

// Camera settings getters
int SettingsManager::cameraShutterSpeed() const { return m_cameraShutterSpeed; }
double SettingsManager::cameraGain() const { return m_cameraGain; }
int SettingsManager::cameraFrameRate() const { return m_cameraFrameRate; }
QString SettingsManager::cameraResolution() const { return m_cameraResolution; }
QString SettingsManager::cameraFormat() const { return m_cameraFormat; }

// Camera settings setters
void SettingsManager::setCameraShutterSpeed(int value) {
    if (m_cameraShutterSpeed != value) {
        m_cameraShutterSpeed = value;
        m_settings->setValue("camera/shutterSpeed", value);
        m_settings->sync();
        emit settingsChanged();
    }
}

void SettingsManager::setCameraGain(double value) {
    if (m_cameraGain != value) {
        m_cameraGain = value;
        m_settings->setValue("camera/gain", value);
        m_settings->sync();
        emit settingsChanged();
    }
}

void SettingsManager::setCameraFrameRate(int value) {
    if (m_cameraFrameRate != value) {
        m_cameraFrameRate = value;
        m_settings->setValue("camera/frameRate", value);
        m_settings->sync();
        emit settingsChanged();
    }
}

void SettingsManager::setCameraResolution(const QString &value) {
    if (m_cameraResolution != value) {
        m_cameraResolution = value;
        m_settings->setValue("camera/resolution", value);
        m_settings->sync();
        emit settingsChanged();
    }
}

void SettingsManager::setCameraFormat(const QString &value) {
    if (m_cameraFormat != value) {
        m_cameraFormat = value;
        m_settings->setValue("camera/format", value);
        m_settings->sync();
        emit settingsChanged();
    }
}

// Generic get/set methods
QVariant SettingsManager::getValue(const QString &key, const QVariant &defaultValue) const {
    return m_settings->value(key, defaultValue);
}

void SettingsManager::setValue(const QString &key, const QVariant &value) {
    m_settings->setValue(key, value);
    m_settings->sync();
    emit settingsChanged();
}

// Type-specific getters
QString SettingsManager::getString(const QString &key, const QString &defaultValue) const {
    return m_settings->value(key, defaultValue).toString();
}

int SettingsManager::getNumber(const QString &key, int defaultValue) const {
    return m_settings->value(key, defaultValue).toInt();
}

double SettingsManager::getDouble(const QString &key, double defaultValue) const {
    return m_settings->value(key, defaultValue).toDouble();
}

bool SettingsManager::getBool(const QString &key, bool defaultValue) const {
    return m_settings->value(key, defaultValue).toBool();
}

// Type-specific setters
void SettingsManager::setString(const QString &key, const QString &value) {
    setValue(key, value);
}

void SettingsManager::setNumber(const QString &key, int value) {
    setValue(key, value);
}

void SettingsManager::setDouble(const QString &key, double value) {
    setValue(key, value);
}

void SettingsManager::setBool(const QString &key, bool value) {
    setValue(key, value);
}
