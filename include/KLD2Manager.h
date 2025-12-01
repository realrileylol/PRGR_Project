#pragma once

#include <QObject>
#include <QSerialPort>
#include <QTimer>
#include <QString>
#include <QByteArray>

/**
 * @brief K-LD2 Doppler radar manager for club/ball speed detection
 *
 * Model: K-LD2-RFB-00H-02 (RFBEAM MICROWAVE GMBH)
 * - 38400 baud UART communication
 * - ASCII command protocol ($S0405 for sampling, $C01 for speed)
 * - Separates approaching (club) from receding (ball) targets
 * - Swing state machine for impact detection
 */
class KLD2Manager : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool isRunning READ isRunning NOTIFY isRunningChanged)
    Q_PROPERTY(double minTriggerSpeed READ minTriggerSpeed WRITE setMinTriggerSpeed NOTIFY minTriggerSpeedChanged)
    Q_PROPERTY(bool debugMode READ debugMode WRITE setDebugMode NOTIFY debugModeChanged)

public:
    explicit KLD2Manager(QObject *parent = nullptr);
    ~KLD2Manager();

    bool isRunning() const { return m_isRunning; }
    double minTriggerSpeed() const { return m_minTriggerSpeed; }
    bool debugMode() const { return m_debugMode; }

    void setMinTriggerSpeed(double speed);
    void setDebugMode(bool enabled);

public slots:
    bool start();
    void stop();

signals:
    // Speed update signals
    void speedUpdated(double speed);           // Legacy - any speed detected
    void clubSpeedUpdated(double speed);       // Club head (approaching)
    void ballSpeedUpdated(double speed);       // Ball (receding)

    // Detection signals
    void clubApproaching(double speed);        // Swing starting (club detected)
    void impactDetected();                     // Impact timing (club passed through)
    void detectionTriggered();                 // Legacy - club approach

    // Status signals
    void statusChanged(const QString &message, const QString &color);
    void isRunningChanged();
    void minTriggerSpeedChanged();
    void debugModeChanged();

private slots:
    void pollRadar();
    void handleSerialData();

private:
    void parseResponse(const QString &line);
    void processSpeed(int approachingSpeed, int recedingSpeed, int approachingMag, int recedingMag);

    QSerialPort *m_serialPort;
    QTimer *m_pollTimer;
    QByteArray m_buffer;

    bool m_isRunning;
    double m_minTriggerSpeed;
    bool m_debugMode;

    // Swing state machine
    bool m_inSwing;
    double m_maxClubSpeed;
};
