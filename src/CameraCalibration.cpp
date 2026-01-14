#include "CameraCalibration.h"
#include "FrameProvider.h"
#include "SettingsManager.h"
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
#include <QDateTime>
#include <QDir>
#include <cmath>

CameraCalibration::CameraCalibration(QObject *parent)
    : QObject(parent)
{
    // Initialize to identity matrices
    m_cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_distCoeffs = cv::Mat::zeros(5, 1, CV_64F);
    m_rotationMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_translationVector = cv::Mat::zeros(3, 1, CV_64F);
    m_homography = cv::Mat::eye(3, 3, CV_64F);

    // Note: Using edge density verification (no templates needed)
}

CameraCalibration::~CameraCalibration() = default;

void CameraCalibration::setFrameProvider(FrameProvider *provider) {
    m_frameProvider = provider;
}

void CameraCalibration::setSettings(SettingsManager *settings) {
    m_settings = settings;
    loadCalibration();
}

void CameraCalibration::setCropParameters(int offsetX, int offsetY, int croppedWidth, int croppedHeight) {
    m_cropOffsetX = offsetX;
    m_cropOffsetY = offsetY;
    m_croppedWidth = croppedWidth;
    m_croppedHeight = croppedHeight;

    qDebug() << "CameraCalibration: Crop parameters set - Offset:" << offsetX << "," << offsetY
             << "Cropped size:" << croppedWidth << "x" << croppedHeight;
}

// ============================================================================
// INTRINSIC CALIBRATION (Checkerboard Method)
// ============================================================================

void CameraCalibration::startIntrinsicCalibration(int boardWidth, int boardHeight, float squareSize) {
    m_boardWidth = boardWidth;
    m_boardHeight = boardHeight;
    m_squareSize = squareSize;
    m_imagePoints.clear();
    m_objectPoints.clear();
    m_progress = 0;
    m_status = QString("Ready to capture frames (%1×%2 board, %3mm squares)")
                   .arg(boardWidth).arg(boardHeight).arg(squareSize);

    qDebug() << "Started intrinsic calibration:" << m_status;
    emit statusChanged();
    emit progressChanged();
}

void CameraCalibration::captureCalibrationFrame() {
    if (!m_frameProvider) {
        qWarning() << "No frame provider available";
        emit calibrationFailed("No camera feed available");
        return;
    }

    // Get current frame
    QImage qimg = m_frameProvider->requestImage("", nullptr, QSize());
    if (qimg.isNull()) {
        qWarning() << "Failed to capture calibration frame";
        emit calibrationFrameCaptured(m_imagePoints.size(), false);
        return;
    }

    // Convert to OpenCV format
    cv::Mat frame(qimg.height(), qimg.width(), CV_8UC1);
    memcpy(frame.data, qimg.bits(), qimg.width() * qimg.height());

    // Detect checkerboard
    std::vector<cv::Point2f> corners;
    bool found = detectCheckerboard(frame, corners);

    if (found) {
        // Add to calibration dataset
        m_imagePoints.push_back(corners);

        // Generate corresponding 3D object points
        std::vector<cv::Point3f> objPoints;
        for (int i = 0; i < m_boardHeight; i++) {
            for (int j = 0; j < m_boardWidth; j++) {
                objPoints.push_back(cv::Point3f(j * m_squareSize, i * m_squareSize, 0.0f));
            }
        }
        m_objectPoints.push_back(objPoints);

        m_progress = (m_imagePoints.size() * 100) / 25;  // Target 25 frames
        m_status = QString("Captured %1/25 frames").arg(m_imagePoints.size());

        qDebug() << "Captured valid calibration frame" << m_imagePoints.size();
        emit calibrationFrameCaptured(m_imagePoints.size(), true);
    } else {
        qWarning() << "Checkerboard not detected in frame";
        emit calibrationFrameCaptured(m_imagePoints.size(), false);
    }

    emit statusChanged();
    emit progressChanged();
}

bool CameraCalibration::detectCheckerboard(const cv::Mat &image, std::vector<cv::Point2f> &corners) {
    cv::Size boardSize(m_boardWidth, m_boardHeight);

    qDebug() << "Detecting checkerboard:" << m_boardWidth << "x" << m_boardHeight
             << "Image size:" << image.cols << "x" << image.rows
             << "Channels:" << image.channels();

    // Find checkerboard corners
    bool found = cv::findChessboardCorners(image, boardSize, corners,
                                           cv::CALIB_CB_ADAPTIVE_THRESH |
                                           cv::CALIB_CB_NORMALIZE_IMAGE |
                                           cv::CALIB_CB_FAST_CHECK);

    qDebug() << "Checkerboard detection result:" << (found ? "SUCCESS" : "FAILED")
             << "Expected corners:" << (m_boardWidth * m_boardHeight)
             << "Found:" << corners.size();

    if (found) {
        // Refine corner positions to sub-pixel accuracy
        cv::cornerSubPix(image, corners, cv::Size(11, 11), cv::Size(-1, -1),
                        cv::TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::COUNT, 30, 0.1));
        qDebug() << "Corner refinement complete";
    }

    return found;
}

void CameraCalibration::finishIntrinsicCalibration() {
    if (m_imagePoints.size() < 10) {
        m_status = QString("Need at least 10 frames (have %1)").arg(m_imagePoints.size());
        emit calibrationFailed(m_status);
        emit statusChanged();
        return;
    }

    m_status = "Computing calibration...";
    emit statusChanged();

    // Perform calibration
    cv::Size imageSize(640, 480);  // OV9281 VGA resolution
    std::vector<cv::Mat> rvecs, tvecs;
    double rms = cv::calibrateCamera(m_objectPoints, m_imagePoints, imageSize,
                                     m_cameraMatrix, m_distCoeffs, rvecs, tvecs,
                                     cv::CALIB_FIX_ASPECT_RATIO);

    // Extract calibration parameters
    m_fx = m_cameraMatrix.at<double>(0, 0);
    m_fy = m_cameraMatrix.at<double>(1, 1);
    m_cx = m_cameraMatrix.at<double>(0, 2);
    m_cy = m_cameraMatrix.at<double>(1, 2);

    m_isIntrinsicCalibrated = true;
    m_progress = 100;
    m_status = QString("Calibration complete (RMS error: %1 pixels)").arg(rms, 0, 'f', 3);

    qDebug() << "Camera calibration complete:";
    qDebug() << "  Focal length: fx=" << m_fx << "fy=" << m_fy;
    qDebug() << "  Principal point:" << m_cx << "x" << m_cy;
    qDebug() << "  Distortion: k1=" << m_distCoeffs.at<double>(0, 0)
             << "k2=" << m_distCoeffs.at<double>(1, 0)
             << "k3=" << m_distCoeffs.at<double>(4, 0);
    qDebug() << "  RMS error:" << rms << "pixels";

    // Validate against sensor specs
    double fovX = 2.0 * std::atan2(imageSize.width / 2.0, m_fx) * 180.0 / M_PI;
    double fovY = 2.0 * std::atan2(imageSize.height / 2.0, m_fy) * 180.0 / M_PI;
    qDebug() << "  Calculated FOV: H=" << fovX << "° V=" << fovY << "°";

    saveCalibration();

    emit intrinsicCalibrationChanged();
    emit statusChanged();
    emit progressChanged();
    emit calibrationComplete(formatCalibrationSummary());
}

void CameraCalibration::cancelIntrinsicCalibration() {
    m_imagePoints.clear();
    m_objectPoints.clear();
    m_progress = 0;
    m_status = "Calibration cancelled";

    emit statusChanged();
    emit progressChanged();
}

// ============================================================================
// EXTRINSIC CALIBRATION (Ground Plane Method)
// ============================================================================

void CameraCalibration::startExtrinsicCalibration() {
    if (!m_isIntrinsicCalibrated) {
        m_status = "Must complete intrinsic calibration first";
        emit calibrationFailed(m_status);
        emit statusChanged();
        return;
    }

    m_status = "Place markers on ground at known positions";
    emit statusChanged();
}

void CameraCalibration::setGroundPlanePoints(const QList<QPointF> &imagePoints,
                                              const QList<QPointF> &worldPoints) {
    if (imagePoints.size() != worldPoints.size() || imagePoints.size() < 4) {
        m_status = "Need at least 4 point pairs";
        emit calibrationFailed(m_status);
        emit statusChanged();
        return;
    }

    // Store marker corners for later use as zone boundaries
    m_markerCorners = imagePoints;
    qDebug() << "Stored marker corners for zone calibration:" << m_markerCorners.size() << "points";

    // Convert to OpenCV format with Z=0 (ground plane)
    std::vector<cv::Point3f> objectPoints;  // 3D world points
    std::vector<cv::Point2f> imagePoints2D; // 2D image points

    for (int i = 0; i < worldPoints.size(); i++) {
        // World points are in mm on ground plane (Z=0)
        objectPoints.push_back(cv::Point3f(worldPoints[i].x(), worldPoints[i].y(), 0.0f));
        imagePoints2D.push_back(cv::Point2f(imagePoints[i].x(), imagePoints[i].y()));
    }

    // Solve for camera pose using Perspective-n-Point
    cv::Mat rvec, tvec;  // Rotation vector and translation vector
    bool success = cv::solvePnP(objectPoints, imagePoints2D, m_cameraMatrix, m_distCoeffs,
                                rvec, tvec, false, cv::SOLVEPNP_ITERATIVE);

    if (!success) {
        m_status = "Failed to solve camera pose";
        emit calibrationFailed(m_status);
        emit statusChanged();
        return;
    }

    // Convert rotation vector to rotation matrix
    cv::Rodrigues(rvec, m_rotationMatrix);
    m_translationVector = tvec;

    qDebug() << "solvePnP successful";
    qDebug() << "Raw translation vector:"
             << "tx=" << m_translationVector.at<double>(0)
             << "ty=" << m_translationVector.at<double>(1)
             << "tz=" << m_translationVector.at<double>(2);

    // Extract camera pose parameters from translation vector
    // In OpenCV camera coordinates: X=right, Y=down, Z=forward
    // Ball (world origin) position in camera frame:
    //   ty = vertical offset (negative means ball is below camera)
    //   tz = forward distance (distance from camera to ball)
    m_cameraHeight = std::abs(m_translationVector.at<double>(1)) / 1000.0;  // |ty| mm to meters
    m_cameraDistance = std::abs(m_translationVector.at<double>(2)) / 1000.0;  // |tz| mm to meters

    // Calculate tilt angle from rotation matrix
    double tiltRad = std::atan2(m_rotationMatrix.at<double>(2, 0),
                                m_rotationMatrix.at<double>(2, 2));
    m_cameraTilt = tiltRad * 180.0 / M_PI;

    // Handle flipped solution
    if (m_cameraTilt > 90) {
        m_cameraTilt = m_cameraTilt - 180.0;
    }

    m_isExtrinsicCalibrated = true;
    m_status = "Extrinsic calibration complete";

    qDebug() << "Extrinsic calibration complete";
    qDebug() << "  Camera height:" << m_cameraHeight << "m";
    qDebug() << "  Camera tilt:" << m_cameraTilt << "°";
    qDebug() << "  Camera distance:" << m_cameraDistance << "m";

    saveCalibration();

    emit extrinsicCalibrationChanged();
    emit statusChanged();
    emit calibrationComplete("Extrinsic calibration successful");
}

