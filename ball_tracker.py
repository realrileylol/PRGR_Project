"""
Advanced Ball Tracker with Template Matching and Kalman Filter
Provides rock-solid ball tracking for golf launch monitor
"""

import cv2
import numpy as np


class BallTracker:
    """
    Hybrid ball tracker combining:
    - Initial detection: HoughCircles
    - Locked tracking: Template Matching + Kalman Filter
    - Fallback: Re-detection if tracking lost
    """

    def __init__(self):
        # Tracking state
        self.is_locked = False
        self.ball_template = None
        self.template_size = 80  # Size of template to extract around ball
        self.search_window = 120  # Search window size for template matching

        # Kalman filter for smooth position tracking
        # State: [x, y, dx, dy] - position and velocity
        self.kalman = cv2.KalmanFilter(4, 2)
        self.kalman.measurementMatrix = np.array([
            [1, 0, 0, 0],
            [0, 1, 0, 0]
        ], np.float32)
        self.kalman.transitionMatrix = np.array([
            [1, 0, 1, 0],
            [0, 1, 0, 1],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        ], np.float32)
        self.kalman.processNoiseCov = np.eye(4, dtype=np.float32) * 0.03

        # Tracking metrics
        self.last_position = None
        self.last_radius = None
        self.tracking_confidence = 0.0
        self.frames_since_good_match = 0

    def lock_ball(self, frame, x, y, radius):
        """
        Lock onto ball and extract template for tracking

        Args:
            frame: Grayscale frame
            x, y: Ball center position
            radius: Ball radius
        """
        self.last_position = (int(x), int(y))
        self.last_radius = int(radius)

        # Extract template around ball
        half_size = self.template_size // 2
        y1 = max(0, int(y) - half_size)
        y2 = min(frame.shape[0], int(y) + half_size)
        x1 = max(0, int(x) - half_size)
        x2 = min(frame.shape[1], int(x) + half_size)

        self.ball_template = frame[y1:y2, x1:x2].copy()

        # Initialize Kalman filter with ball position
        self.kalman.statePre = np.array([x, y, 0, 0], np.float32)
        self.kalman.statePost = np.array([x, y, 0, 0], np.float32)

        self.is_locked = True
        self.tracking_confidence = 1.0
        self.frames_since_good_match = 0

        print(f"🔒 Ball tracker locked at ({x:.0f}, {y:.0f}) r={radius:.0f}px")

    def track(self, frame):
        """
        Track ball in new frame using template matching + Kalman filter

        Args:
            frame: Grayscale frame

        Returns:
            (x, y, radius, confidence) or None if tracking lost
        """
        if not self.is_locked or self.ball_template is None:
            return None

        # Predict next position using Kalman filter
        prediction = self.kalman.predict()
        pred_x, pred_y = int(prediction[0]), int(prediction[1])

        # Define search region around predicted position
        half_search = self.search_window // 2
        search_y1 = max(0, pred_y - half_search)
        search_y2 = min(frame.shape[0], pred_y + half_search)
        search_x1 = max(0, pred_x - half_search)
        search_x2 = min(frame.shape[1], pred_x + half_search)

        search_region = frame[search_y1:search_y2, search_x1:search_x2]

        if search_region.size == 0 or self.ball_template.size == 0:
            return None

        # Template matching
        try:
            result = cv2.matchTemplate(search_region, self.ball_template, cv2.TM_CCOEFF_NORMED)
            _, max_val, _, max_loc = cv2.minMaxLoc(result)

            # Convert to frame coordinates
            template_half = self.template_size // 2
            match_x = search_x1 + max_loc[0] + template_half
            match_y = search_y1 + max_loc[1] + template_half

            # Update Kalman filter with measurement
            measurement = np.array([match_x, match_y], np.float32)
            self.kalman.correct(measurement)

            # Get corrected position from Kalman filter
            corrected = self.kalman.statePost
            final_x = float(corrected[0])
            final_y = float(corrected[1])

            # Update tracking metrics
            self.tracking_confidence = float(max_val)
            self.last_position = (int(final_x), int(final_y))

            # Good match
            if max_val > 0.7:
                self.frames_since_good_match = 0
                return (final_x, final_y, self.last_radius, max_val)
            # Weak match
            elif max_val > 0.5:
                self.frames_since_good_match += 1
                if self.frames_since_good_match < 5:  # Allow brief occlusion
                    return (final_x, final_y, self.last_radius, max_val)

            # Tracking lost
            self.is_locked = False
            return None

        except Exception as e:
            print(f"⚠️ Template matching error: {e}")
            self.is_locked = False
            return None

    def reset(self):
        """Reset tracker to initial state"""
        self.is_locked = False
        self.ball_template = None
        self.last_position = None
        self.last_radius = None
        self.tracking_confidence = 0.0
        self.frames_since_good_match = 0
