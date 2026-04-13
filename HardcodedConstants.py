"""
PRGR Launch Monitor - Hardcoded Constants
==========================================

These values are FIXED and should NEVER be changed by user calibration.
They define the physical world, hardware specs, and golf rules.

IMPORTANT: If you need to change these, you are rebuilding the system from scratch.
           User-adjustable calibration goes in SettingsManager or CalibrationManager.
"""

import math

# ============================================================================
# GOLF BALL SPECIFICATIONS (Rules of Golf - USGA/R&A)
# ============================================================================

GOLF_BALL_DIAMETER_MM = 42.67      # 1.68 inches - official minimum diameter
GOLF_BALL_DIAMETER_INCHES = 1.68
GOLF_BALL_RADIUS_MM = GOLF_BALL_DIAMETER_MM / 2.0
GOLF_BALL_WEIGHT_GRAMS = 45.93     # Maximum weight per rules


# ============================================================================
# CAMERA HARDWARE SPECIFICATIONS (OV9281 Sensor)
# ============================================================================

# OV9281 Sensor Physical Specs
OV9281_SENSOR_WIDTH_PX = 1280      # Sensor resolution - pixels
OV9281_SENSOR_HEIGHT_PX = 800
OV9281_PIXEL_SIZE_UM = 3.0         # Pixel pitch - microns (µm)
OV9281_SENSOR_WIDTH_MM = OV9281_SENSOR_WIDTH_PX * OV9281_PIXEL_SIZE_UM / 1000.0
OV9281_SENSOR_HEIGHT_MM = OV9281_SENSOR_HEIGHT_PX * OV9281_PIXEL_SIZE_UM / 1000.0
OV9281_SENSOR_DIAGONAL_MM = math.sqrt(OV9281_SENSOR_WIDTH_MM**2 + OV9281_SENSOR_HEIGHT_MM**2)

# Spin Camera (CSI OV9281 with 12mm lens)
SPIN_CAM_FOCAL_LENGTH_MM = 12.0    # Telephoto for close-up spin detection
SPIN_CAM_MAX_FPS = 180             # Hardware limit at 640×480

# Trajectory Camera (USB OV9281 with 2.8mm lens)
TRAJ_CAM_FOCAL_LENGTH_MM = 2.8     # Wide angle for trajectory tracking
TRAJ_CAM_MAX_FPS = 240             # Hardware limit at 640×400


# ============================================================================
# 3D WORLD COORDINATE SYSTEM
# ============================================================================

# CRITICAL: Define the origin and axes of the 3D world
# Origin: Ball position at address (tee position)
# X-axis: Perpendicular to target line (positive = right when facing target)
# Y-axis: Vertical (positive = up)
# Z-axis: Along target line (positive = toward target)

WORLD_ORIGIN = "BALL_AT_ADDRESS"   # Documentation - where (0,0,0) is located


# ============================================================================
# HITBOX DEFINITION (3D Detection Zone)
# ============================================================================

# The hitbox is the 3D region where the trajectory camera MUST detect the ball
# Measured from the BALL POSITION AT ADDRESS (origin)

# ANSWER REQUIRED: User needs to confirm these measurements
# Current assumption: measured from ball position at address

HITBOX_NEAR_FT = 7.0               # Front face of hitbox (feet from ball)
HITBOX_FAR_FT = 8.0                # Back face of hitbox (feet from ball)
HITBOX_WIDTH_FT = 1.0              # Total width (X-axis)
HITBOX_HEIGHT_FT = 1.0             # Total height (Y-axis)

# Convert to millimeters (internal unit for calculations)
FT_TO_MM = 304.8                   # 1 foot = 304.8 mm
MM_TO_FT = 1.0 / FT_TO_MM

HITBOX_NEAR_MM = HITBOX_NEAR_FT * FT_TO_MM          # 2133.6 mm
HITBOX_FAR_MM = HITBOX_FAR_FT * FT_TO_MM            # 2438.4 mm
HITBOX_WIDTH_MM = HITBOX_WIDTH_FT * FT_TO_MM        # 304.8 mm
HITBOX_HEIGHT_MM = HITBOX_HEIGHT_FT * FT_TO_MM      # 304.8 mm