void CameraCalibration::calculateCameraPose() {
    // Decompose homography to get rotation and translation
    // This gives us camera pose relative to ground plane
    std::vector<cv::Mat> rotations, translations, normals;
    cv::decomposeHomographyMat(m_homography, m_cameraMatrix, rotations, translations, normals);

    if (rotations.empty()) {
        qWarning() << "Failed to decompose homography";
        return;
    }

    qDebug() << "Homography decomposition returned" << rotations.size() << "solutions";

    // Select the best solution (camera above ground, pointing down)
    int bestIdx = -1;
    double bestScore = -1e9;

    for (size_t i = 0; i < rotations.size(); i++) {
        double tz = translations[i].at<double>(2, 0);
        double nz = normals[i].at<double>(2, 0);

        // Use absolute value of tz (camera height above ground)
        double height = std::abs(tz);

        // Calculate tilt angle
        double tiltRad = std::atan2(rotations[i].at<double>(2, 0),
                                    rotations[i].at<double>(2, 2));
        double tiltDeg = tiltRad * 180.0 / M_PI;

        // Scoring system to find best solution
        double score = 0;

        // Prefer reasonable height (0.2 to 2 meters = 8 to 80 inches)
        if (height > 0.2 && height < 2.0) {
            score += 100;
        } else if (height > 0.05 && height < 5.0) {
            score += 50;  // Acceptable range
        }

        // Prefer downward tilt (-5 to -20 degrees)
        if (tiltDeg < -5 && tiltDeg > -20) {
            score += 100;
        } else if (tiltDeg > 160 && tiltDeg < 175) {
            // Flipped solution (180 - angle gives actual downward tilt)
            score += 80;
        } else if (tiltDeg < 0 && tiltDeg > -45) {
            score += 50;  // Any downward tilt
        }

        // Prefer solutions where camera is above ground (positive tz)
        if (tz > 0) score += 30;

        qDebug() << "  Solution" << i << ": height=" << height << "m, tilt=" << tiltDeg
                 << "°, tz=" << tz << ", nz=" << nz << ", score=" << score;

        if (score > bestScore) {
            bestScore = score;
            bestIdx = i;
        }
    }

    if (bestIdx < 0) {
        qWarning() << "No valid solution found! Using first solution as fallback.";
        bestIdx = 0;
    }

    qDebug() << "Selected solution" << bestIdx << "as best";

    m_rotationMatrix = rotations[bestIdx];
    m_translationVector = translations[bestIdx];

    qDebug() << "Raw translation vector:"
             << "tx=" << m_translationVector.at<double>(0, 0)
             << "ty=" << m_translationVector.at<double>(1, 0)
             << "tz=" << m_translationVector.at<double>(2, 0);

    // Extract camera height (Z component of translation, use absolute value)
    // Translation is in millimeters (same units as intrinsic calibration)
    // Convert to meters for storage/display
    m_cameraHeight = std::abs(m_translationVector.at<double>(2, 0)) / 1000.0;

    // Calculate tilt angle from rotation matrix
    double tiltRad = std::atan2(m_rotationMatrix.at<double>(2, 0),
                                m_rotationMatrix.at<double>(2, 2));
    m_cameraTilt = tiltRad * 180.0 / M_PI;

    // Handle flipped solution (tilt near 180° means camera pointing down)
    if (m_cameraTilt > 90) {
        m_cameraTilt = m_cameraTilt - 180.0;  // Convert 167° to -13°
    }

    // Calculate distance to origin (ball position)
    // Translation in mm, convert to meters
    m_cameraDistance = std::sqrt(
        m_translationVector.at<double>(0, 0) * m_translationVector.at<double>(0, 0) +
        m_translationVector.at<double>(1, 0) * m_translationVector.at<double>(1, 0)
    ) / 1000.0;
}

void CameraCalibration::finishExtrinsicCalibration() {
    // Already handled in setGroundPlanePoints
    saveCalibration();
}

// ============================================================================
// SCALE FACTOR
// ============================================================================

double CameraCalibration::pixelsPerMm() const {
    if (!m_isIntrinsicCalibrated) {
        return 0.0;
    }

    // Calculate pixels per mm based on focal length and sensor size
    // For VGA resolution (640×480):
    // pixels_per_mm = image_width / sensor_width
    // Using 640×480 as reference resolution
    double pixelsPerMmX = 640.0 / SENSOR_WIDTH_MM;
    double pixelsPerMmY = 480.0 / SENSOR_HEIGHT_MM;

    // Return average of X and Y
    return (pixelsPerMmX + pixelsPerMmY) / 2.0;
}

// ============================================================================
// DISTORTION CORRECTION
// ============================================================================

cv::Mat CameraCalibration::undistortImage(const cv::Mat &image) const {
    if (!m_isIntrinsicCalibrated) {
        return image.clone();
    }

    cv::Mat undistorted;
    cv::undistort(image, undistorted, m_cameraMatrix, m_distCoeffs);
    return undistorted;
}

cv::Point2f CameraCalibration::undistortPoint(const cv::Point2f &point) const {
    if (!m_isIntrinsicCalibrated) {
        return point;
    }

    std::vector<cv::Point2f> src = {point};
    std::vector<cv::Point2f> dst;
    cv::undistortPoints(src, dst, m_cameraMatrix, m_distCoeffs, cv::noArray(), m_cameraMatrix);
    return dst[0];
}

// ============================================================================
// COORDINATE TRANSFORMATION
// ============================================================================

cv::Point3f CameraCalibration::pixelToWorld(const cv::Point2f &pixel, double assumedHeight) const {
    if (!m_isExtrinsicCalibrated) {
        return cv::Point3f(0, 0, 0);
    }

    // First undistort the pixel
    cv::Point2f undistorted = undistortPoint(pixel);

    // Apply homography to get ground plane coordinates
    std::vector<cv::Point2f> src = {undistorted};
    std::vector<cv::Point2f> dst;
    cv::perspectiveTransform(src, dst, m_homography);

    return cv::Point3f(dst[0].x, dst[0].y, assumedHeight);
}

cv::Point2f CameraCalibration::worldToPixel(const cv::Point3f &worldPoint) const {
    if (!m_isExtrinsicCalibrated) {
        return cv::Point2f(0, 0);
    }

    // Project world point to image using camera matrix and pose
    std::vector<cv::Point3f> objectPoints = {worldPoint};
    std::vector<cv::Point2f> imagePoints;

    cv::projectPoints(objectPoints, m_rotationMatrix, m_translationVector,
                     m_cameraMatrix, m_distCoeffs, imagePoints);

    return imagePoints[0];
}

// ============================================================================
// PERSISTENCE
// ============================================================================

void CameraCalibration::saveCalibration() {
    if (!m_settings) {
        qWarning() << "No settings manager available";
        return;
    }

    QString appDataPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QString calibPath = appDataPath + "/calibration.json";

    // Create directory if it doesn't exist
    QDir dir;
    if (!dir.mkpath(appDataPath)) {
        qWarning() << "Failed to create directory:" << appDataPath;
        return;
    }

    qDebug() << "Saving calibration to:" << calibPath;

    QJsonObject json;

    // Intrinsic parameters
    json["intrinsic_calibrated"] = m_isIntrinsicCalibrated;
    json["fx"] = m_fx;
    json["fy"] = m_fy;
    json["cx"] = m_cx;
    json["cy"] = m_cy;

    // Distortion coefficients
    QJsonArray distortion;
    for (int i = 0; i < 5; i++) {
        distortion.append(m_distCoeffs.at<double>(i, 0));
    }
    json["distortion"] = distortion;

    // Extrinsic parameters
    json["extrinsic_calibrated"] = m_isExtrinsicCalibrated;
    json["camera_height"] = m_cameraHeight;
    json["camera_tilt"] = m_cameraTilt;
    json["camera_distance"] = m_cameraDistance;

    // Ball zone calibration
    json["ballzone_calibrated"] = m_isBallZoneCalibrated;
    json["ball_center_x"] = m_ballCenterX;
    json["ball_center_y"] = m_ballCenterY;
    json["ball_radius"] = m_ballRadius;

    // Zone boundaries
    json["zone_defined"] = m_isZoneDefined;
    QJsonArray zoneCorners;
    for (const auto &corner : m_zoneCorners) {
        QJsonObject cornerObj;
        cornerObj["x"] = corner.x();
        cornerObj["y"] = corner.y();
        zoneCorners.append(cornerObj);
    }
    json["zone_corners"] = zoneCorners;

    // Marker corners (from extrinsic calibration)
    QJsonArray markerCorners;
    for (const auto &corner : m_markerCorners) {
        QJsonObject cornerObj;
        cornerObj["x"] = corner.x();
        cornerObj["y"] = corner.y();
        markerCorners.append(cornerObj);
    }
    json["marker_corners"] = markerCorners;

    // Save to file
    QFile file(calibPath);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "Failed to open file for writing:" << calibPath;
        qWarning() << "Error:" << file.errorString();
        return;
    }

    QJsonDocument doc(json);
    qint64 bytesWritten = file.write(doc.toJson());
    if (bytesWritten == -1) {
        qWarning() << "Failed to write calibration data:" << file.errorString();
        file.close();
        return;
    }

    file.flush();  // Ensure data is written to disk
    file.close();

    // Verify file was created
    if (QFile::exists(calibPath)) {
        qDebug() << "✓ Calibration saved successfully to" << calibPath;
        qDebug() << "✓ File size:" << bytesWritten << "bytes";
    } else {
        qWarning() << "✗ Calibration file does not exist after save!";
    }
}

