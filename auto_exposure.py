"""
Auto Exposure Controller for Golf Launch Monitor
Dynamically adjusts camera exposure settings for optimal ball detection
in varying light conditions (indoor/outdoor)
"""

import numpy as np
import time


class AutoExposureController:
    """
    Automatic exposure adjustment for ball detection

    Monitors ball zone brightness and adjusts camera settings to maintain
    optimal exposure across indoor/outdoor lighting conditions.

    Strategy:
    - Target ball brightness: 160-200 (on 0-255 scale)
    - Adjust gain primarily (avoid motion blur)
    - Keep shutter speed ≤ 1500µs for high-speed ball capture
    - Smooth, gradual adjustments
    """

    def __init__(self, picam2, ball_zone_center=None, ball_zone_radius=None):
        """
        Initialize auto exposure controller

        Args:
            picam2: Picamera2 instance to control
            ball_zone_center: (x, y) tuple for ball zone center
            ball_zone_radius: radius of ball zone in pixels
        """
        self.picam2 = picam2
        self.ball_zone_center = ball_zone_center
        self.ball_zone_radius = ball_zone_radius

        # Target brightness ranges
        self.target_brightness_min = 160  # Minimum desired brightness
        self.target_brightness_max = 200  # Maximum desired brightness
        self.target_brightness_ideal = 180  # Ideal target

        # Exposure limits (to prevent motion blur)
        self.min_shutter = 500     # 0.5ms minimum (super fast)
        self.max_shutter = 1500    # 1.5ms maximum (motion blur limit)
        self.min_gain = 1.0        # Minimum analog gain
        self.max_gain = 16.0       # Maximum analog gain (OV9281 limit)

        # Current settings
        self.current_shutter = 800   # Start at 800µs (ultra-fast)
        self.current_gain = 10.0     # Start at high gain

        # Adjustment parameters
        self.adjustment_speed = 0.3    # How aggressively to adjust (0-1)
        self.min_adjustment_interval = 0.1  # Minimum seconds between adjustments
        self.last_adjustment_time = 0

        # Brightness history for stability
        self.brightness_history = []
        self.history_size = 5  # Average over last N measurements

        # Mode presets
        self.presets = {
            'outdoor_bright': {
                'shutter': 500,   # Very fast shutter
                'gain': 2.0,      # Low gain
                'target': 170     # Slightly lower target (bright conditions)
            },
            'outdoor_normal': {
                'shutter': 700,
                'gain': 4.0,
                'target': 180
            },
            'indoor': {
                'shutter': 1200,   # Slower shutter (still fast)
                'gain': 12.0,      # High gain
                'target': 190      # Slightly higher target
            },
            'indoor_dim': {
                'shutter': 1500,   # Max shutter we allow
                'gain': 16.0,      # Max gain
                'target': 200      # Accept slightly brighter
            }
        }

        # Current mode
        self.current_mode = None
        self.auto_mode_enabled = True

        print(f"AutoExposure: Initialized with target brightness {self.target_brightness_ideal}")

    def set_ball_zone(self, center, radius):
        """Update ball zone location for brightness measurement"""
        self.ball_zone_center = center
        self.ball_zone_radius = radius
        print(f"AutoExposure: Ball zone set to center={center}, radius={radius}")

    def set_preset_mode(self, mode):
        """
        Apply a preset exposure mode

        Args:
            mode: 'outdoor_bright', 'outdoor_normal', 'indoor', 'indoor_dim', or 'auto'
        """
        if mode == 'auto':
            self.auto_mode_enabled = True
            self.current_mode = None
            print("AutoExposure: Auto mode enabled")
            return

        if mode not in self.presets:
            print(f"AutoExposure: Unknown mode '{mode}', ignoring")
            return

        preset = self.presets[mode]
        self.current_shutter = preset['shutter']
        self.current_gain = preset['gain']
        self.target_brightness_ideal = preset['target']
        self.current_mode = mode
        self.auto_mode_enabled = False

        # Apply immediately
        self._apply_settings()
        print(f"AutoExposure: Preset '{mode}' applied - Shutter={self.current_shutter}µs, Gain={self.current_gain}x")

    def measure_brightness(self, frame):
        """
        Measure brightness in ball zone

        Args:
            frame: Grayscale image (numpy array)

        Returns:
            tuple: (mean_brightness, max_brightness, is_valid)
        """
        if self.ball_zone_center is None or self.ball_zone_radius is None:
            # No ball zone defined - measure center region
            h, w = frame.shape[:2]
            center_x, center_y = w // 2, h // 2
            radius = min(w, h) // 4
        else:
            center_x, center_y = self.ball_zone_center
            radius = int(self.ball_zone_radius * 1.5)  # Slightly larger area

        # Ensure region is within frame
        x1 = max(0, int(center_x - radius))
        x2 = min(frame.shape[1], int(center_x + radius))
        y1 = max(0, int(center_y - radius))
        y2 = min(frame.shape[0], int(center_y + radius))

        if x2 <= x1 or y2 <= y1:
            return 0, 0, False

        # Extract region
        if len(frame.shape) == 3:
            # Convert to grayscale if needed
            import cv2
            region = cv2.cvtColor(frame[y1:y2, x1:x2], cv2.COLOR_RGB2GRAY)
        else:
            region = frame[y1:y2, x1:x2]

        if region.size == 0:
            return 0, 0, False

        mean_brightness = float(np.mean(region))
        max_brightness = float(np.max(region))

        # Add to history
        self.brightness_history.append(mean_brightness)
        if len(self.brightness_history) > self.history_size:
            self.brightness_history.pop(0)

        return mean_brightness, max_brightness, True

    def get_smoothed_brightness(self):
        """Get average brightness from recent history"""
        if not self.brightness_history:
            return None
        return np.mean(self.brightness_history)

    def calculate_adjustment(self, current_brightness):
        """
        Calculate exposure adjustment needed

        Args:
            current_brightness: Current measured brightness

        Returns:
            tuple: (new_shutter, new_gain, adjustment_reason)
        """
        # Calculate error
        error = self.target_brightness_ideal - current_brightness
        error_percent = error / self.target_brightness_ideal

        # Dead zone - don't adjust if within acceptable range
        if self.target_brightness_min <= current_brightness <= self.target_brightness_max:
            return self.current_shutter, self.current_gain, "within_target"

        # Determine adjustment
        new_shutter = self.current_shutter
        new_gain = self.current_gain
        reason = ""

        if current_brightness < self.target_brightness_min:
            # Too dark - increase exposure
            # Prefer increasing gain over shutter (to avoid motion blur)
            if self.current_gain < self.max_gain:
                # Increase gain
                gain_increase = abs(error_percent) * self.adjustment_speed * 4.0  # Faster gain adjustment
                new_gain = min(self.max_gain, self.current_gain * (1 + gain_increase))
                reason = "increased_gain"
            elif self.current_shutter < self.max_shutter:
                # Gain maxed out, increase shutter
                shutter_increase = abs(error_percent) * self.adjustment_speed * 200
                new_shutter = min(self.max_shutter, self.current_shutter + shutter_increase)
                reason = "increased_shutter"
            else:
                reason = "at_max_exposure"

        else:
            # Too bright - decrease exposure
            # Prefer decreasing gain first
            if self.current_gain > self.min_gain:
                # Decrease gain
                gain_decrease = abs(error_percent) * self.adjustment_speed * 0.5
                new_gain = max(self.min_gain, self.current_gain * (1 - gain_decrease))
                reason = "decreased_gain"
            elif self.current_shutter > self.min_shutter:
                # Gain already low, decrease shutter
                shutter_decrease = abs(error_percent) * self.adjustment_speed * 100
                new_shutter = max(self.min_shutter, self.current_shutter - shutter_decrease)
                reason = "decreased_shutter"
            else:
                reason = "at_min_exposure"

        return int(new_shutter), round(new_gain, 2), reason

    def _apply_settings(self):
        """Apply current exposure settings to camera"""
        try:
            self.picam2.set_controls({
                "ExposureTime": int(self.current_shutter),
                "AnalogueGain": float(self.current_gain)
            })
            return True
        except Exception as e:
            print(f"AutoExposure: Failed to apply settings: {e}")
            return False

    def update(self, frame, force=False):
        """
        Update exposure based on current frame

        Args:
            frame: Current camera frame (grayscale numpy array)
            force: Force update even if interval hasn't elapsed

        Returns:
            dict: Status information
        """
        # Check if auto mode is enabled
        if not self.auto_mode_enabled and not force:
            return {
                'adjusted': False,
                'reason': 'manual_mode',
                'brightness': 0,
                'shutter': self.current_shutter,
                'gain': self.current_gain
            }

        # Rate limiting
        current_time = time.time()
        if not force and (current_time - self.last_adjustment_time) < self.min_adjustment_interval:
            return {
                'adjusted': False,
                'reason': 'rate_limited',
                'brightness': 0,
                'shutter': self.current_shutter,
                'gain': self.current_gain
            }

        # Measure brightness
        mean_bright, max_bright, valid = self.measure_brightness(frame)
        if not valid:
            return {
                'adjusted': False,
                'reason': 'invalid_measurement',
                'brightness': 0,
                'shutter': self.current_shutter,
                'gain': self.current_gain
            }

        # Use smoothed brightness for stability
        smoothed_brightness = self.get_smoothed_brightness()
        if smoothed_brightness is None:
            smoothed_brightness = mean_bright

        # Calculate adjustment
        new_shutter, new_gain, reason = self.calculate_adjustment(smoothed_brightness)

        # Apply if changed
        adjusted = False
        if new_shutter != self.current_shutter or new_gain != self.current_gain:
            self.current_shutter = new_shutter
            self.current_gain = new_gain

            if self._apply_settings():
                adjusted = True
                self.last_adjustment_time = current_time

        return {
            'adjusted': adjusted,
            'reason': reason,
            'brightness': smoothed_brightness,
            'brightness_raw': mean_bright,
            'brightness_max': max_bright,
            'shutter': self.current_shutter,
            'gain': self.current_gain,
            'target': self.target_brightness_ideal
        }

    def get_status(self):
        """Get current exposure status"""
        return {
            'mode': self.current_mode if self.current_mode else 'auto',
            'auto_enabled': self.auto_mode_enabled,
            'shutter': self.current_shutter,
            'gain': self.current_gain,
            'target_brightness': self.target_brightness_ideal,
            'brightness_history': self.brightness_history.copy() if self.brightness_history else []
        }

    def reset(self):
        """Reset to default settings"""
        self.brightness_history.clear()
        self.current_shutter = 800
        self.current_gain = 10.0
        self.auto_mode_enabled = True
        self.current_mode = None
        print("AutoExposure: Reset to defaults")
