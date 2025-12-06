#include "BallTracker.h"
#include "CameraManager.h"
#include "CameraCalibration.h"
#include "KLD2Manager.h"
#include <QDebug>

BallTracker::BallTracker(CameraManager *cameraManager,
                         CameraCalibration *calibration,
                         QObject *parent)
    : QObject(parent)
    , m_cameraManager(cameraManager)
    , m_calibration(calibration)
    , m_radar(nullptr)
    , m_state(TrackingState::IDLE)
    , m_status("Ready to track")
    , m_framesSinceArmed(0)
    , m_frameNumber(0)
{
    // Default configuration (tuned for golf ball tracking)
    m_motionThreshold = 15.0;           // Pixel intensity difference
    m_minTrackingFrames = 10;           // Minimum frames for trajectory
    m_maxTrackingFrames = 60;           // ~320ms at 187fps
    m_searchExpansionRate = 1.25;       // 25% growth per frame
    m_minBallArea = 50;                 // ~8px radius minimum
    m_maxBallArea = 2000;               // ~25px radius maximum
    m_maxFrameToFrameDistance = 100.0;  // Max 100 pixels between frames

    // Create processing timer (run at camera frame rate)
    m_processTimer = new QTimer(this);
    m_processTimer->setInterval(5);  // ~200 Hz polling
    connect(m_processTimer, &QTimer::timeout, this, &BallTracker::processFrame);

    qDebug() << "BallTracker initialized";
}

BallTracker::~BallTracker() {
    disarmTracking();
}

// ============================================================================
// PUBLIC CONTROL FUNCTIONS
// ============================================================================

void BallTracker::armTracking() {
    if (!m_calibration->isBallZoneCalibrated() || !m_calibration->isZoneDefined()) {
        setStatus("Cannot arm: calibration incomplete");
        emit trackingFailed("Calibration not complete");
        return;
    }

    // Cache calibration data
    m_ballZoneCenter = cv::Point2f(m_calibration->ballCenterX(),
                                   m_calibration->ballCenterY());
    m_ballZoneRadius = m_calibration->ballRadius();

    QList<QPointF> corners = m_calibration->zoneCorners();
    m_zoneCorners.clear();
    for (const auto &corner : corners) {
        m_zoneCorners.push_back(cv::Point2f(corner.x(), corner.y()));
    }

    // Reset state
    m_frameBuffer.clear();
    m_timestampBuffer.clear();
    m_trackedPositions.clear();
    m_framesSinceArmed = 0;
    m_frameNumber = 0;
    m_referenceFrame = cv::Mat();
    m_backgroundModel = cv::Mat();

    setState(TrackingState::ARMED);
    setStatus("Armed - monitoring for ball");

    // Start processing
    m_processTimer->start();

    qDebug() << "Tracking armed - ball zone center:" << m_ballZoneCenter.x << "," << m_ballZoneCenter.y
             << "radius:" << m_ballZoneRadius;
}

void BallTracker::disarmTracking() {
    m_processTimer->stop();

    if (m_state == TrackingState::TRACKING || m_state == TrackingState::TRIGGERED) {
        setStatus("Tracking aborted");
    } else {
        setStatus("Tracking disarmed");
    }

    setState(TrackingState::IDLE);
}

void BallTracker::resetTracking() {
    disarmTracking();
    m_trackedPositions.clear();
    m_frameBuffer.clear();
    m_timestampBuffer.clear();
    emit capturedFramesChanged();
}

// ============================================================================
// CONFIGURATION
// ============================================================================

void BallTracker::setMotionThreshold(double threshold) {
    m_motionThreshold = threshold;
}

void BallTracker::setMinTrackingFrames(int frames) {
    m_minTrackingFrames = frames;
}

void BallTracker::setMaxTrackingFrames(int frames) {
    m_maxTrackingFrames = frames;
}

void BallTracker::setSearchExpansionRate(double rate) {
    m_searchExpansionRate = rate;
}

// ============================================================================
// MAIN PROCESSING LOOP
// ============================================================================

