#include "KLD2Manager.h"
#include <QSerialPortInfo>
#include <QThread>
#include <QDebug>

KLD2Manager::KLD2Manager(QObject *parent)
    : QObject(parent)
    , m_serialPort(nullptr)
    , m_pollTimer(new QTimer(this))
    , m_isRunning(false)
    , m_minTriggerSpeed(50.0)        // Club trigger: 50 mph (default)
    , m_minBallTriggerSpeed(12.0)   // Ball trigger: 12 mph (recommended 10-15 mph)
    , m_triggerMode("ball")         // Default to ball mode (simpler, more reliable)
    , m_debugMode(false)
    , m_inSwing(false)
    , m_maxClubSpeed(0.0)
    , m_ballDetected(false)
{
    // Connect poll timer
    connect(m_pollTimer, &QTimer::timeout, this, &KLD2Manager::pollRadar);
}

KLD2Manager::~KLD2Manager() {
    stop();
}

void KLD2Manager::setMinTriggerSpeed(double speed) {
    if (m_minTriggerSpeed != speed) {
        m_minTriggerSpeed = speed;
        emit minTriggerSpeedChanged();
    }
}

void KLD2Manager::setMinBallTriggerSpeed(double speed) {
    if (m_minBallTriggerSpeed != speed) {
        m_minBallTriggerSpeed = speed;
        emit minBallTriggerSpeedChanged();
    }
}

void KLD2Manager::setTriggerMode(const QString &mode) {
    if (m_triggerMode != mode) {
        m_triggerMode = mode;
        // Reset state when switching modes
        m_inSwing = false;
        m_maxClubSpeed = 0.0;
        m_ballDetected = false;
        emit triggerModeChanged();
        qDebug() << "K-LD2 trigger mode set to:" << mode;
    }
}

void KLD2Manager::setDebugMode(bool enabled) {
    if (m_debugMode != enabled) {
        m_debugMode = enabled;
        emit debugModeChanged();
    }
}

bool KLD2Manager::start() {
    if (m_isRunning) {
        qWarning() << "K-LD2 already running";
        return true;
    }

    // K-LD2 connected via GPIO UART pins
    // Try common serial ports
    QStringList portCandidates = {"/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"};

    for (const QString &portName : portCandidates) {
        qDebug() << "Trying K-LD2 on" << portName;

        m_serialPort = new QSerialPort(this);
        m_serialPort->setPortName(portName);
        m_serialPort->setBaudRate(38400);  // K-LD2 uses 38400 baud
        m_serialPort->setDataBits(QSerialPort::Data8);
        m_serialPort->setParity(QSerialPort::NoParity);
        m_serialPort->setStopBits(QSerialPort::OneStop);
        m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

        if (m_serialPort->open(QIODevice::ReadWrite)) {
            qDebug() << "✓ K-LD2 connected on" << portName << "@ 38400 baud";

            // Configure sampling rate (20480 Hz for golf swing speeds)
            QThread::msleep(200);
            m_serialPort->write("$S0405\r\n");
            m_serialPort->flush();
            QThread::msleep(200);

            // Read configuration response
            if (m_serialPort->waitForReadyRead(1000)) {
                QByteArray response = m_serialPort->readAll();
                qDebug() << "Sampling rate set response:" << response;
            }

            // Connect serial data signal
            connect(m_serialPort, &QSerialPort::readyRead, this, &KLD2Manager::handleSerialData);

            // Start polling timer (20 Hz = 50ms interval)
            m_pollTimer->start(50);

            m_isRunning = true;
            emit isRunningChanged();
            emit statusChanged("K-LD2 ready", "green");
            qDebug() << "K-LD2 started with 20480 Hz sampling rate (min trigger:" << m_minTriggerSpeed << "mph)";

            return true;
        } else {
            qDebug() << "✗" << portName << "failed:" << m_serialPort->errorString();
            delete m_serialPort;
            m_serialPort = nullptr;
        }
    }

    emit statusChanged("K-LD2 not found", "red");
    return false;
}

void KLD2Manager::stop() {
    if (!m_isRunning) {
        return;
    }

    m_pollTimer->stop();
    m_isRunning = false;

    if (m_serialPort) {
        m_serialPort->close();
        delete m_serialPort;
        m_serialPort = nullptr;
    }

    // Reset all state
    m_inSwing = false;
    m_maxClubSpeed = 0.0;
    m_ballDetected = false;

    emit isRunningChanged();
    emit statusChanged("K-LD2 stopped", "gray");
    qDebug() << "K-LD2 stopped";
}

void KLD2Manager::pollRadar() {
    if (!m_serialPort || !m_serialPort->isOpen()) {
        return;
    }

    // Send $C01 command to get directional speed data
    m_serialPort->write("$C01\r\n");
    m_serialPort->flush();
}

