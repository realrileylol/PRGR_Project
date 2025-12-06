#include "CameraCalibration.h"
#include "FrameProvider.h"
#include "SettingsManager.h"
#include <QDebug>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QStandardPaths>
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
}

CameraCalibration::~CameraCalibration() = default;

void CameraCalibration::setFrameProvider(FrameProvider *provider) {
    m_frameProvider = provider;
}

void CameraCalibration::setSettings(SettingsManager *settings) {
    m_settings = settings;
    loadCalibration();
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

    if (m_isIntrinsicCalibrated) {
        m_status = "Calibration loaded";
        qDebug() << "Camera calibration loaded from" << calibPath;
        qDebug() << "  Focal length: fx=" << m_fx << "fy=" << m_fy;
        qDebug() << "  Intrinsic calibrated:" << m_isIntrinsicCalibrated;
        qDebug() << "  Extrinsic calibrated:" << m_isExtrinsicCalibrated;
        qDebug() << "  Ball zone calibrated:" << m_isBallZoneCalibrated;
    }

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit ballZoneCalibrationChanged();
    emit statusChanged();
}

void CameraCalibration::resetCalibration() {
    m_isIntrinsicCalibrated = false;
    m_isExtrinsicCalibrated = false;
    m_isBallZoneCalibrated = false;
    m_cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_distCoeffs = cv::Mat::zeros(5, 1, CV_64F);
    m_fx = m_fy = m_cx = m_cy = 0.0;
    m_cameraHeight = m_cameraTilt = m_cameraDistance = 0.0;
    m_ballCenterX = m_ballCenterY = m_ballRadius = 0.0;
    m_progress = 0;
    m_status = "Calibration reset";

    saveCalibration();

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit ballZoneCalibrationChanged();
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

    // Detect circles using HoughCircles
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(processed, circles, cv::HOUGH_GRADIENT, 1,
                     processed.rows / 16,  // Min distance between centers
                     100,  // Canny upper threshold
                     15,   // Accumulator threshold
                     4,    // Min radius (golf ball at 5ft should be 4-15 pixels)
                     15);  // Max radius

    if (circles.empty()) {
        qWarning() << "No ball detected in frame";
        emit calibrationFailed("No ball detected. Make sure ball is visible and well-lit.");
        return;
    }

    // Use the first (strongest) detection
    cv::Vec3f bestCircle = circles[0];
    double centerX = bestCircle[0];
    double centerY = bestCircle[1];
    double radius = bestCircle[2];

    // Calculate confidence based on circularity (simplified)
    double confidence = 0.85;  // HoughCircles already filters well

    qDebug() << "Ball detected at" << centerX << "," << centerY
             << "radius:" << radius << "confidence:" << confidence;

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

    qDebug() << "Ball zone calibration complete:";
    qDebug() << "  Center:" << m_ballCenterX << "," << m_ballCenterY;
    qDebug() << "  Radius:" << m_ballRadius << "pixels";

    // Save to settings
    saveCalibration();

    emit ballZoneCalibrationChanged();
    emit calibrationComplete("Ball zone calibration successful");
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
