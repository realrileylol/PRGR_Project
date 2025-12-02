#include "SettingsManager.h"
#include <QStandardPaths>
#include <QDir>

SettingsManager::SettingsManager(QObject *parent)
    : QObject(parent)
    , m_cameraShutterSpeed(8500)
    , m_cameraGain(5.0)
    , m_cameraFrameRate(120)
    , m_cameraResolution("320x240")
    , m_cameraFormat("RAW")
{
    // Use JSON format for human-readable settings
    QString settingsPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(settingsPath);

    m_settings = new QSettings(settingsPath + "/settings.json", QSettings::IniFormat, this);

    loadDefaults();
    load();
}

void SettingsManager::loadDefaults() {
    // Camera defaults optimized for OV9281 monochrome + 120 FPS
    m_settings->setValue("camera/shutterSpeed", 8500);      // 8.5ms for indoor
    m_settings->setValue("camera/gain", 5.0);               // Good indoor gain
    m_settings->setValue("camera/frameRate", 120);          // High-speed capture
    m_settings->setValue("camera/resolution", "320x240");   // 120+ FPS mode
    m_settings->setValue("camera/format", "RAW");           // Bypass ISP

    // Ball detection defaults
    m_settings->setValue("detection/minRadius", 5);
    m_settings->setValue("detection/maxRadius", 50);
    m_settings->setValue("detection/impactThreshold", 10);
    m_settings->setValue("detection/impactAxis", 1);        // Y-axis
    m_settings->setValue("detection/impactDirection", 1);   // Positive direction

    // K-LD2 radar defaults
    m_settings->setValue("kld2/minTriggerSpeed", 20.0);     // 20 mph minimum
    m_settings->setValue("kld2/debugMode", false);

    m_settings->sync();
}

void SettingsManager::load() {
    m_cameraShutterSpeed = m_settings->value("camera/shutterSpeed", 8500).toInt();
    m_cameraGain = m_settings->value("camera/gain", 5.0).toDouble();
    m_cameraFrameRate = m_settings->value("camera/frameRate", 120).toInt();
    m_cameraResolution = m_settings->value("camera/resolution", "320x240").toString();
    m_cameraFormat = m_settings->value("camera/format", "RAW").toString();

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