void BallTracker::processFrame() {
    // Get latest frame from camera
    cv::Mat frame = m_cameraManager->getLatestFrame();
    if (frame.empty()) {
        return;
    }

    auto timestamp = std::chrono::high_resolution_clock::now();
    m_frameNumber++;

    // Preprocess frame (convert to grayscale, denoise)
    cv::Mat processed = preprocessFrame(frame);

    // State machine
    switch (m_state) {
        case TrackingState::IDLE:
            // Do nothing
            break;

        case TrackingState::ARMED: {
            // Add to circular buffer
            m_frameBuffer.push_back(processed.clone());
            m_timestampBuffer.push_back(timestamp);

            if (m_frameBuffer.size() > BUFFER_SIZE) {
                m_frameBuffer.pop_front();
                m_timestampBuffer.pop_front();
            }

            m_framesSinceArmed++;

            // Detect stationary ball and establish reference frame
            if (m_framesSinceArmed < 10) {
                // Let camera stabilize
                updateBackgroundModel(processed);
            } else if (m_framesSinceArmed == 10) {
                // Capture reference frame with ball at rest
                detectStationaryBall(processed);
                m_referenceFrame = processed.clone();
                qDebug() << "Reference frame captured";
            } else {
                // Monitor for motion (camera-based)
                bool cameraMotionDetected = detectMotion(processed, m_referenceFrame);

                // If radar available, use it for confirmation (much more reliable)
                bool radarConfirmed = false;
                if (m_radar && m_radar->isConnected()) {
                    double speed = m_radar->getSpeed();
                    radarConfirmed = (speed > 5.0);  // Ball moving > 5 mph = real hit

                    if (radarConfirmed) {
                        qDebug() << "Radar confirmed ball speed:" << speed << "mph";
                    }
                }

                // Trigger if: (camera motion + radar confirms) OR (camera motion + no radar available)
                bool shouldTrigger = cameraMotionDetected && (radarConfirmed || m_radar == nullptr || !m_radar->isConnected());

                if (shouldTrigger) {
                    // Motion detected - ball hit!
                    m_hitTime = timestamp;
                    m_lastBallPos = m_stationaryBallPos;

                    setState(TrackingState::TRIGGERED);
                    setStatus("Hit detected - tracking");
                    emit hitDetected(m_stationaryBallPos);

                    qDebug() << "Ball hit confirmed at frame" << m_frameNumber
                             << (m_radar ? "(radar + camera)" : "(camera only)");

                    // Add pre-trigger frames from buffer
                    int preTriggerFrames = std::min(5, (int)m_frameBuffer.size());
                    for (int i = m_frameBuffer.size() - preTriggerFrames; i < m_frameBuffer.size(); i++) {
                        BallPosition pos;
                        pos.pixelPos = m_stationaryBallPos;
                        pos.timestamp = m_timestampBuffer[i];
                        pos.frameNumber = m_frameNumber - (m_frameBuffer.size() - i);
                        pos.confidence = 1.0;
                        m_trackedPositions.push_back(pos);
                    }
                }
            }
            break;
        }

        case TrackingState::TRIGGERED:
        case TrackingState::TRACKING: {
            // Calculate adaptive search region
            int framesSinceHit = m_trackedPositions.size();
            cv::Rect searchRegion = getSearchRegion(m_lastBallPos, framesSinceHit);

            // Detect ball in search region
            cv::Point2f ballPos;
            if (detectBall(processed, searchRegion, ballPos)) {
                // Validate position (physics check)
                cv::Point2f predicted = predictNextPosition(m_trackedPositions);

                if (validatePosition(ballPos, predicted)) {
                    // Valid ball detection
                    BallPosition pos;
                    pos.pixelPos = ballPos;
                    pos.timestamp = timestamp;
                    pos.frameNumber = m_frameNumber;
                    pos.confidence = calculateConfidence(processed, ballPos);
                    pos.frame = frame.clone();  // Store frame for later analysis

                    m_trackedPositions.push_back(pos);
                    m_lastBallPos = ballPos;

                    setState(TrackingState::TRACKING);
                    emit capturedFramesChanged();

                    // Check if we have enough frames
                    if (m_trackedPositions.size() >= m_maxTrackingFrames) {
                        qDebug() << "Max tracking frames reached:" << m_trackedPositions.size();
                        setState(TrackingState::ANALYZING);
                        m_processTimer->stop();
                        analyzeTrajectory();
                    }
                } else {
                    qDebug() << "Ball position validation failed (too far from predicted)";
                    // Lost ball - finish tracking if we have minimum frames
                    if (m_trackedPositions.size() >= m_minTrackingFrames) {
                        qDebug() << "Ball lost, finishing tracking with" << m_trackedPositions.size() << "frames";
                        setState(TrackingState::ANALYZING);
                        m_processTimer->stop();
                        analyzeTrajectory();
                    } else {
                        setStatus("Tracking failed - insufficient frames");
                        emit trackingFailed("Ball lost before minimum frames captured");
                        disarmTracking();
                    }
                }
            } else {
                // Ball not detected in search region
                if (framesSinceHit > 5) {  // Allow a few missed frames initially
                    if (m_trackedPositions.size() >= m_minTrackingFrames) {
                        qDebug() << "Ball left frame, finishing tracking with" << m_trackedPositions.size() << "frames";
                        setState(TrackingState::ANALYZING);
                        m_processTimer->stop();
                        analyzeTrajectory();
                    } else {
                        setStatus("Tracking failed - ball lost too early");
                        emit trackingFailed("Ball lost before minimum frames captured");
                        disarmTracking();
                    }
                }
            }
            break;
        }

        case TrackingState::ANALYZING:
        case TrackingState::COMPLETE:
            // Analysis done, waiting for reset
            break;
    }
}

