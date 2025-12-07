cmake_minimum_required(VERSION 3.12)
project(fast_detection)

# Find Python
find_package(Python3 COMPONENTS Interpreter Development REQUIRED)

# Find pybind11 - try CONFIG first, then fallback to MODULE mode
find_package(pybind11 CONFIG QUIET)
if(NOT pybind11_FOUND)
    find_package(pybind11 REQUIRED)
endif()

# Find OpenCV
find_package(OpenCV REQUIRED)

# Create the Python extension module
pybind11_add_module(fast_detection fast_detection.cpp)

# Link OpenCV
target_link_libraries(fast_detection PRIVATE ${OpenCV_LIBS})

# Set C++ standard
target_compile_features(fast_detection PRIVATE cxx_std_11)

# Optimize for performance
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Enable optimizations
target_compile_options(fast_detection PRIVATE
    $<$<CONFIG:RELEASE>:-O3 -march=native>
)

# Installation
install(TARGETS fast_detection LIBRARY DESTINATION .)