void KLD2Manager::handleSerialData() {
    if (!m_serialPort) {
        return;
    }

    // Read available data
    m_buffer.append(m_serialPort->readAll());

    // Process complete lines
    while (m_buffer.contains('\n')) {
        int newlineIndex = m_buffer.indexOf('\n');
        QByteArray line = m_buffer.left(newlineIndex);
        m_buffer = m_buffer.mid(newlineIndex + 1);

        QString lineStr = QString::fromLatin1(line).trimmed();
        if (!lineStr.isEmpty() && !lineStr.startsWith('$') && !lineStr.startsWith('@')) {
            parseResponse(lineStr);
        }
    }
}

void KLD2Manager::parseResponse(const QString &line) {
    // Parse K-LD2 $C01 response format: approaching;receding;app_mag;rec_mag;
    // Example: "040;000;072;000;" = 40 mph approaching, 0 receding
    // Example: "000;010;000;075;" = 0 approaching, 10 mph receding

    QStringList parts = line.split(';');
    if (parts.size() < 4) {
        if (m_debugMode) {
            qDebug() << "K-LD2 parse error:" << line;
        }
        return;
    }

    bool ok1, ok2, ok3, ok4;
    int approachingSpeed = parts[0].toInt(&ok1);
    int recedingSpeed = parts[1].toInt(&ok2);
    int approachingMag = parts[2].toInt(&ok3);
    int recedingMag = parts[3].toInt(&ok4);

    if (!ok1 || !ok2 || !ok3 || !ok4) {
        if (m_debugMode) {
            qDebug() << "K-LD2 invalid data:" << line;
        }
        return;
    }

    processSpeed(approachingSpeed, recedingSpeed, approachingMag, recedingMag);
}

void KLD2Manager::processSpeed(int approachingSpeed, int recedingSpeed, int approachingMag, int recedingMag) {
    Q_UNUSED(approachingMag);
    Q_UNUSED(recedingMag);

    // Emit individual speed signals (always emit for display/measurement)
    if (approachingSpeed > 0) {
        emit clubSpeedUpdated(static_cast<double>(approachingSpeed));
    }
    if (recedingSpeed > 0) {
        emit ballSpeedUpdated(static_cast<double>(recedingSpeed));
    }

    // Debug output
    if (m_debugMode) {
        if (approachingSpeed > 0) {
            qDebug() << "K-LD2:" << approachingSpeed << "mph CLUB (approaching, mag" << approachingMag << ")";
        }
        if (recedingSpeed > 0) {
            qDebug() << "K-LD2:" << recedingSpeed << "mph BALL (receding, mag" << recedingMag << ")";
        }
    }

    // === TRIGGER MODE: BALL-BASED (RECOMMENDED) ===
    // Simple threshold detection: when ball speed appears → impact happened
    if (m_triggerMode == "ball") {
        if (recedingSpeed >= static_cast<int>(m_minBallTriggerSpeed)) {
            // Ball detected moving away (impact happened!)
            if (!m_ballDetected) {
                // First detection of this ball - trigger impact
                m_ballDetected = true;
                qDebug() << "🎯 BALL DETECTED:" << recedingSpeed << "mph (receding) - IMPACT TRIGGERED!";
                emit ballDetected(static_cast<double>(recedingSpeed));
                emit impactDetected();  // Main signal for camera capture
            }
        } else {
            // Ball speed dropped below threshold - reset for next shot
            if (m_ballDetected) {
                m_ballDetected = false;
                if (m_debugMode) {
                    qDebug() << "Ball detection reset (speed:" << recedingSpeed << "mph < threshold:" << m_minBallTriggerSpeed << "mph)";
                }
            }
        }
        return;  // Skip club-based detection in ball mode
    }

    // === TRIGGER MODE: CLUB-BASED (LEGACY) ===
    // Complex state machine: track club approach → peak → impact (speed drop)
    if (m_triggerMode == "club") {
        // Check if club is approaching (above threshold)
        if (approachingSpeed >= static_cast<int>(m_minTriggerSpeed)) {
            // Club detected approaching!
            if (!m_inSwing) {
                // NEW swing starting
                m_inSwing = true;
                m_maxClubSpeed = approachingSpeed;
                qDebug() << "⛳ SWING START: Club" << approachingSpeed << "mph (approaching)";
                emit clubApproaching(static_cast<double>(approachingSpeed));
                emit detectionTriggered();  // Legacy signal for backward compatibility
            } else {
                // Continue tracking swing - update peak if higher
                if (approachingSpeed > m_maxClubSpeed) {
                    m_maxClubSpeed = approachingSpeed;
                    if (m_debugMode) {
                        qDebug() << "   Club speed:" << approachingSpeed << "mph (peak:" << m_maxClubSpeed << "mph)";
                    }
                }
            }
        }
        // If we're in a swing, check if club passed through (speed dropped)
        else if (m_inSwing) {
            // Club speed dropped below threshold - club passed through ball!
            // This happens ~5-10ms after impact
            qDebug() << "🏌️ IMPACT DETECTED: Club speed dropped from" << m_maxClubSpeed << "mph →" << approachingSpeed << "mph";
            emit impactDetected();  // Signal that impact likely occurred

            // Reset swing state for next shot
            m_inSwing = false;
            m_maxClubSpeed = 0.0;
        }
    }
}
