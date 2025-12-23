/**
 * Python bindings for AutoExposureController
 * Ultra-fast C++ auto-exposure with Python interface
 */

#include <pybind11/pybind11.h>
#include <pybind11/numpy.h>
#include "../include/AutoExposureController.h"

namespace py = pybind11;

/**
 * @brief Wrapper for Python integration with numpy arrays
 */
class PyAutoExposureController {
public:
    PyAutoExposureController() : m_controller() {}

    void setBallZone(int center_x, int center_y, int radius) {
        m_controller.setBallZone(center_x, center_y, radius);
    }

    void setPresetMode(const std::string& mode) {
        AutoExposureController::PresetMode preset_mode;

        if (mode == "auto") {
            preset_mode = AutoExposureController::PresetMode::AUTO;
        } else if (mode == "outdoor_bright") {
            preset_mode = AutoExposureController::PresetMode::OUTDOOR_BRIGHT;
        } else if (mode == "outdoor_normal") {
            preset_mode = AutoExposureController::PresetMode::OUTDOOR_NORMAL;
        } else if (mode == "indoor") {
            preset_mode = AutoExposureController::PresetMode::INDOOR;
        } else if (mode == "indoor_dim") {
            preset_mode = AutoExposureController::PresetMode::INDOOR_DIM;
        } else {
            throw std::runtime_error("Unknown preset mode: " + mode);
        }

        m_controller.setPresetMode(preset_mode);
    }

    void setTargetBrightness(float min, float max, float ideal) {
        m_controller.setTargetBrightness(min, max, ideal);
    }

    void setShutterLimits(int min_us, int max_us) {
        m_controller.setShutterLimits(min_us, max_us);
    }

    void setGainLimits(float min, float max) {
        m_controller.setGainLimits(min, max);
    }

    void setAdjustmentSpeed(float speed) {
        m_controller.setAdjustmentSpeed(speed);
    }

    py::dict measureBrightness(py::array_t<uint8_t> frame) {
        // Get buffer info
        py::buffer_info buf = frame.request();

        if (buf.ndim != 2) {
            throw std::runtime_error("Frame must be 2D array (grayscale)");
        }

        int height = buf.shape[0];
        int width = buf.shape[1];
        int stride = buf.strides[0];  // Row stride in bytes
        const uint8_t* data = static_cast<const uint8_t*>(buf.ptr);

        // Call C++ measurement
        auto stats = m_controller.measureBrightness(data, width, height, stride);

        // Return as Python dict
        py::dict result;
        result["mean"] = stats.mean;
        result["max"] = stats.max;
        result["pixels"] = stats.pixels;
        result["valid"] = stats.valid;

        return result;
    }

    py::dict update(py::array_t<uint8_t> frame, bool force = false) {
        // Get buffer info
        py::buffer_info buf = frame.request();

        if (buf.ndim != 2) {
            throw std::runtime_error("Frame must be 2D array (grayscale)");
        }

        int height = buf.shape[0];
        int width = buf.shape[1];
        int stride = buf.strides[0];
        const uint8_t* data = static_cast<const uint8_t*>(buf.ptr);

        // Call C++ update
        auto result = m_controller.update(data, width, height, stride, force);

        // Return as Python dict
        py::dict py_result;
        py_result["adjusted"] = result.adjusted;
        py_result["shutter"] = result.shutter_us;
        py_result["gain"] = result.gain;
        py_result["brightness"] = result.brightness;
        py_result["reason"] = std::string(result.reason);

        return py_result;
    }

    int getCurrentShutter() const {
        return m_controller.getCurrentShutter();
    }

    float getCurrentGain() const {
        return m_controller.getCurrentGain();
    }

    bool isAutoMode() const {
        return m_controller.isAutoMode();
    }

    void reset() {
        m_controller.reset();
    }

private:
    AutoExposureController m_controller;
};

PYBIND11_MODULE(fast_auto_exposure, m) {
    m.doc() = "Ultra-fast auto-exposure controller for high-speed ball tracking (C++ implementation)";

    py::class_<PyAutoExposureController>(m, "AutoExposureController")
        .def(py::init<>())
        .def("set_ball_zone", &PyAutoExposureController::setBallZone,
             "Set ball detection zone for brightness measurement",
             py::arg("center_x"), py::arg("center_y"), py::arg("radius"))
        .def("set_preset_mode", &PyAutoExposureController::setPresetMode,
             "Set exposure preset mode: 'auto', 'outdoor_bright', 'outdoor_normal', 'indoor', 'indoor_dim'",
             py::arg("mode"))
        .def("set_target_brightness", &PyAutoExposureController::setTargetBrightness,
             "Set target brightness range",
             py::arg("min"), py::arg("max"), py::arg("ideal"))
        .def("set_shutter_limits", &PyAutoExposureController::setShutterLimits,
             "Set shutter speed limits in microseconds",
             py::arg("min_us"), py::arg("max_us"))
        .def("set_gain_limits", &PyAutoExposureController::setGainLimits,
             "Set analog gain limits",
             py::arg("min"), py::arg("max"))
        .def("set_adjustment_speed", &PyAutoExposureController::setAdjustmentSpeed,
             "Set adjustment speed (0.0-1.0)",
             py::arg("speed"))
        .def("measure_brightness", &PyAutoExposureController::measureBrightness,
             "Measure brightness in ball zone (returns dict with mean, max, pixels, valid)",
             py::arg("frame"))
        .def("update", &PyAutoExposureController::update,
             "Update exposure based on frame (returns dict with adjustment info)",
             py::arg("frame"), py::arg("force") = false)
        .def("get_current_shutter", &PyAutoExposureController::getCurrentShutter,
             "Get current shutter speed in microseconds")
        .def("get_current_gain", &PyAutoExposureController::getCurrentGain,
             "Get current analog gain")
        .def("is_auto_mode", &PyAutoExposureController::isAutoMode,
             "Check if auto mode is enabled")
        .def("reset", &PyAutoExposureController::reset,
             "Reset to default settings");
}
