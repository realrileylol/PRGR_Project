#pragma once

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @brief Manages player profiles and bag configurations
 *
 * Handles profile creation, deletion, and bag preset management.
 * Stores data in profiles.json for persistence.
 */
class ProfileManager : public QObject {
    Q_OBJECT

public:
    explicit ProfileManager(QObject *parent = nullptr);
    ~ProfileManager() = default;

    // Profile and bag management methods for QML
    Q_INVOKABLE QString getProfilesJson(const QString &key);
    Q_INVOKABLE void saveProfilesJson(const QString &key, const QString &jsonStr);
    Q_INVOKABLE void setActiveProfile(const QString &profileName);
    Q_INVOKABLE QString getActiveProfile();
    Q_INVOKABLE void createProfile(const QString &profileName);
    Q_INVOKABLE void deleteProfile(const QString &profileName);
    Q_INVOKABLE void saveBagPreset(const QString &profileName, const QString &presetName, const QString &clubsJson);
    Q_INVOKABLE QString getBagPreset(const QString &profileName, const QString &presetName);
    Q_INVOKABLE void setActivePreset(const QString &profileName, const QString &presetName);

signals:
    void profilesChanged();
    void activeProfileChanged();

private:
    void loadProfiles();
    void saveProfiles();
    QJsonObject getDefaultData();
    QJsonObject getDefaultBag();

    QString m_profilesFile;
    QJsonObject m_profilesData;
    QString m_activeProfile;
};