# Hitbox boundaries in 3D world coordinates (mm)
# Assumes hitbox is centered on target line (X=0) and starts from ground (Y=0)
HITBOX_X_MIN = -HITBOX_WIDTH_MM / 2.0               # -152.4 mm (left)
HITBOX_X_MAX = +HITBOX_WIDTH_MM / 2.0               # +152.4 mm (right)
HITBOX_Y_MIN = 0.0                                  # Ground level
HITBOX_Y_MAX = HITBOX_HEIGHT_MM                     # 304.8 mm (1ft high)
HITBOX_Z_MIN = HITBOX_NEAR_MM                       # 2133.6 mm (7ft)
HITBOX_Z_MAX = HITBOX_FAR_MM                        # 2438.4 mm (8ft)


# ============================================================================
# DETECTION ZONE PARAMETERS
# ============================================================================

# Ball must be detected within hitbox to trigger shot measurement
# These define the valid 3D space for ball tracking

def is_ball_in_hitbox(x_mm, y_mm, z_mm):
    """
    Check if a 3D point (ball center) is inside the hitbox.

    Args:
        x_mm: X coordinate in world space (mm)
        y_mm: Y coordinate in world space (mm)
        z_mm: Z coordinate in world space (mm)

    Returns:
        bool: True if point is inside hitbox, False otherwise
    """
    return (HITBOX_X_MIN <= x_mm <= HITBOX_X_MAX and
            HITBOX_Y_MIN <= y_mm <= HITBOX_Y_MAX and
            HITBOX_Z_MIN <= z_mm <= HITBOX_Z_MAX)


# ============================================================================
# CAMERA POSITION CONSTRAINTS (Physical Limits)
# ============================================================================

# These are NOT the calibrated positions - those go in CalibrationManager
# These are the VALID RANGES for physical setup

# Spin Camera Position Constraints
SPIN_CAM_MIN_DISTANCE_MM = 500.0    # 50cm - too close causes focus issues
SPIN_CAM_MAX_DISTANCE_MM = 1500.0   # 150cm - too far reduces ball size
SPIN_CAM_MIN_HEIGHT_MM = 50.0       # 5cm - minimum clearance
SPIN_CAM_MAX_HEIGHT_MM = 300.0      # 30cm - above this angle too steep

# Trajectory Camera Position Constraints
TRAJ_CAM_MIN_DISTANCE_MM = 1500.0   # 150cm - minimum to see hitbox
TRAJ_CAM_MAX_DISTANCE_MM = 3000.0   # 300cm - maximum before ball too small
TRAJ_CAM_MIN_HEIGHT_MM = 100.0      # 10cm - minimum clearance
TRAJ_CAM_MAX_HEIGHT_MM = 500.0      # 50cm - above this loses floor view


# ============================================================================
# UNIT CONVERSION UTILITIES
# ============================================================================

def mm_to_ft(mm):
    """Convert millimeters to feet"""
    return mm * MM_TO_FT

def ft_to_mm(ft):
    """Convert feet to millimeters"""
    return ft * FT_TO_MM

def mm_to_inches(mm):
    """Convert millimeters to inches"""
    return mm / 25.4

def inches_to_mm(inches):
    """Convert inches to millimeters"""
    return inches * 25.4


# ============================================================================
# DERIVED CONSTANTS (Calculated from above)
# ============================================================================

# Ball size at different distances (for detection sanity checks)
def ball_pixel_diameter_at_distance(distance_mm, focal_length_mm):
    """
    Calculate expected ball diameter in pixels at given distance.

    Uses pinhole camera model:
    pixel_size = (object_size_mm × focal_length_mm) / (distance_mm × pixel_pitch_mm)

    Args:
        distance_mm: Distance from camera to ball (mm)
        focal_length_mm: Camera focal length (mm)

    Returns:
        float: Expected ball diameter in pixels
    """
    pixel_pitch_mm = OV9281_PIXEL_SIZE_UM / 1000.0  # Convert µm to mm
    return (GOLF_BALL_DIAMETER_MM * focal_length_mm) / (distance_mm * pixel_pitch_mm)


# Expected ball sizes (for validation)
SPIN_CAM_BALL_SIZE_AT_MIN_DIST = ball_pixel_diameter_at_distance(
    SPIN_CAM_MIN_DISTANCE_MM, SPIN_CAM_FOCAL_LENGTH_MM
)
SPIN_CAM_BALL_SIZE_AT_MAX_DIST = ball_pixel_diameter_at_distance(
    SPIN_CAM_MAX_DISTANCE_MM, SPIN_CAM_FOCAL_LENGTH_MM
)