void CameraCalibration::loadCalibration() {
    QString calibPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/calibration.json";

    QFile file(calibPath);
    if (!file.exists()) {
        qDebug() << "No calibration file found";
        return;
    }

    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Failed to open calibration file";
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject json = doc.object();

    // Load intrinsic parameters
    m_isIntrinsicCalibrated = json["intrinsic_calibrated"].toBool();
    m_fx = json["fx"].toDouble();
    m_fy = json["fy"].toDouble();
    m_cx = json["cx"].toDouble();
    m_cy = json["cy"].toDouble();

    // Reconstruct camera matrix
    m_cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_cameraMatrix.at<double>(0, 0) = m_fx;
    m_cameraMatrix.at<double>(1, 1) = m_fy;
    m_cameraMatrix.at<double>(0, 2) = m_cx;
    m_cameraMatrix.at<double>(1, 2) = m_cy;

    // Load distortion coefficients
    QJsonArray distortion = json["distortion"].toArray();
    m_distCoeffs = cv::Mat::zeros(5, 1, CV_64F);
    int distSize = std::min(5, static_cast<int>(distortion.size()));
    for (int i = 0; i < distSize; i++) {
        m_distCoeffs.at<double>(i, 0) = distortion[i].toDouble();
    }

    // Load extrinsic parameters
    m_isExtrinsicCalibrated = json["extrinsic_calibrated"].toBool();
    m_cameraHeight = json["camera_height"].toDouble();
    m_cameraTilt = json["camera_tilt"].toDouble();
    m_cameraDistance = json["camera_distance"].toDouble();

    // Load ball zone calibration
    m_isBallZoneCalibrated = json["ballzone_calibrated"].toBool();
    m_ballCenterX = json["ball_center_x"].toDouble();
    m_ballCenterY = json["ball_center_y"].toDouble();
    m_ballRadius = json["ball_radius"].toDouble();

    // Load zone boundaries
    m_isZoneDefined = json["zone_defined"].toBool();
    m_zoneCorners.clear();
    QJsonArray zoneCorners = json["zone_corners"].toArray();
    for (const auto &cornerVal : zoneCorners) {
        QJsonObject cornerObj = cornerVal.toObject();
        m_zoneCorners.append(QPointF(cornerObj["x"].toDouble(), cornerObj["y"].toDouble()));
    }

    // DEBUG: Log loaded zone corners to verify they match current resolution
    if (m_isZoneDefined && m_zoneCorners.size() == 4) {
        qDebug() << "📍 LOADED ZONE CORNERS FROM FILE:";

        // Validate corners are within reasonable bounds for 250×400 rotated display
        bool cornersValid = true;
        for (int i = 0; i < 4; i++) {
            qDebug() << "   Corner" << i << ":" << m_zoneCorners[i];
            // Check if any corner is way outside current display bounds
            if (m_zoneCorners[i].x() < -50 || m_zoneCorners[i].x() > 300 ||
                m_zoneCorners[i].y() < -50 || m_zoneCorners[i].y() > 450) {
                cornersValid = false;
            }
        }

        if (!cornersValid) {
            qDebug() << "   ❌ INVALID ZONE - corners from old resolution! Auto-clearing zone.";
            qDebug() << "   Please recalibrate zone on Ball Zone Calibration screen.";
            m_zoneCorners.clear();
            m_isZoneDefined = false;
        } else {
            qDebug() << "   ✅ Zone corners valid for current resolution";
        }
    }

    // Load marker corners (from extrinsic calibration)
    m_markerCorners.clear();
    QJsonArray markerCorners = json["marker_corners"].toArray();
    for (const auto &cornerVal : markerCorners) {
        QJsonObject cornerObj = cornerVal.toObject();
        m_markerCorners.append(QPointF(cornerObj["x"].toDouble(), cornerObj["y"].toDouble()));
    }

    if (m_isIntrinsicCalibrated) {
        m_status = "Calibration loaded";
        qDebug() << "Camera calibration loaded from" << calibPath;
        qDebug() << "  Focal length: fx=" << m_fx << "fy=" << m_fy;
        qDebug() << "  Intrinsic calibrated:" << m_isIntrinsicCalibrated;
        qDebug() << "  Extrinsic calibrated:" << m_isExtrinsicCalibrated;
        qDebug() << "  Ball zone calibrated:" << m_isBallZoneCalibrated;
        qDebug() << "  Zone defined:" << m_isZoneDefined;
    }

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit ballZoneCalibrationChanged();
    emit zoneDefinedChanged();
    emit statusChanged();
}

void CameraCalibration::resetCalibration() {
    m_isIntrinsicCalibrated = false;
    m_isExtrinsicCalibrated = false;
    m_isBallZoneCalibrated = false;
    m_isZoneDefined = false;
    m_cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_distCoeffs = cv::Mat::zeros(5, 1, CV_64F);
    m_fx = m_fy = m_cx = m_cy = 0.0;
    m_cameraHeight = m_cameraTilt = m_cameraDistance = 0.0;
    m_ballCenterX = m_ballCenterY = m_ballRadius = 0.0;
    m_zoneCorners.clear();
    m_markerCorners.clear();
    m_progress = 0;
    m_status = "Calibration reset";

    saveCalibration();

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit ballZoneCalibrationChanged();
    emit zoneDefinedChanged();
    emit statusChanged();
    emit progressChanged();
}

// ============================================================================
// BALL ZONE CALIBRATION
// ============================================================================

void CameraCalibration::detectBallForZoneCalibration() {
    if (!m_frameProvider) {
        qWarning() << "No frame provider available";
        emit calibrationFailed("No camera feed available");
        return;
    }

    // Get current frame
    QImage qimg = m_frameProvider->requestImage("", nullptr, QSize());
    if (qimg.isNull()) {
        qWarning() << "Failed to capture frame for ball detection";
        emit calibrationFailed("Failed to capture frame");
        return;
    }

    // Convert to OpenCV format
    cv::Mat frame(qimg.height(), qimg.width(), CV_8UC1);
    memcpy(frame.data, qimg.bits(), qimg.width() * qimg.height());

    // Preprocess frame
    cv::Mat processed = frame.clone();
    cv::GaussianBlur(processed, processed, cv::Size(5, 5), 1.5);

    // Create CLAHE for contrast enhancement
    cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(2.0, cv::Size(8, 8));
    clahe->apply(processed, processed);

    // Detect circles using HoughCircles - GOLF BALL SIZE ONLY
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(processed, circles, cv::HOUGH_GRADIENT, 1,
                     processed.rows / 16,  // Min distance between centers
                     100,  // Canny upper threshold
                     15,   // Accumulator threshold
                     20,   // Min radius - golf ball size at camera distance (~25 pixels)
                     30);  // Max radius - golf ball size at camera distance (~25 pixels)

    if (circles.empty()) {
        qWarning() << "No ball detected in frame";
        emit calibrationFailed("No ball detected. Make sure ball is visible and well-lit.");
        return;
    }

    qDebug() << "Calibration: Found" << circles.size() << "circle candidates, selecting best...";

    // Score each circle based on proximity to center and reasonable size
    // Ball should be near center of frame since that's where we expect it
    double frameCenterX = processed.cols / 2.0;
    double frameCenterY = processed.rows / 2.0;
    double idealRadius = 25.0;  // Ideal golf ball radius (middle of 20-30 range)

    cv::Vec3f bestCircle;
    double bestScore = -1.0;

    for (const auto& circle : circles) {
        double cx = circle[0];
        double cy = circle[1];
        double r = circle[2];

        // Distance from center of frame (normalized 0-1)
        double distFromCenter = std::sqrt(std::pow(cx - frameCenterX, 2) +
                                         std::pow(cy - frameCenterY, 2));
        double maxDist = std::sqrt(std::pow(frameCenterX, 2) + std::pow(frameCenterY, 2));
        double centerScore = 1.0 - (distFromCenter / maxDist);

        // Radius score (how close to ideal ball size)
        double radiusScore = 1.0 - std::abs(r - idealRadius) / idealRadius;

        // Combined score (weight center proximity heavily)
        double score = 0.7 * centerScore + 0.3 * radiusScore;

        // Only log scoring details in debug mode (avoid spam)
        // qDebug() << "  Circle at (" << cx << "," << cy << ") r=" << r << " score=" << score;

        if (score > bestScore) {
            bestScore = score;
            bestCircle = circle;
        }
    }

    double centerX = bestCircle[0];
    double centerY = bestCircle[1];
    double radius = bestCircle[2];

    // Calculate confidence based on score
    double confidence = std::min(0.95, bestScore);

    qDebug() << "Calibration: Selected ball at (" << centerX << "," << centerY << ") radius:" << radius;

    // Save ball zone calibration
    setBallZone(centerX, centerY, radius);

    // Emit signal for UI update
    emit ballDetectedForZone(centerX, centerY, radius, confidence);
}

void CameraCalibration::setBallZone(double centerX, double centerY, double radius) {
    m_ballCenterX = centerX;
    m_ballCenterY = centerY;
    m_ballRadius = radius;
    m_isBallZoneCalibrated = true;

    qDebug() << "✅ Ball zone calibration complete → Center:(" << m_ballCenterX << "," << m_ballCenterY << ") Radius:" << m_ballRadius << "px";

    // Save to settings
    saveCalibration();

    emit ballZoneCalibrationChanged();
    emit calibrationComplete("Ball zone calibration successful");
}

void CameraCalibration::setBallEdgePoints(const QList<QPointF> &edgePoints) {
    if (edgePoints.size() < 3) {
        qWarning() << "Need at least 3 points to fit circle";
        emit calibrationFailed("Need at least 3 edge points");
        return;
    }

    // Convert to OpenCV format
    std::vector<cv::Point2f> points;
    for (const auto &pt : edgePoints) {
        points.push_back(cv::Point2f(pt.x(), pt.y()));
    }

    // Fit circle using least squares (algebraic fit)
    // Method: solving linear system for circle equation (x-cx)^2 + (y-cy)^2 = r^2
    int n = points.size();
    cv::Mat A(n, 3, CV_64F);
    cv::Mat b(n, 1, CV_64F);

    for (int i = 0; i < n; i++) {
        double x = points[i].x;
        double y = points[i].y;
        A.at<double>(i, 0) = 2.0 * x;
        A.at<double>(i, 1) = 2.0 * y;
        A.at<double>(i, 2) = 1.0;
        b.at<double>(i, 0) = x * x + y * y;
    }

    // Solve least squares: A^T * A * x = A^T * b
    cv::Mat AtA = A.t() * A;
    cv::Mat Atb = A.t() * b;
    cv::Mat solution;
    cv::solve(AtA, Atb, solution, cv::DECOMP_LU);

    double cx = solution.at<double>(0, 0);
    double cy = solution.at<double>(1, 0);
    double c = solution.at<double>(2, 0);
    double r = std::sqrt(cx * cx + cy * cy + c);

    qDebug() << "Fitted circle from" << n << "points:";
    qDebug() << "  Center: (" << cx << "," << cy << ")";
    qDebug() << "  Radius:" << r << "pixels";

    // Set ball zone with fitted circle
    setBallZone(cx, cy, r);

    // Emit signal with high confidence (manual input)
    emit ballDetectedForZone(cx, cy, r, 0.99);
}

void CameraCalibration::setZoneCorners(const QList<QPointF> &corners) {
    if (corners.size() != 4) {
        qWarning() << "Need exactly 4 corners for zone definition";
        emit calibrationFailed("Need exactly 4 corner points");
        return;
    }

    m_zoneCorners = corners;
    m_isZoneDefined = true;

    qDebug() << "Zone corners defined:";
    for (int i = 0; i < 4; i++) {
        qDebug() << "  Corner" << i << ":" << corners[i];
    }

    // Save to settings
    saveCalibration();

    emit zoneDefinedChanged();
    emit calibrationComplete("Zone boundary defined successfully");
}

void CameraCalibration::useMarkerCornersForZone() {
    if (!m_isExtrinsicCalibrated || m_markerCorners.size() != 4) {
        qWarning() << "Extrinsic calibration markers not available";
        emit calibrationFailed("Complete extrinsic calibration first");
        return;
    }

    qDebug() << "Using extrinsic calibration marker corners for zone:";
    for (int i = 0; i < 4; i++) {
        qDebug() << "  Marker" << i << ":" << m_markerCorners[i];
    }

    // Use marker corners directly as zone corners
    setZoneCorners(m_markerCorners);
}

