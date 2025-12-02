cmake_minimum_required(VERSION 3.16)
project(PRGR_LaunchMonitor VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find required Qt packages
find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml QuickControls2 Multimedia SerialPort)

# Find OpenCV
find_package(OpenCV REQUIRED)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${OpenCV_INCLUDE_DIRS}
)

# Source files
set(SOURCES
    src/main.cpp
    src/SettingsManager.cpp
    src/KLD2Manager.cpp
    src/CameraManager.cpp
    src/CaptureManager.cpp
    src/FrameProvider.cpp
    src/SoundManager.cpp
    src/CalibrationManager.cpp
)

# Header files
set(HEADERS
    include/SettingsManager.h
    include/KLD2Manager.h
    include/CameraManager.h
    include/CaptureManager.h
    include/FrameProvider.h
    include/SoundManager.h
    include/CalibrationManager.h
)

# QML resources
qt_add_resources(RESOURCES qml.qrc)

# Create executable
add_executable(${PROJECT_NAME}
    ${SOURCES}
    ${HEADERS}
    ${RESOURCES}
)

# Link libraries
target_link_libraries(${PROJECT_NAME}
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::QuickControls2
    Qt6::Multimedia
    Qt6::SerialPort
    ${OpenCV_LIBS}
)

# Compiler flags for optimization
target_compile_options(${PROJECT_NAME} PRIVATE
    -O3
    -march=native
    -Wall
    -Wextra
)

# Install target
install(TARGETS ${PROJECT_NAME}
    RUNTIME DESTINATION bin
)