// ============================================================================
// BALL DETECTION FUNCTIONS
// ============================================================================

void BallTracker::detectStationaryBall(const cv::Mat &frame) {
    // Create mask for ball zone
    cv::Mat mask = cv::Mat::zeros(frame.size(), CV_8UC1);
    cv::circle(mask, m_ballZoneCenter, m_ballZoneRadius * 1.5, cv::Scalar(255), -1);

    // Apply mask
    cv::Mat masked;
    frame.copyTo(masked, mask);

    // Threshold to find bright ball
    cv::Mat thresh;
    cv::threshold(masked, thresh, 0, 255, cv::THRESH_BINARY + cv::THRESH_OTSU);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Find circular blob closest to zone center
    double minDist = std::numeric_limits<double>::max();
    cv::Point2f bestPos = m_ballZoneCenter;

    for (const auto &contour : contours) {
        double area = cv::contourArea(contour);
        if (area < m_minBallArea || area > m_maxBallArea) {
            continue;
        }

        // Calculate centroid
        cv::Moments moments = cv::moments(contour);
        if (moments.m00 == 0) continue;

        cv::Point2f center(moments.m10 / moments.m00, moments.m01 / moments.m00);

        // Check circularity
        double perimeter = cv::arcLength(contour, true);
        double circularity = 4 * M_PI * area / (perimeter * perimeter);

        if (circularity > 0.6) {  // Reasonably circular
            double dist = cv::norm(center - m_ballZoneCenter);
            if (dist < minDist) {
                minDist = dist;
                bestPos = center;
            }
        }
    }

    m_stationaryBallPos = bestPos;
    emit ballAtRest(bestPos);

    qDebug() << "Stationary ball detected at:" << bestPos.x << "," << bestPos.y;
}

