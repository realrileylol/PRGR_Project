#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariant>

/**
 * @brief Settings manager for persistent configuration storage
 *
 * Manages camera settings, calibration data, and user preferences.
 * Uses QSettings for cross-platform storage (JSON format).
 */
class SettingsManager : public QObject {
    Q_OBJECT

    // Expose settings as Q_PROPERTY for QML binding
    Q_PROPERTY(int cameraShutterSpeed READ cameraShutterSpeed WRITE setCameraShutterSpeed NOTIFY settingsChanged)
    Q_PROPERTY(double cameraGain READ cameraGain WRITE setCameraGain NOTIFY settingsChanged)
    Q_PROPERTY(int cameraFrameRate READ cameraFrameRate WRITE setCameraFrameRate NOTIFY settingsChanged)
    Q_PROPERTY(QString cameraResolution READ cameraResolution WRITE setCameraResolution NOTIFY settingsChanged)
    Q_PROPERTY(QString cameraFormat READ cameraFormat WRITE setCameraFormat NOTIFY settingsChanged)

public:
    explicit SettingsManager(QObject *parent = nullptr);
    ~SettingsManager() = default;

    // Camera settings getters
    int cameraShutterSpeed() const;
    double cameraGain() const;
    int cameraFrameRate() const;
    QString cameraResolution() const;
    QString cameraFormat() const;

    // Camera settings setters
    void setCameraShutterSpeed(int value);
    void setCameraGain(double value);
    void setCameraFrameRate(int value);
    void setCameraResolution(const QString &value);
    void setCameraFormat(const QString &value);

    // Generic get/set methods for QML
    Q_INVOKABLE QVariant getValue(const QString &key, const QVariant &defaultValue = QVariant()) const;
    Q_INVOKABLE void setValue(const QString &key, const QVariant &value);

    // Type-specific getters for QML
    Q_INVOKABLE QString getString(const QString &key, const QString &defaultValue = QString()) const;
    Q_INVOKABLE int getNumber(const QString &key, int defaultValue = 0) const;
    Q_INVOKABLE double getDouble(const QString &key, double defaultValue = 0.0) const;
    Q_INVOKABLE bool getBool(const QString &key, bool defaultValue = false) const;

    // Type-specific setters for QML
    Q_INVOKABLE void setString(const QString &key, const QString &value);
    Q_INVOKABLE void setNumber(const QString &key, int value);
    Q_INVOKABLE void setDouble(const QString &key, double value);
    Q_INVOKABLE void setBool(const QString &key, bool value);

    // Save/load operations
    Q_INVOKABLE void save();
    Q_INVOKABLE void load();
    Q_INVOKABLE void resetToDefaults();

signals:
    void settingsChanged();

private:
    void loadDefaults();

    QSettings *m_settings;

    // Cached values for frequent access
    int m_cameraShutterSpeed;
    double m_cameraGain;
    int m_cameraFrameRate;
    QString m_cameraResolution;
    QString m_cameraFormat;
};