QString CameraCalibration::formatCalibrationSummary() const {
    QString summary;
    summary += QString("Focal Length: fx=%1 fy=%2 pixels\n").arg(m_fx, 0, 'f', 1).arg(m_fy, 0, 'f', 1);
    summary += QString("Principal Point: (%1, %2)\n").arg(m_cx, 0, 'f', 1).arg(m_cy, 0, 'f', 1);
    summary += QString("Distortion: k1=%1 k2=%2 k3=%3\n")
                   .arg(m_distCoeffs.at<double>(0, 0), 0, 'f', 4)
                   .arg(m_distCoeffs.at<double>(1, 0), 0, 'f', 4)
                   .arg(m_distCoeffs.at<double>(4, 0), 0, 'f', 4);

    if (m_isExtrinsicCalibrated) {
        summary += QString("\nCamera Height: %1 m\n").arg(m_cameraHeight, 0, 'f', 2);
        summary += QString("Camera Tilt: %1°\n").arg(m_cameraTilt, 0, 'f', 1);
        summary += QString("Camera Distance: %1 m\n").arg(m_cameraDistance, 0, 'f', 2);
    }

    if (m_isBallZoneCalibrated) {
        summary += QString("\nBall Position: (%1, %2)\n").arg(m_ballCenterX, 0, 'f', 1).arg(m_ballCenterY, 0, 'f', 1);
        summary += QString("Ball Radius: %1 px\n").arg(m_ballRadius, 0, 'f', 1);
    }

    return summary;
}

// ============================================================================
// LIVE BALL TRACKING (Temporal Tracking with Adaptive Lighting)
// ============================================================================

