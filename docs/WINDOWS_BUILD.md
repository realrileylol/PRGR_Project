# Windows Desktop Build (Staging / Development Mode)

This builds the full PRGR Launch Monitor UI on a Windows laptop — no Raspberry Pi,
no cameras, no radar. The app starts in **Development Mode** automatically
(simulated camera feed + simulated radar), so every screen is clickable:
profiles, club bags, settings, history, the K-LD2 monitor with "Simulate Swing", etc.

Live capture paths are compiled out on Windows (`#ifdef _WIN32` guards) and show a
friendly message instead of crashing.

---

## What you need

| Piece | What it is | How to get it |
|---|---|---|
| Qt 6.8.2 | The UI framework | `aqt install-qt` (below) |
| C++ compiler | Turns code into an .exe | MinGW via aqt, **or** Visual Studio from your company portal |
| OpenCV 4 | Vision library (the sim frames use it too) | Prebuilt download (MSVC) or source build (MinGW) |
| CMake + Ninja | Build system | `pip install cmake ninja` |

> **Rule: everything must use the same compiler.** Qt built for MSVC + OpenCV built
> for MinGW will not link. Pick one path below and stick to it.

---

## Path A — MSVC (recommended if Visual Studio is in your company portal)

OpenCV ships prebuilt binaries for MSVC, which makes this the easy path.

1. **Install Visual Studio** from the company portal with the
   **"Desktop development with C++"** workload.

2. **Install Qt (MSVC build):**
   ```
   aqt install-qt windows desktop 6.8.2 win64_msvc2022_64 -O C:\Users\RileySasiain\Qt
   ```

3. **Install OpenCV (prebuilt):** download the Windows package from
   https://opencv.org/releases/ (e.g. `opencv-4.10.0-windows.exe`), run it, and
   extract to `C:\Users\RileySasiain\opencv`.

4. **Install build tools:**
   ```
   pip install cmake ninja
   ```

5. **Configure & build** (from a *"x64 Native Tools Command Prompt for VS"*):
   ```
   cd path\to\PRGR_Project
   cmake -B build -G Ninja ^
     -DCMAKE_PREFIX_PATH="C:/Users/RileySasiain/Qt/6.8.2/msvc2022_64" ^
     -DOpenCV_DIR="C:/Users/RileySasiain/opencv/build" ^
     -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

6. **Run it:**
   ```
   C:\Users\RileySasiain\Qt\6.8.2\msvc2022_64\bin\windeployqt --qmldir . build\PRGR_LaunchMonitor.exe
   build\PRGR_LaunchMonitor.exe
   ```
   (`windeployqt` copies the Qt DLLs and QML modules next to the .exe — run it once.
   Also copy `opencv_world4100.dll` from `opencv\build\x64\vc16\bin` next to the exe.)

---

## Path B — MinGW (no Visual Studio needed)

You already have the Qt MinGW build downloading. The catch: OpenCV has **no
official MinGW binaries**, so OpenCV must be compiled from source once (~30-60 min,
one time only).

1. **Qt + compiler** (you've already run these):
   ```
   aqt install-qt windows desktop 6.8.2 win64_mingw -O C:\Users\RileySasiain\Qt
   aqt install-tool windows desktop tools_mingw1310 -O C:\Users\RileySasiain\Qt
   ```

2. **Build tools:**
   ```
   pip install cmake ninja
   ```

3. **Put MinGW on PATH** (current terminal only):
   ```
   set PATH=C:\Users\RileySasiain\Qt\Tools\mingw1310_64\bin;%PATH%
   ```

4. **Build OpenCV from source** (one time):
   ```
   git clone --depth 1 --branch 4.10.0 https://github.com/opencv/opencv.git C:\Users\RileySasiain\opencv-src
   cmake -B C:\Users\RileySasiain\opencv-build -G Ninja ^
     -DCMAKE_BUILD_TYPE=Release ^
     -DBUILD_LIST=core,imgproc,imgcodecs,videoio,calib3d,features2d,video ^
     -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF ^
     C:\Users\RileySasiain\opencv-src
   cmake --build C:\Users\RileySasiain\opencv-build
   ```

5. **Configure & build the app:**
   ```
   cd path\to\PRGR_Project
   cmake -B build -G Ninja ^
     -DCMAKE_PREFIX_PATH="C:/Users/RileySasiain/Qt/6.8.2/mingw_64" ^
     -DOpenCV_DIR="C:/Users/RileySasiain/opencv-build" ^
     -DCMAKE_BUILD_TYPE=Release
   cmake --build build
   ```

6. **Run it:**
   ```
   C:\Users\RileySasiain\Qt\6.8.2\mingw_64\bin\windeployqt --qmldir . build\PRGR_LaunchMonitor.exe
   build\PRGR_LaunchMonitor.exe
   ```

---

## What works in the Windows build

| Feature | Status |
|---|---|
| Full QML UI (all screens) | ✅ |
| Development Mode (auto-on) | ✅ simulated camera + radar |
| Simulate Swing (K-LD2 monitor) | ✅ |
| Profiles / club bag / history / settings | ✅ real data, stored locally |
| Live camera preview | ❌ shows "requires Raspberry Pi hardware" |
| Shot capture / recording | ❌ Pi only |
| Real radar serial I/O | ❌ Pi only |

## Troubleshooting

- **`Could NOT find OpenCV`** — `OpenCV_DIR` must point at the folder containing
  `OpenCVConfig.cmake` (`opencv/build` for prebuilt, the build folder for source builds).
- **Blank window / QML errors** — you skipped `windeployqt --qmldir .`; Qt can't
  find its QML modules.
- **`0xc000007b` or missing DLL on launch** — mixed 32/64-bit or mixed compilers;
  verify Qt, OpenCV, and the compiler are all the same toolchain.
- **Corporate proxy blocks downloads** — aqt honors `HTTPS_PROXY`; set it to your
  company proxy if downloads stall.
