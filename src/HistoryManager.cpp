#include "HistoryManager.h"
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDateTime>
#include <QDebug>
#include <QDir>

HistoryManager::HistoryManager(QObject *parent)
    : QObject(parent)
{
    m_historyFile = QDir::currentPath() + "/history.json";
    loadHistory();
}

void HistoryManager::loadHistory()
{
    QFile file(m_historyFile);

    if (file.exists() && file.open(QIODevice::ReadOnly)) {
        QByteArray data = file.readAll();
        file.close();

        QJsonDocument doc = QJsonDocument::fromJson(data);
        if (!doc.isNull() && doc.isObject()) {
            m_historyData = doc.object();
            qDebug() << "History loaded from" << m_historyFile;
            return;
        }
    }

    // Use default data if file doesn't exist or is invalid
    m_historyData = getDefaultData();
    qDebug() << "Using default history data";
}

void HistoryManager::saveHistory()
{
    QFile file(m_historyFile);

    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(m_historyData);
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
        qDebug() << "History saved to" << m_historyFile;
    } else {
        qWarning() << "Failed to save history to" << m_historyFile;
    }
}

QJsonObject HistoryManager::getDefaultData()
{
    QJsonObject data;
    data["shots"] = QJsonArray();
    return data;
}

void HistoryManager::addShot(const QString &profile, const QString &club,
                             double clubSpeed, double ballSpeed, double smash,
                             double launch, int spin, int carry, int total)
{
    QJsonObject shot;
    shot["timestamp"] = QDateTime::currentDateTime().toString(Qt::ISODate);
    shot["profile"] = profile;
    shot["club"] = club;
    shot["clubSpeed"] = qRound(clubSpeed * 10) / 10.0;
    shot["ballSpeed"] = qRound(ballSpeed * 10) / 10.0;
    shot["smash"] = qRound(smash * 100) / 100.0;
    shot["launch"] = qRound(launch * 10) / 10.0;
    shot["spin"] = spin;
    shot["carry"] = carry;
    shot["total"] = total;

    QJsonArray shots = m_historyData["shots"].toArray();
    shots.append(shot);
    m_historyData["shots"] = shots;

    saveHistory();
    emit historyChanged();

    qDebug() << "Shot added to history for" << profile << "using" << club;
}

QString HistoryManager::getHistoryForProfile(const QString &profile)
{
    QJsonArray shots = m_historyData["shots"].toArray();
    QJsonArray profileShots;

    for (const QJsonValue &value : shots) {
        QJsonObject shot = value.toObject();
        if (shot["profile"].toString() == profile) {
            profileShots.append(shot);
        }
    }

    // Reverse array (newest first)
    QJsonArray reversed;
    for (int i = profileShots.size() - 1; i >= 0; --i) {
        reversed.append(profileShots[i]);
    }

    QJsonDocument doc(reversed);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

QString HistoryManager::getAllHistory()
{
    QJsonArray shots = m_historyData["shots"].toArray();

    // Reverse array (newest first)
    QJsonArray reversed;
    for (int i = shots.size() - 1; i >= 0; --i) {
        reversed.append(shots[i]);
    }

    QJsonDocument doc(reversed);
    return QString::fromUtf8(doc.toJson(QJsonDocument::Compact));
}

void HistoryManager::clearAllHistory()
{
    m_historyData = getDefaultData();
    saveHistory();
    emit historyChanged();
    qDebug() << "All history cleared";
}

void HistoryManager::clearProfileHistory(const QString &profile)
{
    QJsonArray shots = m_historyData["shots"].toArray();
    QJsonArray filteredShots;

    for (const QJsonValue &value : shots) {
        QJsonObject shot = value.toObject();
        if (shot["profile"].toString() != profile) {
            filteredShots.append(shot);
        }
    }

    m_historyData["shots"] = filteredShots;
    saveHistory();
    emit historyChanged();

    qDebug() << "History cleared for" << profile;
}

QString HistoryManager::exportToCSV()
{
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString exportFile = QDir::currentPath() + "/shot_history_" + timestamp + ".csv";

    QFile file(exportFile);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "Failed to create CSV file:" << exportFile;
        return "";
    }

    QTextStream out(&file);

    // Write CSV header
    out << "Date/Time,Profile,Club,Ball Speed (mph),Club Speed (mph),"
        << "Smash Factor,Launch Angle (°),Spin (rpm),Carry (yds),Total (yds)\n";

    // Write shots (oldest first for CSV)
    QJsonArray shots = m_historyData["shots"].toArray();
    for (const QJsonValue &value : shots) {
        QJsonObject shot = value.toObject();

        QString dateTime = QDateTime::fromString(shot["timestamp"].toString(), Qt::ISODate)
                               .toString("yyyy-MM-dd HH:mm:ss");

        out << dateTime << ","
            << shot["profile"].toString() << ","
            << shot["club"].toString() << ","
            << shot["ballSpeed"].toDouble() << ","
            << shot["clubSpeed"].toDouble() << ","
            << shot["smash"].toDouble() << ","
            << shot["launch"].toDouble() << ","
            << shot["spin"].toInt() << ","
            << shot["carry"].toInt() << ","
            << shot["total"].toInt() << "\n";
    }

    file.close();
    qDebug() << "📄 History exported to" << exportFile;

    return exportFile;
}

void HistoryManager::deleteShot(int index)
{
    QJsonArray shots = m_historyData["shots"].toArray();

    // Index is from reversed array (newest first), so convert
    int actualIndex = shots.size() - 1 - index;

    if (actualIndex >= 0 && actualIndex < shots.size()) {
        shots.removeAt(actualIndex);
        m_historyData["shots"] = shots;
        saveHistory();
        emit historyChanged();
        qDebug() << "Shot deleted at index" << index;
    } else {
        qWarning() << "Invalid shot index:" << index;
    }
}
