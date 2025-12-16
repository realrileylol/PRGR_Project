#pragma once

#include <QObject>

/**
 * @brief Simple sound manager for UI feedback
 */
class SoundManager : public QObject {
    Q_OBJECT

public:
    explicit SoundManager(QObject *parent = nullptr) : QObject(parent) {}

public slots:
    void playClick() {
        // Stub - could implement with QSoundEffect later
    }

    void playSuccess() {
        // Stub - could implement with QSoundEffect later
    }

    void playError() {
        // Stub - could implement with QSoundEffect later
    }
};
