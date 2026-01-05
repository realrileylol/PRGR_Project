#include "ProfileManager.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>
#include <QDir>

ProfileManager::ProfileManager(QObject *parent)
    : QObject(parent)
{
    m_profilesFile = QDir::currentPath() + "/profiles.json";
    loadProfiles();
    m_activeProfile = m_profilesData["active_profile"].toString();
}

void ProfileManager::loadProfiles()
{
    QFile file(m_profilesFile);

    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.isObject()) {
            m_profilesData = doc.object();
            qDebug() << "Profiles loaded from" << m_profilesFile;
            return;
        }
    }

    // Use default data if file doesn't exist or is invalid
    m_profilesData = getDefaultData();
    qDebug() << "Using default profile data";
}

void ProfileManager::saveProfiles()
{
    QFile file(m_profilesFile);

    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(m_profilesData);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        qDebug() << "Profiles saved to" << m_profilesFile;
    } else {
        qWarning() << "Failed to save profiles to" << m_profilesFile;
    }
}

QJsonObject ProfileManager::getDefaultData()
{
    QJsonObject data;
    data["active_profile"] = "";
    data["profiles"] = QJsonArray();
    data["bags"] = QJsonObject();
    data["active_presets"] = QJsonObject();
    return data;
}

QJsonObject ProfileManager::getDefaultBag()
{
    QJsonObject bag;
    bag["Driver"] = 10.5;
    bag["3 Wood"] = 15.0;
    bag["5 Wood"] = 18.0;
    bag["3 Hybrid"] = 19.0;
    bag["4 Iron"] = 21.0;
    bag["5 Iron"] = 24.0;
    bag["6 Iron"] = 28.0;
    bag["7 Iron"] = 34.0;
    bag["8 Iron"] = 38.0;
    bag["9 Iron"] = 42.0;
    bag["PW"] = 46.0;
    bag["GW"] = 50.0;
    bag["SW"] = 56.0;
    bag["LW"] = 60.0;
    return bag;
}

QString ProfileManager::getProfilesJson(const QString &key)
{
    QJsonDocument doc;

    if (key == "profiles") {
        doc.setArray(m_profilesData["profiles"].toArray());
    } else if (key == "bags") {
        doc.setObject(m_profilesData["bags"].toObject());
    } else if (key == "active_presets") {
        doc.setObject(m_profilesData["active_presets"].toObject());
    } else {
        doc.setArray(QJsonArray());
    }

    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

void ProfileManager::saveProfilesJson(const QString &key, const QString &jsonStr)
{
    QJsonDocument doc = QJsonDocument::fromJson(jsonStr.toUtf8());

    if (!doc.isNull()) {
        if (doc.isArray()) {
            m_profilesData[key] = doc.array();
        } else if (doc.isObject()) {
            m_profilesData[key] = doc.object();
        }

        saveProfiles();
        emit profilesChanged();
    } else {
        qWarning() << "Invalid JSON for key:" << key;
    }
}

void ProfileManager::setActiveProfile(const QString &profileName)
{
    m_activeProfile = profileName;
    m_profilesData["active_profile"] = profileName;
    saveProfiles();
    emit activeProfileChanged();
}

QString ProfileManager::getActiveProfile()
{
    return m_activeProfile;
}

void ProfileManager::createProfile(const QString &profileName)
{
    if (profileName.isEmpty()) {
        return;
    }

    QJsonArray profiles = m_profilesData["profiles"].toArray();

    // Check if profile already exists
    for (const QJsonValue &value : profiles) {
        if (value.toString() == profileName) {
            qDebug() << "Profile already exists:" << profileName;
            return;
        }
    }

    // Add new profile
    profiles.append(profileName);
    m_profilesData["profiles"] = profiles;

    // Create default bag
    QJsonObject bags = m_profilesData["bags"].toObject();
    QJsonObject profileBags;
    profileBags["Default Set"] = getDefaultBag();
    bags[profileName] = profileBags;
    m_profilesData["bags"] = bags;

    // Set default active preset
    QJsonObject activePresets = m_profilesData["active_presets"].toObject();
    activePresets[profileName] = "Default Set";
    m_profilesData["active_presets"] = activePresets;

    saveProfiles();
    emit profilesChanged();

    qDebug() << "Profile created:" << profileName;
}

void ProfileManager::deleteProfile(const QString &profileName)
{
    QJsonArray profiles = m_profilesData["profiles"].toArray();

    // Remove profile from array
    for (int i = 0; i < profiles.size(); ++i) {
        if (profiles[i].toString() == profileName) {
            profiles.removeAt(i);
            break;
        }
    }
    m_profilesData["profiles"] = profiles;

    // Remove associated data
    QJsonObject bags = m_profilesData["bags"].toObject();
    bags.remove(profileName);
    m_profilesData["bags"] = bags;

    QJsonObject activePresets = m_profilesData["active_presets"].toObject();
    activePresets.remove(profileName);
    m_profilesData["active_presets"] = activePresets;

    // If deleting active profile, switch to first available or empty
    if (m_activeProfile == profileName) {
        if (profiles.size() > 0) {
            m_activeProfile = profiles[0].toString();
        } else {
            m_activeProfile = "";
        }
        m_profilesData["active_profile"] = m_activeProfile;
    }

    saveProfiles();
    emit profilesChanged();
    emit activeProfileChanged();

    qDebug() << "Profile deleted:" << profileName;
}

void ProfileManager::saveBagPreset(const QString &profileName, const QString &presetName, const QString &clubsJson)
{
    QJsonDocument doc = QJsonDocument::fromJson(clubsJson.toUtf8());

    if (!doc.isNull() && doc.isObject()) {
        QJsonObject bags = m_profilesData["bags"].toObject();
        QJsonObject profileBags = bags[profileName].toObject();
        profileBags[presetName] = doc.object();
        bags[profileName] = profileBags;
        m_profilesData["bags"] = bags;

        saveProfiles();
        emit profilesChanged();

        qDebug() << "Bag preset saved:" << profileName << "/" << presetName;
    } else {
        qWarning() << "Invalid clubs JSON for bag preset";
    }
}

QString ProfileManager::getBagPreset(const QString &profileName, const QString &presetName)
{
    QJsonObject bags = m_profilesData["bags"].toObject();

    if (bags.contains(profileName)) {
        QJsonObject profileBags = bags[profileName].toObject();

        if (profileBags.contains(presetName)) {
            QJsonDocument doc(profileBags[presetName].toObject());
            return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
        }
    }

    // Return default bag if not found
    QJsonDocument doc(getDefaultBag());
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

void ProfileManager::setActivePreset(const QString &profileName, const QString &presetName)
{
    QJsonObject activePresets = m_profilesData["active_presets"].toObject();
    activePresets[profileName] = presetName;
    m_profilesData["active_presets"] = activePresets;
    saveProfiles();
}