TRAJ_CAM_BALL_SIZE_AT_HITBOX_NEAR = ball_pixel_diameter_at_distance(
    HITBOX_NEAR_MM, TRAJ_CAM_FOCAL_LENGTH_MM
)
TRAJ_CAM_BALL_SIZE_AT_HITBOX_FAR = ball_pixel_diameter_at_distance(
    HITBOX_FAR_MM, TRAJ_CAM_FOCAL_LENGTH_MM
)


# ============================================================================
# VALIDATION & DEBUG INFO
# ============================================================================

def print_constants_summary():
    """Print a summary of all hardcoded constants for verification"""
    print("=" * 70)
    print("PRGR LAUNCH MONITOR - HARDCODED CONSTANTS")
    print("=" * 70)
    print()
    print("GOLF BALL:")
    print(f"  Diameter: {GOLF_BALL_DIAMETER_MM:.2f} mm ({GOLF_BALL_DIAMETER_INCHES} inches)")
    print()
    print("OV9281 SENSOR:")
    print(f"  Resolution: {OV9281_SENSOR_WIDTH_PX} × {OV9281_SENSOR_HEIGHT_PX} pixels")
    print(f"  Pixel size: {OV9281_PIXEL_SIZE_UM} µm")
    print(f"  Sensor size: {OV9281_SENSOR_WIDTH_MM:.2f} × {OV9281_SENSOR_HEIGHT_MM:.2f} mm")
    print()
    print("CAMERAS:")
    print(f"  Spin cam: {SPIN_CAM_FOCAL_LENGTH_MM} mm @ {SPIN_CAM_MAX_FPS} fps")
    print(f"  Traj cam: {TRAJ_CAM_FOCAL_LENGTH_MM} mm @ {TRAJ_CAM_MAX_FPS} fps")
    print()
    print("HITBOX (3D Detection Zone):")
    print(f"  Depth: {HITBOX_NEAR_FT} ft to {HITBOX_FAR_FT} ft ({HITBOX_NEAR_MM:.0f} - {HITBOX_FAR_MM:.0f} mm)")
    print(f"  Width: {HITBOX_WIDTH_FT} ft ({HITBOX_WIDTH_MM:.0f} mm)")
    print(f"  Height: {HITBOX_HEIGHT_FT} ft ({HITBOX_HEIGHT_MM:.0f} mm)")
    print(f"  Volume: {HITBOX_WIDTH_FT} × {HITBOX_HEIGHT_FT} × {HITBOX_FAR_FT - HITBOX_NEAR_FT} = {HITBOX_WIDTH_FT * HITBOX_HEIGHT_FT * (HITBOX_FAR_FT - HITBOX_NEAR_FT)} cubic ft")
    print()
    print("EXPECTED BALL SIZES:")
    print(f"  Spin cam @ {mm_to_ft(SPIN_CAM_MIN_DISTANCE_MM):.1f} ft: {SPIN_CAM_BALL_SIZE_AT_MIN_DIST:.1f} px")
    print(f"  Spin cam @ {mm_to_ft(SPIN_CAM_MAX_DISTANCE_MM):.1f} ft: {SPIN_CAM_BALL_SIZE_AT_MAX_DIST:.1f} px")
    print(f"  Traj cam @ hitbox near ({HITBOX_NEAR_FT} ft): {TRAJ_CAM_BALL_SIZE_AT_HITBOX_NEAR:.1f} px")
    print(f"  Traj cam @ hitbox far ({HITBOX_FAR_FT} ft): {TRAJ_CAM_BALL_SIZE_AT_HITBOX_FAR:.1f} px")
    print()
    print("=" * 70)


if __name__ == "__main__":
    # Run this file directly to see constants summary
    print_constants_summary()

    # Test hitbox detection
    print("\nTesting hitbox detection:")
    test_points = [
        (0, 150, 2200, "Center of hitbox"),
        (0, 0, 2100, "Below hitbox (ground at 7ft)"),
        (0, 400, 2200, "Above hitbox"),
        (200, 150, 2200, "Right of hitbox"),
        (0, 150, 2000, "Before hitbox (6.6ft)"),
        (0, 150, 2500, "After hitbox (8.2ft)"),
    ]

    for x, y, z, desc in test_points:
        in_box = is_ball_in_hitbox(x, y, z)
        status = "✓ IN" if in_box else "✗ OUT"
        print(f"  {status}: ({x:4.0f}, {y:3.0f}, {z:4.0f}) mm - {desc}")
