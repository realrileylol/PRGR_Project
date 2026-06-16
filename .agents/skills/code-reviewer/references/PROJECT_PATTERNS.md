# PRGR Project Patterns

## File organization
- Headers: `include/*.h`
- Sources: `src/*.cpp`
- QML screens: `screens/*.qml`
- QML entry point: `main.qml`
- Resources: `qml.qrc`
- Build: `CMakeLists.txt`

## Manager pattern
Every hardware subsystem or feature area has a Manager class:
- Inherits `QObject`
- Exposes state via `Q_PROPERTY` with NOTIFY signals
- Callable from QML via `Q_INVOKABLE`
- Created in `main.cpp`, passed to QML via `setContextProperty`

## Thread model
- Main thread: Qt event loop, QML rendering, signal/slot dispatch
- Camera preview thread: `QThread` subclass, reads YUV420 from named pipe
- Capture thread: `QThread` subclass, high-speed frame capture + ball detection
- Cross-thread communication: `std::atomic` for flags, `QMetaObject::invokeMethod` with `Qt::QueuedConnection` for main-thread calls

## Camera pipeline
- rpicam-vid outputs YUV420 to a POSIX named pipe (`/tmp/prgr_camera_pipe`)
- Worker thread reads frames, extracts Y channel (grayscale)
- Frame passed to `FrameProvider` (thread-safe QML image provider)
- QML display updates throttled to ~30 FPS via timestamp check

## Development Mode
- Runtime toggle (Settings screen), persisted via SettingsManager
- `CameraManager::simulationMode` — QTimer generates synthetic frames at 30 FPS
- `KLD2Manager::simulationMode` — simulates radar without serial port
- `CaptureManager` — blocks with message in dev mode
- Windows builds default to dev mode ON

## Naming conventions
- C++ classes: PascalCase
- Q_PROPERTY names: camelCase
- QML ids: camelCase
- Source files match class names exactly
- Settings keys: `category/keyName` (e.g., `developer/developmentMode`)