QVariantMap CameraCalibration::detectBallLive() {
    QVariantMap result;
    result["detected"] = false;
    result["x"] = 0.0;
    result["y"] = 0.0;
    result["radius"] = 0.0;
    result["inZone"] = false;

    if (!m_frameProvider) {
        return result;
    }

    // Get latest frame UNROTATED (crop coords are in unrotated space)
    // The frame provider rotates for display, but we need unrotated for detection
    cv::Mat frame = m_frameProvider->getLatestFrameUnrotated();
    if (frame.empty()) {
        qDebug() << "❌ detectBallLive: No frame available from provider";
        return result;
    }

    // Log frame dimensions once at startup to verify sensor output
    static bool dimensionsLogged = false;
    if (!dimensionsLogged) {
        qDebug() << "📐 detectBallLive frame size:" << frame.cols << "×" << frame.rows
                 << "| Expected: 640×400 @ 240 FPS (maximum speed, before rotation)";
        dimensionsLogged = true;
    }

    // Convert to grayscale if needed
    cv::Mat gray;
    if (frame.channels() == 3) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = frame.clone();
    }

    // ========== ADAPTIVE LIGHTING DETECTION ==========
    // Calculate mean brightness to adapt detection parameters
    cv::Scalar meanBrightness = cv::mean(gray);
    double brightness = meanBrightness[0];  // 0-255 range

    // Adapt HoughCircles parameters based on lighting
    // Tighter parameters to reduce false positives (was getting 80+ false circles)
    int cannyThreshold = static_cast<int>(std::max(60.0, std::min(140.0, brightness * 0.6)));
    int accumulatorThreshold = static_cast<int>(std::max(12.0, std::min(20.0, brightness * 0.08)));

    // Only log lighting changes significantly (avoid terminal spam)
    static double lastBrightness = 0;
    if (std::abs(brightness - lastBrightness) > 10.0 || lastBrightness == 0) {
        qDebug() << "Scene brightness:" << brightness << "→ Canny:" << cannyThreshold << "Acc:" << accumulatorThreshold;
        lastBrightness = brightness;
    }

    // Preprocess frame for better ball detection
    cv::Mat processed;
    cv::GaussianBlur(gray, processed, cv::Size(5, 5), 1.5);

    // ========== BACKGROUND SUBTRACTION (Eliminate Texture Circles) ==========
    if (m_hasBaseline && !m_baselineFrame.empty()) {
        // Subtract baseline from current frame
        cv::Mat diff;
        cv::absdiff(processed, m_baselineFrame, diff);

        // Threshold to create binary mask (ball shows up, texture doesn't)
        cv::Mat mask;
        cv::threshold(diff, mask, 25, 255, cv::THRESH_BINARY);

        // Apply morphological opening to remove small noise
        cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
        cv::morphologyEx(mask, mask, cv::MORPH_OPEN, kernel);

        // Store difference frame for screenshot
        m_lastDifferenceFrame = mask.clone();

        // Apply CLAHE to current frame for edge detection
        double clipLimit = (brightness < 100) ? 3.0 : 2.0;
        cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(clipLimit, cv::Size(8, 8));
        clahe->apply(processed, processed);

        // Apply mask - keep CLAHE edges only where ball is (not texture)
        processed.setTo(0, mask == 0);  // Black out areas with no difference

        qDebug() << "Background subtraction ACTIVE - texture eliminated";
    } else {
        // Use CLAHE for contrast enhancement (adaptive to lighting) - only when no baseline
        double clipLimit = (brightness < 100) ? 3.0 : 2.0;  // More aggressive in dark scenes
        cv::Ptr<cv::CLAHE> clahe = cv::createCLAHE(clipLimit, cv::Size(8, 8));
        clahe->apply(processed, processed);
    }

    // Detect circles using HoughCircles - GOLF BALL SIZE ONLY
    // Golf ball @ 7ft with 12mm lens + 1.6× crop: ~40-50 px diameter (20-25 px radius)
    // ADAPTIVE parameters for varying lighting conditions
    std::vector<cv::Vec3f> circles;

    // Log frame dimensions for debugging (every time for now to verify)
    static int logCounter = 0;
    if (logCounter % 30 == 0) {  // Log every 30 frames (~1 second)
        qDebug() << "detectBallLive analyzing frame size:" << processed.cols << "x" << processed.rows
                 << "| brightness:" << brightness;
    }
    logCounter++;

    cv::HoughCircles(processed, circles, cv::HOUGH_GRADIENT, 1,
                     processed.rows / 12,      // Min distance between circles
                     cannyThreshold,            // Canny threshold (ADAPTIVE - was hardcoded 90)
                     accumulatorThreshold,      // Accumulator threshold (ADAPTIVE - was hardcoded 18)
                     17,                        // Min radius: golf ball only (640×400 @ 240 FPS: 34-44px diameter)
                     22);                       // Max radius: golf ball only (tight range to filter carpet)

    // Only log if detection changes significantly (suppress "0 candidates" spam)
    static int lastCircleCount = 0;
    static qint64 lastZeroLogTime = 0;

    if (circles.size() == 0) {
        // Throttle "0 candidates" logging to once every 2 seconds
        qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
        if (currentTime - lastZeroLogTime > 2000 || lastZeroLogTime == 0) {
            qDebug() << "⚠ HoughCircles: 0 candidates | brightness:" << brightness
                     << "| Canny=" << cannyThreshold << "Acc=" << accumulatorThreshold;
            lastZeroLogTime = currentTime;
        }
        lastCircleCount = 0;
    } else {
        // Always log when circles ARE detected (critical for debugging)
        qDebug() << "✓ HoughCircles detected:" << circles.size() << "candidates";
        // Log ALL circle sizes for debugging
        for (size_t i = 0; i < std::min(circles.size(), size_t(5)); i++) {
            qDebug() << "  Circle" << i << "- pos:(" << circles[i][0] << "," << circles[i][1]
                     << ") radius:" << circles[i][2] << "px";
        }
        lastCircleCount = circles.size();
    }

    if (circles.empty()) {
        // Track missed frames
        m_missedFrames++;

        // If we have Kalman filter, use prediction even without measurement
        // This is the KEY advantage of Kalman - handles brief occlusions
        if (m_kalmanInitialized && m_missedFrames < 10 && m_trackingConfidence > 3) {
            // PREDICT without measurement (ball might be briefly occluded)
            cv::Mat prediction = m_kalmanFilter.predict();
            m_smoothedBallX = prediction.at<float>(0);
            m_smoothedBallY = prediction.at<float>(1);

            // Transform to rotated coordinates for display
            int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
            double displayX = m_smoothedBallY;
            double displayY = frameWidth - m_smoothedBallX;

            result["detected"] = true;
            result["x"] = displayX;
            result["y"] = displayY;
            result["radius"] = m_lastBallRadius;

            // Check zone with predicted position (with edge tolerance)
            bool inZone = false;
            if (m_isZoneDefined && m_zoneCorners.size() == 4) {
                std::vector<cv::Point2f> zonePoints;
                int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
                for (const auto &corner : m_zoneCorners) {
                    // Inverse 90° CW rotation: (x_rot, y_rot) → (frameWidth - y_rot, x_rot)
                    float unrotatedX = static_cast<float>(frameWidth) - corner.y();
                    float unrotatedY = corner.x();
                    zonePoints.push_back(cv::Point2f(unrotatedX, unrotatedY));
                }
                double distance = cv::pointPolygonTest(zonePoints,
                    cv::Point2f(m_smoothedBallX, m_smoothedBallY), true);
                inZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
            }
            result["inZone"] = inZone;

            qDebug() << "Kalman prediction (no measurement):" << m_smoothedBallX << "," << m_smoothedBallY;
        } else {
            // Lost tracking after too many missed frames
            if (m_missedFrames > 15) {
                // Throttle "lost tracking" spam to once every 5 seconds (avoid spam when no ball present)
                static qint64 lastLostTrackingLogTime = 0;
                qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

                if (currentTime - lastLostTrackingLogTime > 5000 || lastLostTrackingLogTime == 0) {
                    qDebug() << "Lost ball tracking (no ball visible or too dark)";
                    lastLostTrackingLogTime = currentTime;
                }

                m_liveTrackingInitialized = false;
                m_kalmanInitialized = false;
                m_trackingConfidence = 0;
            }
        }
        return result;
    }

    // ========== TEMPLATE MATCHING REMOVED ==========
    // Replaced with edge density verification (see verifyBallAppearance)

    // ========== SIMPLE BRIGHTNESS-BASED TRACKING ==========
    // USER REQUIREMENT: Track the WHITEST object (golf ball)
    // Strategy: Find brightest circle IN THE ZONE (ignore bright lights outside zone)

    cv::Vec3f bestCircle;
    double bestBrightness = -1.0;
    int circlesInZone = 0;

    for (const auto& circle : circles) {
        double cx = circle[0];
        double cy = circle[1];
        double r = circle[2];

        // Check if circle center is in the zone (with edge tolerance)
        bool inZone = false;
        if (m_isZoneDefined && m_zoneCorners.size() == 4) {
            std::vector<cv::Point2f> zonePoints;

            // Debug: log zone transform once
            static bool loggedZone = false;
            if (!loggedZone) {
                qDebug() << "===== ZONE TRANSFORM DEBUG =====";
                qDebug() << "Frame dimensions:" << processed.cols << "x" << processed.rows;
                for (int i = 0; i < m_zoneCorners.size(); i++) {
                    qDebug() << "  Corner" << i << "rotated:" << m_zoneCorners[i].x() << "," << m_zoneCorners[i].y();
                }
            }

            int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
            for (const auto& corner : m_zoneCorners) {
                // Inverse 90° CW rotation: (x_rot, y_rot) → (frameWidth - y_rot, x_rot)
                float unrotatedX = static_cast<float>(frameWidth) - corner.y();
                float unrotatedY = corner.x();
                zonePoints.push_back(cv::Point2f(unrotatedX, unrotatedY));

                if (!loggedZone) {
                    qDebug() << "    → unrotated:" << unrotatedX << "," << unrotatedY;
                }
            }

            if (!loggedZone) {
                qDebug() << "First circle pos:" << cx << "," << cy << "radius:" << r;
                loggedZone = true;
            }

            // pointPolygonTest returns signed distance:
            // > 0: inside, 0: on edge, < 0: outside
            // With tolerance: allow ball even when slightly outside edge
            double distance = cv::pointPolygonTest(zonePoints, cv::Point2f(cx, cy), true);
            inZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
        }

        // ========== ZONE FILTERING (Initial Lock vs Tracking) ==========
        // If no zone defined, accept all golf ball sized circles
        // If zone defined but invalid, also accept all circles
        if (m_isZoneDefined && m_zoneCorners.size() == 4) {
            // Zone is defined - only accept circles in zone for initial lock
            if (!m_liveTrackingInitialized && !inZone) {
                continue;  // Not tracking yet - skip circles outside zone
            }
        }
        // No zone defined or zone invalid - accept all circles

        // Track whether this circle is in zone for scoring purposes
        if (inZone) {
            circlesInZone++;
        }

        // STRICT SIZE FILTER: Only accept circles matching golf ball size (17-22 pixels radius)
        if (r < 17.0 || r > 22.0) {
            continue;  // Not golf ball size - reject immediately
        }

        // ========== GOLF BALL APPEARANCE VERIFICATION ==========
        // Use edge density to verify this circle looks like a golf ball (has dimples)
        // Golf ball: 8-20% edge density (dimples create edges)
        // Carpet: 1-5% edge density (smooth gradients)
        if (!verifyBallAppearance(gray, static_cast<int>(cx), static_cast<int>(cy), static_cast<int>(r))) {
            // qDebug() << "  Circle at (" << cx << "," << cy << ") R=" << r << "REJECTED by edge density check";
            continue;  // Doesn't look like golf ball - reject
        }

        // ========== ADAPTIVE FILTERS FOR HEAT-SEEKING MODE ==========
        // When tracking, check if this circle is near last position
        // WIDER search radius for ball movement and occlusion handling
        bool nearLastPosition = false;
        double distFromLast = 0.0;

        if (m_liveTrackingInitialized) {
            // Distance from last smoothed position
            distFromLast = std::sqrt(std::pow(cx - m_smoothedBallX, 2) +
                                     std::pow(cy - m_smoothedBallY, 2));

            // WIDENED search radius - allows ball to move without losing lock
            // High confidence (10/10) = 50px search, low confidence (0/10) = 150px search
            // This prevents ball from jumping to false circles when it moves
            double searchRadius = 50.0 + (10 - m_trackingConfidence) * 10.0;  // 50-150px range
            nearLastPosition = (distFromLast < searchRadius);
        }

        // ========== SPHERICAL/CIRCULARITY CHECK ==========
        // DISABLED - too strict without background subtraction
        // Background subtraction handles texture noise elimination
        // Size + Zone + Temporal tracking is sufficient for ball detection

        // ========== SHAPE-BASED DETECTION FOR ANY COLOR BALL ==========
        // NO brightness filtering - works with white, yellow, orange, any color ball
        // Detection based ONLY on: SIZE (20-30px) + SHAPE (circular) + ZONE + TEMPORAL

        // COMBINED SCORE: Radius match + Temporal proximity
        // Perfect radius match (r=25) gets score of 100, edges (r=20 or 30) get score of 0
        double radiusScore = 100.0 * (1.0 - std::min(1.0, std::abs(r - 25.0) / 5.0));
        double combinedScore = radiusScore;

        // HEAT-SEEKING BONUS: Proximity-based scoring for temporal consistency
        // MLM2 Pro-style MAGNETIC LOCK - once locked, stay locked
        if (nearLastPosition) {
            // EXPONENTIAL proximity score: creates magnetic lock effect
            // 0px = 10000 pts, 50px = 7500 pts, 100px = 5000 pts, 150px = 0 pts
            double normalizedDist = distFromLast / 150.0;  // 0.0 to 1.0
            double proximityScore = 10000.0 * (1.0 - normalizedDist * normalizedDist);
            combinedScore += proximityScore;  // HUGE bonus - ball won't jump away
        }

        // Pick the best circle IN THE ZONE (brightness + size preference)
        if (combinedScore > bestBrightness) {
            bestBrightness = combinedScore;  // Actually storing combined score
            bestCircle = circle;
        }
    }

    // ========== MULTI-BALL REJECTION ==========
    // If too many circles in zone, reject all (multiple balls or too much noise)
    if (circlesInZone > 2 && !m_liveTrackingInitialized) {
        qDebug() << "⚠️ WARNING: Too many objects in zone (" << circlesInZone << ") - cannot determine which is the ball";
        qDebug() << "   → Remove extra balls or adjust lighting to reduce false detections";

        QVariantMap result;
        result["detected"] = false;
        result["inZone"] = false;
        return result;
    }

    // Did we find any circles?
    if (bestBrightness < 0) {
        qDebug() << "No valid golf balls detected (total circles:" << circles.size() << ")";
        m_missedFrames++;

        // HEAT-SEEKING MISSILE MODE: VELOCITY PREDICTION
        // When club passes in front, predict where ball is based on velocity
        // Extended window (60 frames @ 180fps = 0.33 seconds) for club occlusion
        if (m_liveTrackingInitialized && m_missedFrames < 60) {
            // PREDICT ball position using velocity
            double predictedX = m_smoothedBallX + (m_ballVelocityX * m_missedFrames);
            double predictedY = m_smoothedBallY + (m_ballVelocityY * m_missedFrames);

            // If predicted position goes off-screen, ball left the zone → reset tracking
            if (predictedX < 0 || predictedX >= 640 || predictedY < 0 || predictedY >= 480) {
                qDebug() << "⚠️ Ball left frame - predicted position off-screen (" << predictedX << "," << predictedY << ")";
                qDebug() << "   Resetting tracking (velocity prediction stopped)";

                m_liveTrackingInitialized = false;
                m_kalmanInitialized = false;
                m_trackingConfidence = 0;
                m_missedFrames = 0;

                result["detected"] = false;
                result["inZone"] = false;
                return result;
            }

            qDebug() << "⚡ PREDICTION mode (occlusion) - missed:" << m_missedFrames
                     << "frames | velocity:(" << m_ballVelocityX << "," << m_ballVelocityY << ")"
                     << "| predicted:(" << predictedX << "," << predictedY << ")";

            result["detected"] = true;
            result["x"] = predictedX;
            result["y"] = predictedY;
            result["radius"] = m_lastBallRadius;

            // Check if predicted position is in zone (with edge tolerance)
            bool inZone = false;
            if (m_isZoneDefined && m_zoneCorners.size() == 4) {
                std::vector<cv::Point2f> zonePoints;
                for (const auto &corner : m_zoneCorners) {
                    // Transform zone corners from original coords to cropped coords
                    float transformedX = corner.x() - m_cropOffsetX;
                    float transformedY = corner.y() - m_cropOffsetY;
                    zonePoints.push_back(cv::Point2f(transformedX, transformedY));
                }
                double distance = cv::pointPolygonTest(zonePoints,
                    cv::Point2f(predictedX, predictedY), true);
                inZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
            }
            result["inZone"] = inZone;

            return result;
        } else {
            // Too many missed frames - truly lost
            return result;
        }
    }

    qDebug() << "Circles in zone:" << circlesInZone << "Selected circle -"
             << "Position:(" << bestCircle[0] << "," << bestCircle[1] << ")"
             << "Radius:" << bestCircle[2] << "pixels | Score:" << bestBrightness;

    double ballX = bestCircle[0];
    double ballY = bestCircle[1];
    double ballRadius = bestCircle[2];

    qDebug() << "BALL DETECTED - Position:(" << ballX << "," << ballY << ") Radius:" << ballRadius << "pixels";

    // Get frame dimensions for coordinate transforms
    int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
    int frameHeight = m_croppedHeight > 0 ? m_croppedHeight : 480;

    // Check if detected ball is inside zone (before anti-jump filter)
    bool detectedBallInZone = false;
    if (m_isZoneDefined && m_zoneCorners.size() == 4) {
        std::vector<cv::Point2f> zonePoints;
        for (const auto &corner : m_zoneCorners) {
            // Inverse 90° CW rotation: (x_rot, y_rot) → (frameWidth - y_rot, x_rot)
            float unrotatedX = static_cast<float>(frameWidth) - corner.y();
            float unrotatedY = corner.x();
            zonePoints.push_back(cv::Point2f(unrotatedX, unrotatedY));
        }
        double distance = cv::pointPolygonTest(zonePoints, cv::Point2f(ballX, ballY), true);
        detectedBallInZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
    }

    // Check if last smoothed position was in bounds (not way off-screen from velocity prediction)
    bool lastPositionInBounds = (m_smoothedBallX >= 0 && m_smoothedBallX < frameWidth &&
                                  m_smoothedBallY >= 0 && m_smoothedBallY < frameHeight);

    // CRITICAL FIX: If last position is WAY outside frame, reset tracking immediately
    if (m_liveTrackingInitialized && !lastPositionInBounds) {
        qDebug() << "🔄 RESET: Last position (" << m_smoothedBallX << "," << m_smoothedBallY
                 << ") outside frame bounds - resetting tracking";
        m_liveTrackingInitialized = false;
        m_kalmanInitialized = false;
        m_trackingConfidence = 0;
        m_missedFrames = 0;
    }

    // ========== ZONE RE-ENTRY DETECTION ==========
    // If ball is detected IN ZONE but last position was out of bounds or way off,
    // this is a re-entry from outside → force accept and reset tracking
    bool forceAcceptZoneReEntry = (detectedBallInZone && !lastPositionInBounds && m_liveTrackingInitialized);

    if (forceAcceptZoneReEntry) {
        qDebug() << "🎯 ZONE RE-ENTRY: Ball re-entered hitbox at (" << ballX << "," << ballY << ")";
        qDebug() << "   Forcing re-lock (last position was off-screen at " << m_smoothedBallX << "," << m_smoothedBallY << ")";

        // Reset tracking to new ball position
        m_smoothedBallX = ballX;
        m_smoothedBallY = ballY;
        m_ballVelocityX = 0.0;
        m_ballVelocityY = 0.0;
        m_missedFrames = 0;
        m_trackingConfidence = 10;
        // Don't run anti-jump filter below
    }
    // ========== ANTI-JUMP FILTER ==========
    // Reject detections that jump too far from last smoothed position
    // This prevents false positives from HoughCircles that are far away
    // BUT: Disable during re-acquisition (when frames were recently missed) or zone re-entry
    else if (m_liveTrackingInitialized && m_missedFrames < 3) {
        // Only apply strict filter when tracking is stable (< 3 missed frames)
        // If we missed 3+ frames, ball may have exited/re-entered - allow re-acquisition
        double jumpDist = std::sqrt(std::pow(ballX - m_smoothedBallX, 2) +
                                   std::pow(ballY - m_smoothedBallY, 2));
        const double MAX_JUMP_PX = 8.0;  // Maximum allowed jump per frame at 180 FPS (very strict for stationary ball)

        if (jumpDist > MAX_JUMP_PX) {
            qDebug() << "⚠ ANTI-JUMP FILTER: Rejecting detection - jump of" << jumpDist
                     << "pixels exceeds threshold of" << MAX_JUMP_PX
                     << "| Keeping last position (" << m_smoothedBallX << "," << m_smoothedBallY << ")";

            // Use predicted position based on velocity instead
            double predictedX = m_smoothedBallX + m_ballVelocityX;
            double predictedY = m_smoothedBallY + m_ballVelocityY;

            ballX = predictedX;
            ballY = predictedY;

            m_missedFrames++;  // Count as partial miss

            qDebug() << "  Using velocity prediction: (" << predictedX << "," << predictedY << ")";
        }
    } else if (m_missedFrames >= 3) {
        qDebug() << "⚡ RE-ACQUISITION MODE: Missed" << m_missedFrames
                 << "frames - disabling anti-jump filter for ball re-entry";
    }

    // ========== DEBUG VISUALIZATION ==========
    if (m_debugMode) {
        // Create color debug frame from PROCESSED image (same as what HoughCircles sees)
        // This shows the CLAHE-enhanced bright image, not the raw dark frame
        cv::Mat debugFrame;
        cv::cvtColor(processed, debugFrame, cv::COLOR_GRAY2BGR);

        // Draw ALL detected circles in BLUE with radius labels
        for (const auto& circle : circles) {
            double cx = circle[0];
            double cy = circle[1];
            double r = circle[2];

            // Draw circle in BLUE
            cv::circle(debugFrame, cv::Point(cx, cy), r, cv::Scalar(255, 100, 0), 1);  // Blue

            // Draw radius value (shape-based detection)
            QString radiusText = QString("R=%1").arg(static_cast<int>(r));
            cv::putText(debugFrame, radiusText.toStdString(),
                       cv::Point(cx - 15, cy - r - 5),
                       cv::FONT_HERSHEY_SIMPLEX, 0.4, cv::Scalar(255, 255, 0), 1);  // Cyan text
        }

        // Draw SELECTED circle (EXACT ball dimensions) in GREEN
        cv::Scalar selectedColor = cv::Scalar(0, 255, 0);  // Green

        // Outer circle - exact ball radius
        cv::circle(debugFrame, cv::Point(ballX, ballY), ballRadius, selectedColor, 3);

        // Inner circle for clarity
        cv::circle(debugFrame, cv::Point(ballX, ballY), ballRadius - 2, selectedColor, 1);

        // Center dot
        cv::circle(debugFrame, cv::Point(ballX, ballY), 2, selectedColor, -1);

        // Crosshair
        cv::line(debugFrame, cv::Point(ballX - 6, ballY), cv::Point(ballX + 6, ballY), selectedColor, 1);
        cv::line(debugFrame, cv::Point(ballX, ballY - 6), cv::Point(ballX, ballY + 6), selectedColor, 1);

        // Draw radius info (shape-based detection)
        QString ballText = QString("BALL: R=%1px (ANY COLOR)")
            .arg(static_cast<int>(ballRadius));
        cv::putText(debugFrame, ballText.toStdString(),
                   cv::Point(ballX - 70, ballY + ballRadius + 20),
                   cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(0, 255, 0), 2);

        // Draw info text - Shape-based tracking
        QString infoText = QString("Detected: %1 | In Zone: %2 | Best Score: %3")
            .arg(circles.size())
            .arg(circlesInZone)
            .arg(static_cast<int>(bestBrightness));
        cv::putText(debugFrame, infoText.toStdString(),
                   cv::Point(10, frame.rows - 40),
                   cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(255, 255, 255), 1);

        QString strategyText = m_hasBaseline ?
            QString("Strategy: BACKGROUND SUBTRACTION + Shape") :
            QString("Strategy: SHAPE-BASED (Size + Circularity + Zone + Temporal)");
        cv::putText(debugFrame, strategyText.toStdString(),
                   cv::Point(10, frame.rows - 20),
                   cv::FONT_HERSHEY_SIMPLEX, 0.5,
                   m_hasBaseline ? cv::Scalar(0, 255, 0) : cv::Scalar(255, 255, 255), 1);

        // Rotate debug frame 90° clockwise to match display orientation (portrait)
        cv::Mat rotatedDebugFrame;
        cv::rotate(debugFrame, rotatedDebugFrame, cv::ROTATE_90_CLOCKWISE);

        // Store rotated frame for screenshot capability
        m_lastDebugFrame = rotatedDebugFrame.clone();
    }

    // ========== INSTANT TRACKING MODE + VELOCITY PREDICTION ==========
    // Calculate velocity for prediction (handle club occlusion)
    if (m_liveTrackingInitialized) {
        // Update velocity based on position change
        double dx = ballX - m_smoothedBallX;
        double dy = ballY - m_smoothedBallY;

        // Smooth velocity with exponential moving average (alpha = 0.3)
        // This reduces noise while staying responsive
        m_ballVelocityX = 0.3 * dx + 0.7 * m_ballVelocityX;
        m_ballVelocityY = 0.3 * dy + 0.7 * m_ballVelocityY;

        qDebug() << "Velocity updated: vx=" << m_ballVelocityX << "vy=" << m_ballVelocityY;

        // Apply temporal smoothing to ball position (MLM2 Pro-style smooth tracking)
        // Exponential moving average: alpha = 0.4 (40% new, 60% old)
        // This eliminates jitter while maintaining responsiveness
        m_smoothedBallX = 0.4 * ballX + 0.6 * m_smoothedBallX;
        m_smoothedBallY = 0.4 * ballY + 0.6 * m_smoothedBallY;
        m_smoothedBallRadius = 0.4 * ballRadius + 0.6 * m_smoothedBallRadius;  // Smooth radius too
        qDebug() << "Smoothed position:" << m_smoothedBallX << "," << m_smoothedBallY
                 << "radius:" << m_smoothedBallRadius;
    } else {
        // First detection - use raw values
        m_smoothedBallX = ballX;
        m_smoothedBallY = ballY;
        m_smoothedBallRadius = ballRadius;
    }

    m_lastBallRadius = ballRadius;

    // Track initialization status
    if (!m_liveTrackingInitialized) {
        // Check if ball is in roughly same position as last frame (stability check)
        bool stablePosition = false;
        if (m_lastBallX > 0 && m_lastBallY > 0) {
            double distFromLast = std::sqrt(std::pow(ballX - m_lastBallX, 2) +
                                           std::pow(ballY - m_lastBallY, 2));
            stablePosition = (distFromLast < 10.0);  // Must be within 10px of last position
        }

        // Update last position
        m_lastBallX = ballX;
        m_lastBallY = ballY;

        // Require 2 consecutive stable detections before locking
        if (!stablePosition) {
            qDebug() << "Ball detected at (" << ballX << "," << ballY << ") - waiting for stability";
            // Transform to rotated coordinates for display
            double displayX = ballY;
            double displayY = frameWidth - ballX;
            result["detected"] = true;
            result["x"] = displayX;
            result["y"] = displayY;
            result["radius"] = ballRadius;
            result["inZone"] = true;
            return result;  // Show green circle but don't lock yet
        }

        qDebug() << "Ball STABLE at (" << ballX << "," << ballY << ") - locking onto ball";
        m_liveTrackingInitialized = true;
        m_trackingConfidence = 10;
        m_ballVelocityX = 0.0;  // Initialize velocity
        m_ballVelocityY = 0.0;

        // Template extraction removed - using edge density verification instead
    } else {
        m_trackingConfidence = 10;  // Always high confidence in instant mode
    }
    m_missedFrames = 0;

    // Check if ball is inside zone boundaries (using smoothed position with edge tolerance)
    bool inZone = false;
    if (m_isZoneDefined && m_zoneCorners.size() == 4) {
        std::vector<cv::Point2f> zonePoints;
        for (const auto &corner : m_zoneCorners) {
            // Inverse 90° CW rotation: (x_rot, y_rot) → (frameWidth - y_rot, x_rot)
            float unrotatedX = static_cast<float>(frameWidth) - corner.y();
            float unrotatedY = corner.x();
            zonePoints.push_back(cv::Point2f(unrotatedX, unrotatedY));
        }

        // With distance calculation enabled (true) to get signed distance
        // Allow ball to be tracked even when on edge of zone
        double distance = cv::pointPolygonTest(zonePoints,
            cv::Point2f(m_smoothedBallX, m_smoothedBallY), true);
        inZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
    }

    // Transform coordinates from unrotated space (640×400) to rotated space (400×640)
    // for camera 0 which is rotated 90° clockwise for display
    // Rotation transform: (x, y) → (y, width-x)
    double displayX = m_smoothedBallY;                    // Rotated X = original Y
    double displayY = frameWidth - m_smoothedBallX;        // Rotated Y = width - original X

    // Fill result with ROTATED coordinates for QML display
    result["detected"] = true;
    result["x"] = displayX;
    result["y"] = displayY;
    result["radius"] = m_smoothedBallRadius;  // Use smoothed radius to prevent jitter
    result["inZone"] = inZone;

    // ========== VIDEO RECORDING ==========
    if (m_isRecording && m_videoWriter.isOpened()) {
        // Create color version of frame for recording
        cv::Mat colorFrame;
        if (frame.channels() == 1) {
            cv::cvtColor(frame, colorFrame, cv::COLOR_GRAY2BGR);
        } else {
            colorFrame = frame.clone();
        }

        // Draw all overlays on the recorded frame
        // 1. Draw zone boundary (cyan box)
        if (m_isZoneDefined && m_zoneCorners.size() == 4) {
            std::vector<cv::Point> pts;
            for (const auto &corner : m_zoneCorners) {
                // Transform zone corners from original coords to cropped coords
                int transformedX = corner.x() - m_cropOffsetX;
                int transformedY = corner.y() - m_cropOffsetY;
                pts.push_back(cv::Point(transformedX, transformedY));
            }
            cv::polylines(colorFrame, pts, true, cv::Scalar(212, 188, 0), 2);  // Cyan BGR

            // Draw corner labels
            QStringList labels = {"FL", "FR", "BR", "BL"};
            for (int i = 0; i < 4 && i < m_zoneCorners.size(); i++) {
                int transformedX = m_zoneCorners[i].x() - m_cropOffsetX;
                int transformedY = m_zoneCorners[i].y() - m_cropOffsetY;
                cv::putText(colorFrame, labels[i].toStdString(),
                           cv::Point(transformedX + 5, transformedY - 5),
                           cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(255, 255, 255), 1);
            }
        }

        // 2. Draw ball tracking circle (green or red)
        if (result["detected"].toBool()) {
            cv::Scalar circleColor = inZone ? cv::Scalar(80, 175, 76) : cv::Scalar(0, 0, 255);  // Green or Red BGR
            cv::circle(colorFrame, cv::Point(m_smoothedBallX, m_smoothedBallY),
                      ballRadius + 3, circleColor, 3);
            cv::circle(colorFrame, cv::Point(m_smoothedBallX, m_smoothedBallY),
                      2, circleColor, -1);  // Center dot
        }

        // 3. Draw tracking status text
        QString statusText = result["detected"].toBool() ?
                            (inZone ? "TRACKING - IN ZONE" : "TRACKING - OUT OF ZONE") :
                            "SEARCHING...";
        cv::putText(colorFrame, statusText.toStdString(),
                   cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX, 0.7,
                   cv::Scalar(0, 255, 0), 2);

        // 4. Draw frame counter
        QString frameText = QString("Frame: %1").arg(m_recordedFrames);
        cv::putText(colorFrame, frameText.toStdString(),
                   cv::Point(10, colorFrame.rows - 10), cv::FONT_HERSHEY_SIMPLEX, 0.5,
                   cv::Scalar(255, 255, 255), 1);

        // Write frame to video
        m_videoWriter.write(colorFrame);
        m_recordedFrames++;
    }

    // ========== BALL ZONE STATE MACHINE UPDATE ==========
    // Update state machine with current detection results (ballX, ballY already in scope)
    bool ballDetected = result["detected"].toBool();
    bool ballInZone = result["inZone"].toBool();

    updateBallZoneState(ballDetected, ballInZone, ballX, ballY);

    // Add state machine info to result for UI display
    result["zoneState"] = getBallZoneStateString();
    result["zoneStateDisplay"] = getBallZoneStateDisplay();
    result["isReady"] = isSystemReady();
    result["isArmed"] = isSystemArmed();

    return result;
}

