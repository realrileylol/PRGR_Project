/**
 * PRGR Launch Monitor - Hardcoded Constants
 * ==========================================
 *
 * These values are FIXED and should NEVER be changed by user calibration.
 * They define the physical world, hardware specs, and golf rules.
 *
 * IMPORTANT: If you need to change these, you are rebuilding the system from scratch.
 *            User-adjustable calibration goes in CalibrationManager or SettingsManager.
 */

#ifndef HARDCODED_CONSTANTS_H
#define HARDCODED_CONSTANTS_H

#include <cmath>

// ============================================================================
// GOLF BALL SPECIFICATIONS (Rules of Golf - USGA/R&A)
// ============================================================================

constexpr double GOLF_BALL_DIAMETER_MM = 42.67;        // 1.68 inches - official minimum
constexpr double GOLF_BALL_DIAMETER_INCHES = 1.68;
constexpr double GOLF_BALL_RADIUS_MM = GOLF_BALL_DIAMETER_MM / 2.0;
constexpr double GOLF_BALL_WEIGHT_GRAMS = 45.93;       // Maximum weight per rules


// ============================================================================
// CAMERA HARDWARE SPECIFICATIONS (OV9281 Sensor)
// ============================================================================

// OV9281 Sensor Physical Specs
constexpr int OV9281_SENSOR_WIDTH_PX = 1280;           // Sensor resolution - pixels
constexpr int OV9281_SENSOR_HEIGHT_PX = 800;
constexpr double OV9281_PIXEL_SIZE_UM = 3.0;           // Pixel pitch - microns (µm)
constexpr double OV9281_SENSOR_WIDTH_MM = OV9281_SENSOR_WIDTH_PX * OV9281_PIXEL_SIZE_UM / 1000.0;
constexpr double OV9281_SENSOR_HEIGHT_MM = OV9281_SENSOR_HEIGHT_PX * OV9281_PIXEL_SIZE_UM / 1000.0;

// Spin Camera (CSI OV9281 with 12mm lens)
constexpr double SPIN_CAM_FOCAL_LENGTH_MM = 12.0;      // Telephoto for close-up spin detection
constexpr int SPIN_CAM_MAX_FPS = 180;                  // Hardware limit at 640×480

// Trajectory Camera (USB OV9281 with 2.8mm lens)
constexpr double TRAJ_CAM_FOCAL_LENGTH_MM = 2.8;       // Wide angle for trajectory tracking
constexpr int TRAJ_CAM_MAX_FPS = 240;                  // Hardware limit at 640×400


// ============================================================================
// 3D WORLD COORDINATE SYSTEM
// ============================================================================

// CRITICAL: Define the origin and axes of the 3D world
// Origin: Ball position at address (tee position)
// X-axis: Perpendicular to target line (positive = right when facing target)
// Y-axis: Vertical (positive = up)
// Z-axis: Along target line (positive = toward target)


// ============================================================================
// HITBOX DEFINITION (3D Detection Zone)
// ============================================================================

// The hitbox is the 3D region where the trajectory camera MUST detect the ball
// Measured from the BALL POSITION AT ADDRESS (origin)

constexpr double HITBOX_NEAR_FT = 7.0;                 // Front face of hitbox (feet from ball)
constexpr double HITBOX_FAR_FT = 8.0;                  // Back face of hitbox (feet from ball)
constexpr double HITBOX_WIDTH_FT = 1.0;                // Total width (X-axis)
constexpr double HITBOX_HEIGHT_FT = 1.0;               // Total height (Y-axis)

// Unit conversion
constexpr double FT_TO_MM = 304.8;                     // 1 foot = 304.8 mm
constexpr double MM_TO_FT = 1.0 / FT_TO_MM;

// Convert to millimeters (internal unit for calculations)
constexpr double HITBOX_NEAR_MM = HITBOX_NEAR_FT * FT_TO_MM;          // 2133.6 mm
constexpr double HITBOX_FAR_MM = HITBOX_FAR_FT * FT_TO_MM;            // 2438.4 mm
constexpr double HITBOX_WIDTH_MM = HITBOX_WIDTH_FT * FT_TO_MM;        // 304.8 mm
constexpr double HITBOX_HEIGHT_MM = HITBOX_HEIGHT_FT * FT_TO_MM;      // 304.8 mm

// Hitbox boundaries in 3D world coordinates (mm)
constexpr double HITBOX_X_MIN = -HITBOX_WIDTH_MM / 2.0;               // -152.4 mm (left)
constexpr double HITBOX_X_MAX = +HITBOX_WIDTH_MM / 2.0;               // +152.4 mm (right)
constexpr double HITBOX_Y_MIN = 0.0;                                  // Ground level
constexpr double HITBOX_Y_MAX = HITBOX_HEIGHT_MM;                     // 304.8 mm (1ft high)
constexpr double HITBOX_Z_MIN = HITBOX_NEAR_MM;                       // 2133.6 mm (7ft)
constexpr double HITBOX_Z_MAX = HITBOX_FAR_MM;                        // 2438.4 mm (8ft)