bool BallTracker::detectMotion(const cv::Mat &currentFrame, const cv::Mat &referenceFrame) {
    if (referenceFrame.empty()) {
        return false;
    }

    // Create tight mask for ball zone only (1.5x radius to avoid club)
    cv::Mat mask = cv::Mat::zeros(currentFrame.size(), CV_8UC1);
    cv::circle(mask, m_ballZoneCenter, m_ballZoneRadius * 1.5, cv::Scalar(255), -1);

    // Frame difference
    cv::Mat diff;
    cv::absdiff(currentFrame, referenceFrame, diff);

    // Apply mask to only check ball zone
    diff.setTo(0, ~mask);

    // Threshold the difference to find changed regions
    cv::Mat thresh;
    cv::threshold(diff, thresh, m_motionThreshold, 255, cv::THRESH_BINARY);

    // Find connected components (blobs) in the difference
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Filter blobs - look for small, ball-sized motion, not large club motion
    for (const auto &contour : contours) {
        double area = cv::contourArea(contour);

        // Club creates large blobs (1000+ pixels), ball creates small motion (50-400 pixels)
        if (area < m_minBallArea * 0.5 || area > m_maxBallArea * 1.5) {
            continue;  // Too small (noise) or too large (club)
        }

        // Check if blob is roughly circular (ball), not elongated (club shaft)
        double perimeter = cv::arcLength(contour, true);
        double circularity = 4 * M_PI * area / (perimeter * perimeter);

        if (circularity > 0.4) {  // Reasonably circular = ball motion
            // Check if motion is near ball center
            cv::Moments moments = cv::moments(contour);
            if (moments.m00 > 0) {
                cv::Point2f motionCenter(moments.m10 / moments.m00, moments.m01 / moments.m00);
                double distFromBall = cv::norm(motionCenter - m_ballZoneCenter);

                // Motion must be within ball zone
                if (distFromBall < m_ballZoneRadius * 1.2) {
                    qDebug() << "Ball motion detected: area=" << area << "circularity=" << circularity
                             << "distFromBall=" << distFromBall;
                    return true;  // Valid ball motion detected
                }
            }
        }
    }

    // No valid ball motion found (likely club or noise)
    return false;
}

bool BallTracker::detectBall(const cv::Mat &frame, const cv::Rect &searchRegion, cv::Point2f &ballPos) {
    // Ensure search region is within frame bounds
    cv::Rect safeBounds = searchRegion & cv::Rect(0, 0, frame.cols, frame.rows);
    if (safeBounds.width < 10 || safeBounds.height < 10) {
        return false;
    }

    cv::Mat roi = frame(safeBounds);

    // Threshold to find bright regions
    cv::Mat thresh;
    cv::threshold(roi, thresh, 0, 255, cv::THRESH_BINARY + cv::THRESH_OTSU);

    // Morphological operations to clean up
    cv::Mat kernel = cv::getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(3, 3));
    cv::morphologyEx(thresh, thresh, cv::MORPH_OPEN, kernel);
    cv::morphologyEx(thresh, thresh, cv::MORPH_CLOSE, kernel);

    // Find contours
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Find best circular blob
    double bestScore = 0.0;
    cv::Point2f bestCenter;
    bool found = false;

    for (const auto &contour : contours) {
        double area = cv::contourArea(contour);
        if (area < m_minBallArea || area > m_maxBallArea) {
            continue;
        }

        // Calculate centroid
        cv::Moments moments = cv::moments(contour);
        if (moments.m00 == 0) continue;

        cv::Point2f center(moments.m10 / moments.m00, moments.m01 / moments.m00);

        // Check circularity
        double perimeter = cv::arcLength(contour, true);
        double circularity = 4 * M_PI * area / (perimeter * perimeter);

        // Score based on circularity and size match
        double expectedArea = M_PI * m_ballZoneRadius * m_ballZoneRadius;
        double sizeScore = 1.0 - std::abs(area - expectedArea) / expectedArea;
        double score = circularity * 0.7 + sizeScore * 0.3;

        if (score > bestScore && circularity > 0.5) {
            bestScore = score;
            bestCenter = center + cv::Point2f(safeBounds.x, safeBounds.y);
            found = true;
        }
    }

    if (found) {
        ballPos = bestCenter;
    }

    return found;
}