// ============================================================================
// VIDEO RECORDING
// ============================================================================

void CameraCalibration::startRecording() {
    if (m_isRecording) {
        qWarning() << "Already recording";
        return;
    }

    // Create recordings directory
    QString recordingsDir = QDir::homePath() + "/prgr/PRGR_Project/recordings";
    QDir dir;
    if (!dir.mkpath(recordingsDir)) {
        qWarning() << "Failed to create recordings directory:" << recordingsDir;
        return;
    }

    // Generate filename with timestamp
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss");
    m_recordingPath = recordingsDir + "/tracking_" + timestamp + ".mp4";

    // Open video writer (640x480 @ 30fps, H264 codec)
    int fourcc = cv::VideoWriter::fourcc('m', 'p', '4', 'v');  // MP4 codec
    m_videoWriter.open(m_recordingPath.toStdString(), fourcc, 30.0, cv::Size(640, 480));

    if (!m_videoWriter.isOpened()) {
        qWarning() << "Failed to open video writer:" << m_recordingPath;
        return;
    }

    m_isRecording = true;
    m_recordedFrames = 0;
    qDebug() << "Started recording to:" << m_recordingPath;
}

void CameraCalibration::stopRecording() {
    if (!m_isRecording) {
        qWarning() << "Not currently recording";
        return;
    }

    m_videoWriter.release();
    m_isRecording = false;

    qDebug() << "Stopped recording. Saved" << m_recordedFrames << "frames to:" << m_recordingPath;
    qDebug() << "Video location:" << m_recordingPath;
}