// ============================================================================
// CAMERA POSITION CONSTRAINTS (Physical Limits)
// ============================================================================

// Spin Camera Position Constraints
constexpr double SPIN_CAM_MIN_DISTANCE_MM = 500.0;     // 50cm - too close causes focus issues
constexpr double SPIN_CAM_MAX_DISTANCE_MM = 1500.0;    // 150cm - too far reduces ball size
constexpr double SPIN_CAM_MIN_HEIGHT_MM = 50.0;        // 5cm - minimum clearance
constexpr double SPIN_CAM_MAX_HEIGHT_MM = 300.0;       // 30cm - above this angle too steep

// Trajectory Camera Position Constraints
constexpr double TRAJ_CAM_MIN_DISTANCE_MM = 1500.0;    // 150cm - minimum to see hitbox
constexpr double TRAJ_CAM_MAX_DISTANCE_MM = 3000.0;    // 300cm - maximum before ball too small
constexpr double TRAJ_CAM_MIN_HEIGHT_MM = 100.0;       // 10cm - minimum clearance
constexpr double TRAJ_CAM_MAX_HEIGHT_MM = 500.0;       // 50cm - above this loses floor view


// ============================================================================
// INLINE UTILITY FUNCTIONS
// ============================================================================

/**
 * Check if a 3D point (ball center) is inside the hitbox.
 */
inline bool isBallInHitbox(double x_mm, double y_mm, double z_mm) {
    return (x_mm >= HITBOX_X_MIN && x_mm <= HITBOX_X_MAX &&
            y_mm >= HITBOX_Y_MIN && y_mm <= HITBOX_Y_MAX &&
            z_mm >= HITBOX_Z_MIN && z_mm <= HITBOX_Z_MAX);
}

/**
 * Calculate expected ball diameter in pixels at given distance.
 *
 * Uses pinhole camera model:
 * pixel_size = (object_size_mm × focal_length_mm) / (distance_mm × pixel_pitch_mm)
 */
inline double ballPixelDiameterAtDistance(double distance_mm, double focal_length_mm) {
    const double pixel_pitch_mm = OV9281_PIXEL_SIZE_UM / 1000.0;  // Convert µm to mm
    return (GOLF_BALL_DIAMETER_MM * focal_length_mm) / (distance_mm * pixel_pitch_mm);
}

/**
 * Convert millimeters to feet
 */
inline double mmToFt(double mm) {
    return mm * MM_TO_FT;
}

/**
 * Convert feet to millimeters
 */
inline double ftToMm(double ft) {
    return ft * FT_TO_MM;
}

/**
 * Convert millimeters to inches
 */
inline double mmToInches(double mm) {
    return mm / 25.4;
}

/**
 * Convert inches to millimeters
 */
inline double inchesToMm(double inches) {
    return inches * 25.4;
}


// ============================================================================
// DERIVED CONSTANTS (Calculated at compile time)
// ============================================================================

// Expected ball sizes at various distances (for validation)
constexpr double SPIN_CAM_BALL_SIZE_AT_MIN_DIST =
    (GOLF_BALL_DIAMETER_MM * SPIN_CAM_FOCAL_LENGTH_MM) / (SPIN_CAM_MIN_DISTANCE_MM * (OV9281_PIXEL_SIZE_UM / 1000.0));

constexpr double SPIN_CAM_BALL_SIZE_AT_MAX_DIST =
    (GOLF_BALL_DIAMETER_MM * SPIN_CAM_FOCAL_LENGTH_MM) / (SPIN_CAM_MAX_DISTANCE_MM * (OV9281_PIXEL_SIZE_UM / 1000.0));

constexpr double TRAJ_CAM_BALL_SIZE_AT_HITBOX_NEAR =
    (GOLF_BALL_DIAMETER_MM * TRAJ_CAM_FOCAL_LENGTH_MM) / (HITBOX_NEAR_MM * (OV9281_PIXEL_SIZE_UM / 1000.0));

constexpr double TRAJ_CAM_BALL_SIZE_AT_HITBOX_FAR =
    (GOLF_BALL_DIAMETER_MM * TRAJ_CAM_FOCAL_LENGTH_MM) / (HITBOX_FAR_MM * (OV9281_PIXEL_SIZE_UM / 1000.0));


#endif // HARDCODED_CONSTANTS_H
