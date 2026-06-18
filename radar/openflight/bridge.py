"""
PRGR Radar Bridge — connects Python radar drivers to the C++ launch monitor.

Runs as a standalone process. Manages OPS243-A and K-LD7 radars, sends shot
data to the C++ app over a Unix domain socket (or TCP localhost on Windows).

Protocol: newline-delimited JSON, one message per line.
Message types:
  - heartbeat:  {"type": "heartbeat", "ts": <epoch_ms>}
  - status:     {"type": "status", "sensor": "ops243"|"kld7_v"|"kld7_h", "state": "connected"|"error"|"offline", "msg": "..."}
  - shot_data:  {"type": "shot_data", "ball_speed_mph": ..., "club_speed_mph": ..., ...}
  - error:      {"type": "error", "msg": "..."}

The C++ side (RadarBridge manager) connects as a client, reads messages,
and exposes them to QML via Q_PROPERTY.
"""

import json
import os
import signal
import socket
import sys
import threading
import time

SOCKET_PATH = "/tmp/prgr_radar.sock"
TCP_PORT = 19730  # fallback for Windows (no Unix sockets)
HEARTBEAT_INTERVAL = 2.0


class RadarBridge:
    def __init__(self):
        self._running = False
        self._client = None
        self._client_lock = threading.Lock()
        self._server_socket = None

    def send(self, msg: dict):
        """Send a JSON message to the connected C++ client."""
        with self._client_lock:
            if self._client is None:
                return
            try:
                line = json.dumps(msg) + "\n"
                self._client.sendall(line.encode("utf-8"))
            except (BrokenPipeError, ConnectionResetError, OSError):
                self._client = None

    def send_heartbeat(self):
        self.send({"type": "heartbeat", "ts": int(time.time() * 1000)})

    def send_status(self, sensor: str, state: str, msg: str = ""):
        self.send({"type": "status", "sensor": sensor, "state": state, "msg": msg})

    def send_shot(self, shot_dict: dict):
        shot_dict["type"] = "shot_data"
        self.send(shot_dict)

    def send_error(self, msg: str):
        self.send({"type": "error", "msg": msg})

    def _heartbeat_loop(self):
        while self._running:
            self.send_heartbeat()
            time.sleep(HEARTBEAT_INTERVAL)

    def _accept_loop(self):
        """Accept one client at a time (the C++ app). Reconnects are handled by
        the C++ side closing and re-opening the connection."""
        while self._running:
            try:
                client, _ = self._server_socket.accept()
                with self._client_lock:
                    if self._client is not None:
                        try:
                            self._client.close()
                        except OSError:
                            pass
                    self._client = client
                print("[bridge] C++ client connected")
                self.send_status("bridge", "connected", "Radar bridge active")
            except OSError:
                if self._running:
                    time.sleep(0.5)

    def start(self):
        self._running = True

        # Create socket (Unix domain on Linux, TCP on Windows)
        if sys.platform == "win32":
            self._server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            self._server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            self._server_socket.bind(("127.0.0.1", TCP_PORT))
        else:
            if os.path.exists(SOCKET_PATH):
                os.unlink(SOCKET_PATH)
            self._server_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            self._server_socket.bind(SOCKET_PATH)

        self._server_socket.listen(1)
        self._server_socket.settimeout(1.0)

        threading.Thread(target=self._accept_loop, daemon=True).start()
        threading.Thread(target=self._heartbeat_loop, daemon=True).start()

        print(f"[bridge] Listening on {SOCKET_PATH if sys.platform != 'win32' else f'TCP:{TCP_PORT}'}")

    def stop(self):
        self._running = False
        with self._client_lock:
            if self._client:
                try:
                    self._client.close()
                except OSError:
                    pass
                self._client = None
        if self._server_socket:
            self._server_socket.close()
        if sys.platform != "win32" and os.path.exists(SOCKET_PATH):
            os.unlink(SOCKET_PATH)
        print("[bridge] Stopped")


def main():
    """Entry point: start radar bridge, connect sensors, run until killed."""
    bridge = RadarBridge()

    def shutdown(signum, frame):
        print("\n[bridge] Shutting down...")
        bridge.stop()
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    bridge.start()

    # --- Sensor initialization ---
    # When OpenFlight radar files are vendored (run scripts/vendor_openflight.sh),
    # uncomment the imports below and wire up the sensors.
    #
    # from openflight.ops243 import OPS243Radar
    # from openflight.kld7.tracker import KLD7Tracker
    #
    # ops = OPS243Radar()
    # kld7_vert = KLD7Tracker(orientation="vertical")
    # kld7_horiz = KLD7Tracker(orientation="horizontal")
    #
    # try:
    #     ops.connect()
    #     bridge.send_status("ops243", "connected")
    # except Exception as e:
    #     bridge.send_status("ops243", "error", str(e))
    #
    # Main loop: ops243 detects shots, kld7s provide angles,
    # bridge.send_shot() pushes results to C++.

    print("[bridge] Radar bridge running (no sensors connected yet)")
    print("[bridge] Run scripts/vendor_openflight.sh to install radar drivers")
    print("[bridge] Press Ctrl+C to stop")

    while True:
        time.sleep(1)


if __name__ == "__main__":
    main()