void CameraCalibration::resetTracking() {
    qDebug() << "Manually resetting ball tracking";
    m_liveTrackingInitialized = false;
    m_kalmanInitialized = false;
    m_trackingConfidence = 0;
    m_missedFrames = 0;
    m_ballZoneState = BallZoneState::NO_BALL;
    m_isArmed = false;
    m_ballPositionHistory.clear();

    // Reset template matching
    m_templateInitialized = false;
    m_ballTemplate.release();
    m_templateConfidence = 0;

    qDebug() << "Tracking reset complete - will re-acquire ball and extract new template";
}

void CameraCalibration::setDebugMode(bool enabled) {
    m_debugMode = enabled;
    qDebug() << "Debug mode" << (enabled ? "ENABLED" : "DISABLED");
    if (enabled) {
        qDebug() << "Debug visualization will show:";
        qDebug() << "  - All detected circles in BLUE";
        qDebug() << "  - Brightness scores for each circle";
        qDebug() << "  - Selected circle in GREEN/RED (larger)";
        qDebug() << "  - Detection parameters and scores";
    }
}

// ============================================================================
// BACKGROUND SUBTRACTION (Eliminate Texture Circles)
// ============================================================================

void CameraCalibration::captureBaseline() {
    if (!m_frameProvider) {
        qWarning() << "No frame provider available";
        return;
    }

    // Get current frame (EMPTY ZONE - no ball!)
    cv::Mat frame = m_frameProvider->getLatestFrame();
    if (frame.empty()) {
        qWarning() << "Failed to capture baseline frame";
        return;
    }

    // Convert to grayscale if needed
    if (frame.channels() == 3) {
        cv::cvtColor(frame, m_baselineFrame, cv::COLOR_BGR2GRAY);
    } else {
        m_baselineFrame = frame.clone();
    }

    // Apply same preprocessing as detection (for consistency)
    cv::GaussianBlur(m_baselineFrame, m_baselineFrame, cv::Size(5, 5), 1.5);

    m_hasBaseline = true;
    qDebug() << "✓ Baseline captured! Background subtraction ENABLED";
    qDebug() << "  Baseline size:" << m_baselineFrame.cols << "x" << m_baselineFrame.rows;
    qDebug() << "  All texture circles will be eliminated";

    emit baselineCaptured();  // Notify QML that baseline is ready
}

QString CameraCalibration::saveBackgroundSubtractionView() {
    if (!m_lastDifferenceFrame.empty()) {
        // Save the last difference frame
        QString screenshotsDir = QDir::homePath() + "/prgr/PRGR_Project/screenshots";
        QDir dir;
        if (!dir.mkpath(screenshotsDir)) {
            qWarning() << "Failed to create screenshots directory";
            return QString();
        }

        QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss");
        QString filepath = screenshotsDir + "/background_subtraction_" + timestamp + ".png";

        if (!cv::imwrite(filepath.toStdString(), m_lastDifferenceFrame)) {
            qWarning() << "Failed to save background subtraction view";
            return QString();
        }

        qDebug() << "Background subtraction view saved:" << filepath;
        return filepath;
    } else {
        qDebug() << "No difference frame available - run detection first with baseline captured";
        return QString();
    }
}

// ============================================================================
// BALL ZONE STATE MACHINE (Professional Launch Monitor Ready System)
// ============================================================================

bool CameraCalibration::isBallStable() const {
    if (m_ballPositionHistory.size() < m_stabilityHistorySize) {
        return false;  // Not enough history yet
    }

    // Calculate max movement in recent history
    double maxMovement = 0.0;
    cv::Point2f firstPos = m_ballPositionHistory.front();

    for (const auto& pos : m_ballPositionHistory) {
        double dx = pos.x - firstPos.x;
        double dy = pos.y - firstPos.y;
        double movement = std::sqrt(dx*dx + dy*dy);
        maxMovement = std::max(maxMovement, movement);
    }

    // Stable if max movement is below threshold
    return maxMovement < m_stabilityThreshold;
}

QString CameraCalibration::getBallZoneStateString() const {
    switch (m_ballZoneState) {
        case BallZoneState::NO_BALL:
            return "NO_BALL";
        case BallZoneState::BALL_OUT_OF_ZONE:
            return "OUT_OF_ZONE";
        case BallZoneState::BALL_IN_ZONE_MOVING:
            return "MOVING";
        case BallZoneState::BALL_IN_ZONE_STABLE:
            return "STABILIZING";
        case BallZoneState::READY:
            return "READY";
        case BallZoneState::IMPACT_DETECTED:
            return "IMPACT";
        case BallZoneState::POST_IMPACT:
            return "PROCESSING";
        default:
            return "UNKNOWN";
    }
}

QString CameraCalibration::getBallZoneStateDisplay() const {
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();

    switch (m_ballZoneState) {
        case BallZoneState::NO_BALL:
            return "Place ball in zone";
        case BallZoneState::BALL_OUT_OF_ZONE:
            return "Ball outside zone";
        case BallZoneState::BALL_IN_ZONE_MOVING:
            return "Ball moving...";
        case BallZoneState::BALL_IN_ZONE_STABLE: {
            qint64 elapsed = currentTime - m_stableStartTime;
            double remaining = (m_readyRequiredMs - elapsed) / 1000.0;
            return QString("Stabilizing... %1s").arg(remaining, 0, 'f', 1);
        }
        case BallZoneState::READY:
            return "READY - Hit when ready";
        case BallZoneState::IMPACT_DETECTED:
            return "IMPACT!";
        case BallZoneState::POST_IMPACT:
            return "Processing...";
        default:
            return "Unknown state";
    }
}

bool CameraCalibration::isSystemReady() const {
    return m_ballZoneState == BallZoneState::READY;
}

bool CameraCalibration::isSystemArmed() const {
    return m_isArmed;
}

void CameraCalibration::updateBallZoneState(bool ballDetected, bool inZone, double ballX, double ballY) {
    qint64 currentTime = QDateTime::currentMSecsSinceEpoch();
    BallZoneState previousState = m_ballZoneState;

    // Update position history for stability tracking
    if (ballDetected && inZone) {
        m_ballPositionHistory.push_back(cv::Point2f(ballX, ballY));
        if (m_ballPositionHistory.size() > m_stabilityHistorySize) {
            m_ballPositionHistory.pop_front();
        }
    } else {
        m_ballPositionHistory.clear();
    }

    // State machine transitions
    switch (m_ballZoneState) {
        case BallZoneState::NO_BALL:
            if (ballDetected && inZone) {
                m_ballZoneState = BallZoneState::BALL_IN_ZONE_MOVING;
                qDebug() << "State: NO_BALL → BALL_IN_ZONE_MOVING";
            } else if (ballDetected && !inZone) {
                m_ballZoneState = BallZoneState::BALL_OUT_OF_ZONE;
                qDebug() << "State: NO_BALL → BALL_OUT_OF_ZONE";
            }
            break;

        case BallZoneState::BALL_OUT_OF_ZONE:
            if (!ballDetected) {
                m_ballZoneState = BallZoneState::NO_BALL;
                qDebug() << "State: BALL_OUT_OF_ZONE → NO_BALL";
            } else if (inZone) {
                m_ballZoneState = BallZoneState::BALL_IN_ZONE_MOVING;
                qDebug() << "State: BALL_OUT_OF_ZONE → BALL_IN_ZONE_MOVING";
            }
            break;

        case BallZoneState::BALL_IN_ZONE_MOVING:
            if (!ballDetected || !inZone) {
                m_ballZoneState = !ballDetected ? BallZoneState::NO_BALL : BallZoneState::BALL_OUT_OF_ZONE;
                qDebug() << "State: BALL_IN_ZONE_MOVING → " << getBallZoneStateString();
            } else if (isBallStable()) {
                m_ballZoneState = BallZoneState::BALL_IN_ZONE_STABLE;
                m_stableStartTime = currentTime;
                qDebug() << "State: BALL_IN_ZONE_MOVING → BALL_IN_ZONE_STABLE (ball stopped moving)";
            }
            break;

        case BallZoneState::BALL_IN_ZONE_STABLE:
            if (!ballDetected || !inZone) {
                m_ballZoneState = !ballDetected ? BallZoneState::NO_BALL : BallZoneState::BALL_OUT_OF_ZONE;
                qDebug() << "State: BALL_IN_ZONE_STABLE → " << getBallZoneStateString();
            } else if (!isBallStable()) {
                m_ballZoneState = BallZoneState::BALL_IN_ZONE_MOVING;
                qDebug() << "State: BALL_IN_ZONE_STABLE → BALL_IN_ZONE_MOVING (ball moved)";
            } else if (currentTime - m_stableStartTime >= m_readyRequiredMs) {
                m_ballZoneState = BallZoneState::READY;
                m_isArmed = true;
                qDebug() << "State: BALL_IN_ZONE_STABLE → READY ✅ (SYSTEM ARMED)";
            }
            break;

        case BallZoneState::READY:
            // Check for impact (ball left zone or disappeared)
            if (!ballDetected || !inZone) {
                m_ballZoneState = BallZoneState::IMPACT_DETECTED;
                m_impactTime = currentTime;
                qDebug() << "State: READY → IMPACT_DETECTED 🏌️ (Shot detected!)";
            }
            // If ball is still there but moving, stay READY (club might be approaching)
            break;

        case BallZoneState::IMPACT_DETECTED:
            // Transition to post-impact processing
            // (This will be handled by high-speed capture system)
            m_ballZoneState = BallZoneState::POST_IMPACT;
            qDebug() << "State: IMPACT_DETECTED → POST_IMPACT";
            break;

        case BallZoneState::POST_IMPACT:
            // Reset to NO_BALL after processing complete
            // (Will be triggered after capture sequence completes)
            break;
    }

    // Log state changes
    if (m_ballZoneState != previousState) {
        qDebug() << "Ball Zone State Changed:" << getBallZoneStateString();
    }
}

