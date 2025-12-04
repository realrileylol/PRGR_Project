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

    // Find checkerboard corners
    bool found = cv::findChessboardCorners(image, boardSize, corners,
                                           cv::CALIB_CB_ADAPTIVE_THRESH |
                                           cv::CALIB_CB_NORMALIZE_IMAGE |
                                           cv::CALIB_CB_FAST_CHECK);

    if (found) {
        // Refine corner positions to sub-pixel accuracy
        cv::cornerSubPix(image, corners, cv::Size(11, 11), cv::Size(-1, -1),
                        cv::TermCriteria(cv::TermCriteria::EPS + cv::TermCriteria::COUNT, 30, 0.1));
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
    qDebug() << "  Distortion:" << m_distCoeffs;
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

    // Convert QList to std::vector
    std::vector<cv::Point2f> srcPoints, dstPoints;
    for (int i = 0; i < imagePoints.size(); i++) {
        srcPoints.push_back(cv::Point2f(imagePoints[i].x(), imagePoints[i].y()));
        dstPoints.push_back(cv::Point2f(worldPoints[i].x(), worldPoints[i].y()));
    }

    // Compute homography from image plane to ground plane
    m_homography = cv::findHomography(srcPoints, dstPoints, cv::RANSAC);

    if (m_homography.empty()) {
        m_status = "Failed to compute homography";
        emit calibrationFailed(m_status);
        emit statusChanged();
        return;
    }

    calculateCameraPose();

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

    if (!rotations.empty()) {
        m_rotationMatrix = rotations[0];
        m_translationVector = translations[0];

        // Extract camera height (Z component of translation)
        m_cameraHeight = std::abs(m_translationVector.at<double>(2, 0));

        // Calculate tilt angle from rotation matrix
        double tiltRad = std::atan2(m_rotationMatrix.at<double>(2, 0),
                                    m_rotationMatrix.at<double>(2, 2));
        m_cameraTilt = tiltRad * 180.0 / M_PI;

        // Calculate distance to origin (ball position)
        m_cameraDistance = std::sqrt(
            m_translationVector.at<double>(0, 0) * m_translationVector.at<double>(0, 0) +
            m_translationVector.at<double>(1, 0) * m_translationVector.at<double>(1, 0)
        );
    }
}

void CameraCalibration::finishExtrinsicCalibration() {
    // Already handled in setGroundPlanePoints
    saveCalibration();
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

    QString calibPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/calibration.json";
    QDir().mkpath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation));

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

    // Save to file
    QFile file(calibPath);
    if (file.open(QIODevice::WriteOnly)) {
        QJsonDocument doc(json);
        file.write(doc.toJson());
        file.close();
        qDebug() << "Calibration saved to" << calibPath;
    } else {
        qWarning() << "Failed to save calibration to" << calibPath;
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
    for (int i = 0; i < std::min(5, distortion.size()); i++) {
        m_distCoeffs.at<double>(i, 0) = distortion[i].toDouble();
    }

    // Load extrinsic parameters
    m_isExtrinsicCalibrated = json["extrinsic_calibrated"].toBool();
    m_cameraHeight = json["camera_height"].toDouble();
    m_cameraTilt = json["camera_tilt"].toDouble();
    m_cameraDistance = json["camera_distance"].toDouble();

    if (m_isIntrinsicCalibrated) {
        m_status = "Calibration loaded";
        qDebug() << "Camera calibration loaded from" << calibPath;
        qDebug() << "  Focal length: fx=" << m_fx << "fy=" << m_fy;
        qDebug() << "  Intrinsic calibrated:" << m_isIntrinsicCalibrated;
        qDebug() << "  Extrinsic calibrated:" << m_isExtrinsicCalibrated;
    }

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit statusChanged();
}

void CameraCalibration::resetCalibration() {
    m_isIntrinsicCalibrated = false;
    m_isExtrinsicCalibrated = false;
    m_cameraMatrix = cv::Mat::eye(3, 3, CV_64F);
    m_distCoeffs = cv::Mat::zeros(5, 1, CV_64F);
    m_fx = m_fy = m_cx = m_cy = 0.0;
    m_cameraHeight = m_cameraTilt = m_cameraDistance = 0.0;
    m_progress = 0;
    m_status = "Calibration reset";

    saveCalibration();

    emit intrinsicCalibrationChanged();
    emit extrinsicCalibrationChanged();
    emit statusChanged();
    emit progressChanged();
}

QString CameraCalibration::formatCalibrationSummary() const {
    QString summary;
    summary += QString("Focal Length: fx=%.1f fy=%.1f pixels\n").arg(m_fx).arg(m_fy);
    summary += QString("Principal Point: (%.1f, %.1f)\n").arg(m_cx).arg(m_cy);
    summary += QString("Distortion: k1=%.4f k2=%.4f k3=%.4f\n")
                   .arg(m_distCoeffs.at<double>(0, 0))
                   .arg(m_distCoeffs.at<double>(1, 0))
                   .arg(m_distCoeffs.at<double>(4, 0));

    if (m_isExtrinsicCalibrated) {
        summary += QString("\nCamera Height: %.2f m\n").arg(m_cameraHeight);
        summary += QString("Camera Tilt: %.1f°\n").arg(m_cameraTilt);
        summary += QString("Camera Distance: %.2f m\n").arg(m_cameraDistance);
    }

    return summary;
}
