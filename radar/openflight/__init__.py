# OpenFlight radar drivers — vendored from https://github.com/jewbetcha/openflight
# Licensed under AGPL-3.0. See LICENSE_OPENFLIGHT in this directory.
#
# Core radar modules for PRGR Launch Monitor:
#   ops243      - OPS243-A Doppler radar driver (ball/club speed, I/Q capture)
#   kld7/       - K-LD7 angle radar drivers (launch angle, club path)
#   rolling_buffer/ - I/Q rolling buffer capture and FFT processing
#   ballistics  - RK4 trajectory simulation (carry distance, apex, flight time)
#   spin_estimate   - Kinematic spin estimation from ball speed + launch angle
#   speed_correction - Cosine correction for radar-measured ball speed
#   launch_monitor  - Shot data model (40+ fields)
#   session_logger  - JSONL session logging with raw data preservation
