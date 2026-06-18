# PRGR Launch Monitor - Makefile
# Primary target is Raspberry Pi 5 (aarch64). Windows target is experimental.

.PHONY: build build-windows run run-dev radar-start radar-test radar-lint radar-format \
        hardware-test-ops243 hardware-test-kld7 hardware-test-camera setup clean

# Build the C++/Qt application (Raspberry Pi / Linux)
build:
	mkdir -p build && cd build && cmake .. && make -j4

# Build for Windows using Visual Studio 2022 (experimental)
# You MUST set CMAKE_PREFIX_PATH to your Qt6 installation and OpenCV_DIR to your OpenCV build.
# Example:
#   CMAKE_PREFIX_PATH=C:/Qt/6.7.0/msvc2019_64
#   OpenCV_DIR=C:/opencv/build
build-windows:
	cmake -B build -G "Visual Studio 17 2022" -A x64 \
		-DCMAKE_PREFIX_PATH="C:/Qt/6.7.0/msvc2019_64" \
		-DOpenCV_DIR="C:/opencv/build"
	cmake --build build --config Release

# Run the launch monitor application
run:
	./build/PRGR_LaunchMonitor

# Run in development mode (enables debug overlays and verbose logging)
run-dev:
	PRGR_DEV_MODE=1 ./build/PRGR_LaunchMonitor

# Start the radar bridge (OpenFlight serial bridge)
radar-start:
	cd radar && python -m openflight.bridge

# Run radar unit tests
radar-test:
	cd radar && python -m pytest tests/ -v

# Lint the radar Python code
radar-lint:
	cd radar && ruff check .

# Format the radar Python code
radar-format:
	cd radar && ruff format .

# Hardware test: OPS243-A Doppler radar
hardware-test-ops243:
	cd scripts/hardware-test && python test_ops243.py

# Hardware test: K-LD7 Doppler radar
hardware-test-kld7:
	cd scripts/hardware-test && python test_kld7.py

# Hardware test: camera FPS measurement
hardware-test-camera:
	cd scripts/hardware-test && python test_camera_fps.py

# Run the Raspberry Pi setup script (installs all dependencies)
setup:
	scripts/setup/setup.sh

# Remove build artifacts
clean:
	rm -rf build/
