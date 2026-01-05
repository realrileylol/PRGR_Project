#pragma once

#include <QObject>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>

/**
 * @brief Manages shot history data
 *
 * Tracks all shots with metrics and timestamps.
 * Stores data in history.json for persistence.
 * Supports CSV export for data analysis.
 */
class HistoryManager : public QObject {
    Q_OBJECT

public:
    explicit HistoryManager(QObject *parent = nullptr);
    ~HistoryManager() = default;

    // Shot history methods for QML
    Q_INVOKABLE void addShot(const QString &profile, const QString &club,
                             double clubSpeed, double ballSpeed, double smash,
                             double launch, int spin, int carry, int total);
    Q_INVOKABLE QString getHistoryForProfile(const QString &profile);
    Q_INVOKABLE QString getAllHistory();
    Q_INVOKABLE void clearAllHistory();
    Q_INVOKABLE void clearProfileHistory(const QString &profile);
    Q_INVOKABLE QString exportToCSV();
    Q_INVOKABLE void deleteShot(int index);

signals:
    void historyChanged();

private:
    void loadHistory();
    void saveHistory();
    QJsonObject getDefaultData();

    QString m_historyFile;
    QJsonObject m_historyData;
};