cv::Rect BallTracker::getSearchRegion(const cv::Point2f &lastPos, int framesSinceHit) {
    // Start with ball zone size
    double searchRadius = m_ballZoneRadius;

    // Expand search region based on frames since hit
    double expansionFactor = std::pow(m_searchExpansionRate, framesSinceHit);
    searchRadius *= expansionFactor;

    // Clamp to reasonable bounds
    searchRadius = std::min(searchRadius, 300.0);

    // Create search rectangle centered on last position
    cv::Point2f topLeft(lastPos.x - searchRadius, lastPos.y - searchRadius);
    cv::Point2f bottomRight(lastPos.x + searchRadius, lastPos.y + searchRadius);

    return cv::Rect(topLeft, bottomRight);
}

double BallTracker::calculateConfidence(const cv::Mat &frame, const cv::Point2f &pos) {
    // Simple confidence based on contrast around detected position
    // This is a placeholder - could be more sophisticated
    return 0.8;
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

cv::Mat BallTracker::preprocessFrame(const cv::Mat &frame) {
    cv::Mat gray;

    // Convert to grayscale if needed
    if (frame.channels() == 3) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = frame.clone();
    }

    // Denoise slightly (preserve edges)
    cv::Mat denoised;
    cv::GaussianBlur(gray, denoised, cv::Size(3, 3), 0.5);

    return denoised;
}

void BallTracker::updateBackgroundModel(const cv::Mat &frame) {
    if (m_backgroundModel.empty()) {
        m_backgroundModel = frame.clone();
        m_backgroundModel.convertTo(m_backgroundModel, CV_32F);
    } else {
        // Running average
        cv::accumulateWeighted(frame, m_backgroundModel, 0.1);
    }
}

cv::Point2f BallTracker::predictNextPosition(const std::vector<BallPosition> &positions) {
    if (positions.empty()) {
        return m_ballZoneCenter;
    }

    if (positions.size() == 1) {
        return positions[0].pixelPos;
    }

    // Simple linear extrapolation from last 2-3 positions
    int n = std::min(3, (int)positions.size());
    cv::Point2f velocity(0, 0);

    for (int i = positions.size() - 1; i >= positions.size() - n + 1; i--) {
        velocity += positions[i].pixelPos - positions[i-1].pixelPos;
    }
    velocity /= (float)(n - 1);

    return positions.back().pixelPos + velocity;
}

bool BallTracker::validatePosition(const cv::Point2f &pos, const cv::Point2f &predicted) {
    // Check if position is within reasonable distance of prediction
    double distance = cv::norm(pos - predicted);
    return distance < m_maxFrameToFrameDistance;
}

void BallTracker::setState(TrackingState newState) {
    if (m_state != newState) {
        m_state = newState;
        emit trackingStateChanged();
    }
}

void BallTracker::setStatus(const QString &status) {
    if (m_status != status) {
        m_status = status;
        emit statusChanged();
    }
}

// ============================================================================
// TRAJECTORY ANALYSIS
// ============================================================================

void BallTracker::analyzeTrajectory() {
    if (m_trackedPositions.size() < m_minTrackingFrames) {
        setStatus("Analysis failed - insufficient frames");
        emit trackingFailed("Not enough frames for trajectory analysis");
        return;
    }

    qDebug() << "Analyzing trajectory with" << m_trackedPositions.size() << "frames";

    // Convert pixel positions to 3D world coordinates
    for (auto &pos : m_trackedPositions) {
        pos.worldPos = pixelToWorld(pos.pixelPos);
    }

    setStatus(QString("Tracking complete - %1 frames captured").arg(m_trackedPositions.size()));
    setState(TrackingState::COMPLETE);

    emit trackingComplete(m_trackedPositions.size());
    emit trajectoryReady(m_trackedPositions);

    qDebug() << "Trajectory analysis complete";
}

cv::Point3f BallTracker::pixelToWorld(const cv::Point2f &pixel) {
    // Use calibration to convert pixel coordinates to 3D world coordinates
    // Assumes ball is on ground plane initially (Z=0)
    cv::Point3f worldPoint = m_calibration->pixelToWorld(pixel, 0.0);
    return worldPoint;
}
