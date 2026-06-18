# PRGR Radar Subsystem

Python radar drivers for the PRGR Launch Monitor, vendored from [OpenFlight](https://github.com/jewbetcha/openflight) (AGPL-3.0).

## Hardware

| Sensor | Role | Interface |
|---|---|---|
| OPS243-A | Ball speed, club speed, I/Q capture, spin (when SNR allows) | USB serial |
| K-LD7 (vertical) | Launch angle | USB serial, 3 Mbaud |
| K-LD7 (horizontal) | Club path | USB serial, 3 Mbaud |

## Setup

```bash
# 1. Vendor OpenFlight radar code (one-time)
../scripts/vendor_openflight.sh

# 2. Install Python package
pip install -e .

# 3. Run tests
pytest tests/ -v

# 4. Test hardware (one sensor at a time)
cd ../scripts/hardware-test
python test_ops243.py      # OPS243-A speed readings
python test_kld7.py        # K-LD7 angle data
```

## Architecture

```
OPS243-A ──► ops243.py ──► rolling_buffer/ ──► shot processing ──┐
K-LD7 vert ──► kld7/tracker.py ──► angle extraction ─────────────┤
K-LD7 horiz ──► kld7/tracker.py ──► angle extraction ────────────┤
                                                                  ▼
                                                          bridge.py
                                                              │
                                                    Unix socket (JSON)
                                                              │
                                                              ▼
                                                    C++ RadarBridge
                                                      (Qt/QML UI)
```

The bridge runs as a standalone Python process. The C++ app launches it as a child
process and connects via Unix domain socket. Protocol is newline-delimited JSON.

## Key Modules

| Module | Source | Purpose |
|---|---|---|
| `ops243.py` | OpenFlight | OPS243-A serial driver, I/Q capture, rolling buffer |
| `kld7/` | OpenFlight | K-LD7 serial I/O, RADC parsing, angle extraction |
| `rolling_buffer/` | OpenFlight | I/Q capture, FFT processing, spin detection |
| `ballistics.py` | OpenFlight | RK4 trajectory simulation (carry, apex, flight time) |
| `spin_estimate.py` | OpenFlight | Kinematic spin from ball speed + launch angle |
| `speed_correction.py` | OpenFlight | Cosine correction for radar ball speed |
| `launch_monitor.py` | OpenFlight | Shot data model (40+ fields) |
| `session_logger.py` | OpenFlight | JSONL session logging |
| `bridge.py` | **PRGR original** | Unix socket bridge to C++ app |