QString CameraCalibration::captureScreenshot() {
    // If debug mode is enabled, use the last debug frame (shows all circles)
    if (m_debugMode && !m_lastDebugFrame.empty()) {
        QString screenshotsDir = QDir::homePath() + "/prgr/PRGR_Project/screenshots";
        QDir dir;
        if (!dir.mkpath(screenshotsDir)) {
            qWarning() << "Failed to create screenshots directory:" << screenshotsDir;
            return QString();
        }

        QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss");
        QString filepath = screenshotsDir + "/debug_" + timestamp + ".png";

        if (!cv::imwrite(filepath.toStdString(), m_lastDebugFrame)) {
            qWarning() << "Failed to save debug screenshot to:" << filepath;
            return QString();
        }

        qDebug() << "DEBUG screenshot saved to:" << filepath;
        qDebug() << "Shows: ALL detected circles (blue), brightness values, selected circle (green)";
        return filepath;
    }

    // Normal screenshot mode (no debug visualization)
    if (!m_frameProvider) {
        qWarning() << "No frame provider available";
        return QString();
    }

    // Get latest frame
    cv::Mat frame = m_frameProvider->getLatestFrame();
    if (frame.empty()) {
        qWarning() << "No frame available for screenshot";
        return QString();
    }

    // Create color version if needed
    cv::Mat colorFrame;
    if (frame.channels() == 1) {
        cv::cvtColor(frame, colorFrame, cv::COLOR_GRAY2BGR);
    } else {
        colorFrame = frame.clone();
    }

    // Get current ball detection state
    bool ballDetected = m_liveTrackingInitialized && m_trackingConfidence > 0;
    bool inZone = false;

    if (ballDetected && m_isZoneDefined && m_zoneCorners.size() == 4) {
        std::vector<cv::Point2f> zonePoints;
        int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
        for (const auto &corner : m_zoneCorners) {
            // Frame is ROTATED, ball position is in UNROTATED space
            // Zone corners are in ROTATED space
            // Need to inverse transform zone back to unrotated for comparison
            float unrotatedX = static_cast<float>(frameWidth) - corner.y();
            float unrotatedY = corner.x();
            zonePoints.push_back(cv::Point2f(unrotatedX, unrotatedY));
        }
        double distance = cv::pointPolygonTest(zonePoints,
            cv::Point2f(m_smoothedBallX, m_smoothedBallY), true);
        inZone = (distance >= -m_zoneEdgeTolerance);  // Allow 15px outside zone edge
    }

    // Draw all overlays
    // 1. Draw zone boundary (orange box)
    // NOTE: Frame from getLatestFrame() is ROTATED (250×400)
    // Zone corners are stored in ROTATED space (from QML clicks)
    // So use zone corners directly - NO transformation needed
    if (m_isZoneDefined && m_zoneCorners.size() == 4) {
        std::vector<cv::Point> pts;
        for (const auto &corner : m_zoneCorners) {
            // Zone corners are already in rotated 250×400 space - use directly
            pts.push_back(cv::Point(corner.x(), corner.y()));
        }
        cv::polylines(colorFrame, pts, true, cv::Scalar(0, 165, 255), 2);  // Orange BGR

        // Draw corner labels
        QStringList labels = {"FL", "FR", "BR", "BL"};
        for (int i = 0; i < 4 && i < m_zoneCorners.size(); i++) {
            cv::putText(colorFrame, labels[i].toStdString(),
                       cv::Point(m_zoneCorners[i].x() + 5, m_zoneCorners[i].y() - 5),
                       cv::FONT_HERSHEY_SIMPLEX, 0.5, cv::Scalar(255, 255, 255), 1);
        }
    }

    // 2. Draw ball tracking circle (green or red)
    // Ball position is in UNROTATED space, need to transform to ROTATED space for drawing
    if (ballDetected) {
        // Transform ball position from unrotated (640×400) to rotated (400×640) space
        // Rotation: (x, y) → (y, frameWidth-x)
        int frameWidth = m_croppedWidth > 0 ? m_croppedWidth : 640;
        int ballRotatedX = static_cast<int>(m_smoothedBallY);
        int ballRotatedY = static_cast<int>(frameWidth - m_smoothedBallX);

        cv::Scalar circleColor = inZone ? cv::Scalar(80, 175, 76) : cv::Scalar(0, 0, 255);  // Green or Red BGR
        cv::circle(colorFrame, cv::Point(ballRotatedX, ballRotatedY),
                  m_lastBallRadius + 3, circleColor, 3);
        cv::circle(colorFrame, cv::Point(ballRotatedX, ballRotatedY),
                  2, circleColor, -1);  // Center dot
    }

    // 3. Draw tracking status text
    QString statusText = ballDetected ?
                        (inZone ? "TRACKING - IN ZONE" : "TRACKING - OUT OF ZONE") :
                        "SEARCHING...";
    cv::putText(colorFrame, statusText.toStdString(),
               cv::Point(10, 30), cv::FONT_HERSHEY_SIMPLEX, 0.7,
               cv::Scalar(0, 255, 0), 2);

    // 4. Draw confidence indicator
    if (ballDetected) {
        QString confText = QString("Confidence: %1/10").arg(m_trackingConfidence);
        cv::putText(colorFrame, confText.toStdString(),
                   cv::Point(10, 60), cv::FONT_HERSHEY_SIMPLEX, 0.6,
                   cv::Scalar(255, 255, 255), 1);
    }

    // 5. Draw timestamp
    QString timestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    cv::putText(colorFrame, timestamp.toStdString(),
               cv::Point(10, colorFrame.rows - 10), cv::FONT_HERSHEY_SIMPLEX, 0.5,
               cv::Scalar(255, 255, 255), 1);

    // Create screenshots directory
    QString screenshotsDir = QDir::homePath() + "/prgr/PRGR_Project/screenshots";
    QDir dir;
    if (!dir.mkpath(screenshotsDir)) {
        qWarning() << "Failed to create screenshots directory:" << screenshotsDir;
        return QString();
    }

    // Generate filename with timestamp
    QString filenameTimestamp = QDateTime::currentDateTime().toString("yyyy-MM-dd_HH-mm-ss");
    QString filepath = screenshotsDir + "/tracking_" + filenameTimestamp + ".png";

    // Save screenshot
    if (!cv::imwrite(filepath.toStdString(), colorFrame)) {
        qWarning() << "Failed to save screenshot to:" << filepath;
        return QString();
    }

    qDebug() << "Screenshot saved to:" << filepath;
    return filepath;
}

// ============================================================================
// EDGE DENSITY VERIFICATION (Golf Ball Appearance Check)
// ============================================================================

// NOTE: Template matching (loadVerificationTemplates) has been replaced with
// edge density verification for better performance and accuracy.
// Templates are no longer needed - verification is now based on Laplacian edge detection.

void CameraCalibration::loadVerificationTemplates() {
    // OBSOLETE: Templates no longer used (edge density verification instead)
    // Keeping function stub to avoid breaking existing code
    m_verificationTemplatesLoaded = false;
}

bool CameraCalibration::verifyBallAppearance(const cv::Mat &frame, int x, int y, int radius) {
    // ========== EDGE DENSITY VERIFICATION ==========
    // Golf balls have HIGH edge density (dimples create many edges)
    // Carpet/turf has LOW edge density (smooth gradients)

    // Extract region around circle (radius + 5px margin)
    int margin = 5;
    int roiSize = (radius + margin) * 2;
    int roiX = std::max(0, x - radius - margin);
    int roiY = std::max(0, y - radius - margin);
    int roiWidth = std::min(roiSize, frame.cols - roiX);
    int roiHeight = std::min(roiSize, frame.rows - roiY);

    // Check if ROI is valid
    if (roiWidth < radius * 2 || roiHeight < radius * 2) {
        return true;  // Circle too close to edge - can't verify, accept it
    }

    cv::Rect roi(roiX, roiY, roiWidth, roiHeight);
    cv::Mat circleRegion = frame(roi);

    // Apply Laplacian edge detection (detects high-frequency texture)
    cv::Mat laplacian;
    cv::Laplacian(circleRegion, laplacian, CV_16S, 3);  // 3x3 kernel
    cv::convertScaleAbs(laplacian, laplacian);  // Convert to absolute values

    // Create circular mask (only count edges INSIDE the circle)
    cv::Mat mask = cv::Mat::zeros(circleRegion.size(), CV_8U);
    int centerX = radius + margin;
    int centerY = radius + margin;
    cv::circle(mask, cv::Point(centerX, centerY), radius, cv::Scalar(255), -1);

    // Count strong edges inside circle (edge pixels > threshold)
    int edgeCount = 0;
    int totalPixels = 0;
    const int EDGE_THRESHOLD = 80;  // Pixels with edge strength > 80 are considered edges (only strong dimple edges)

    for (int i = 0; i < laplacian.rows; i++) {
        for (int j = 0; j < laplacian.cols; j++) {
            if (mask.at<uchar>(i, j) > 0) {  // Only count inside circle
                totalPixels++;
                if (laplacian.at<uchar>(i, j) > EDGE_THRESHOLD) {
                    edgeCount++;
                }
            }
        }
    }

    // Calculate edge density (percentage of pixels that are edges)
    double edgeDensity = (totalPixels > 0) ? (100.0 * edgeCount / totalPixels) : 0.0;

    // Golf ball with dimples: 8-20% edge density
    // Carpet/turf: 1-5% edge density
    const double MIN_EDGE_DENSITY = 8.0;  // Require at least 8% edges (strictest threshold)

    bool isGolfBall = (edgeDensity >= MIN_EDGE_DENSITY);

    if (isGolfBall) {
        qDebug() << "  ✅ Golf ball verified! Edge density:" << QString::number(edgeDensity, 'f', 1) << "%"
                 << "(" << edgeCount << "/" << totalPixels << "pixels)";
    } else {
        qDebug() << "  ❌ REJECTED (not a golf ball) - Edge density:" << QString::number(edgeDensity, 'f', 1) << "%"
                 << "< threshold" << MIN_EDGE_DENSITY << "% (carpet/smooth surface)";
    }

    return isGolfBall;
}
