#!/usr/bin/env python3
"""
Standalone K-LD2 Radar Test GUI
================================
A completely separate GUI for testing and tuning K-LD2 radar detection
independently from the main application.

Features:
- Real-time speed display (approaching/receding)
- State machine visualization (IDLE → ARMED → TRIGGERED)
- Adjustable thresholds via sliders
- Practice swing detection
- Event logging with timestamps
- Simulated capture indicators

Usage:
    python3 radar_test_gui.py

Requirements:
    pip install PySide6 pyserial
"""

import sys
import serial
import time
from datetime import datetime
from enum import Enum, auto
from dataclasses import dataclass
from typing import Optional
import threading

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QSlider, QGroupBox, QTextEdit, QFrame,
    QGridLayout, QSpinBox, QComboBox, QSplitter
)
from PySide6.QtCore import Qt, QTimer, Signal, QObject
from PySide6.QtGui import QFont, QColor, QPalette


# =============================================================================
# State Machine
# =============================================================================

class DetectionState(Enum):
    """Radar detection state machine states"""
    IDLE = auto()           # Waiting for swing
    ARMED = auto()          # Club detected, waiting for ball
    TRIGGERED = auto()      # Ball detected, capture in progress
    PRACTICE_SWING = auto() # Timeout, no ball detected


@dataclass
class RadarReading:
    """Single radar reading"""
    timestamp: datetime
    approaching_speed: int  # Club (toward radar)
    receding_speed: int     # Ball (away from radar)
    approaching_mag: int
    receding_mag: int


# =============================================================================
# Radar Communication (runs in background thread)
# =============================================================================

class RadarSignals(QObject):
    """Signals for thread-safe communication"""
    reading_received = Signal(int, int, int, int)  # approaching, receding, app_mag, rec_mag
    status_changed = Signal(str, str)  # message, color
    connected = Signal(bool)


class RadarConnection:
    """Handles serial communication with K-LD2 radar"""

    BAUD_RATE = 38400
    CMD_SET_SAMPLING = b'$S0405\r\n'
    CMD_GET_SPEED = b'$C01\r\n'
    PORT_CANDIDATES = ['/dev/serial0', '/dev/ttyAMA0', '/dev/ttyS0']

    def __init__(self):
        self.serial_port: Optional[serial.Serial] = None
        self.signals = RadarSignals()
        self._running = False
        self._thread: Optional[threading.Thread] = None

    def connect(self, port: str = "") -> bool:
        """Connect to radar on specified or auto-detected port"""
        ports = [port] if port else self.PORT_CANDIDATES

        for p in ports:
            try:
                self.signals.status_changed.emit(f"Trying {p}...", "orange")
                self.serial_port = serial.Serial(
                    port=p,
                    baudrate=self.BAUD_RATE,
                    timeout=1.0
                )

                # Configure sampling rate
                time.sleep(0.2)
                self.serial_port.write(self.CMD_SET_SAMPLING)
                time.sleep(0.3)
                self.serial_port.read(self.serial_port.in_waiting)  # Clear buffer

                self.signals.status_changed.emit(f"Connected: {p}", "green")
                self.signals.connected.emit(True)
                return True

            except Exception as e:
                continue

        self.signals.status_changed.emit("Radar not found", "red")
        self.signals.connected.emit(False)
        return False

    def disconnect(self):
        """Disconnect from radar"""
        self._running = False
        if self._thread:
            self._thread.join(timeout=2.0)
        if self.serial_port:
            self.serial_port.close()
            self.serial_port = None
        self.signals.connected.emit(False)
        self.signals.status_changed.emit("Disconnected", "gray")

    def start_polling(self):
        """Start background polling thread"""
        if not self.serial_port:
            return
        self._running = True
        self._thread = threading.Thread(target=self._poll_loop, daemon=True)
        self._thread.start()

    def stop_polling(self):
        """Stop polling"""
        self._running = False

    def send_command(self, cmd: str) -> Optional[str]:
        """Send a command to the radar and return response"""
        if not self.serial_port:
            return None
        try:
            # Pause polling briefly
            was_running = self._running
            self._running = False
            time.sleep(0.1)

            # Send command
            if not cmd.endswith('\r\n'):
                cmd += '\r\n'
            self.serial_port.write(cmd.encode('ascii'))
            time.sleep(0.3)

            # Read response
            response = ""
            if self.serial_port.in_waiting > 0:
                response = self.serial_port.read(self.serial_port.in_waiting).decode('ascii', errors='ignore')

            # Resume polling
            if was_running:
                self._running = True

            return response.strip()
        except Exception as e:
            return f"Error: {e}"

    def set_sampling_rate(self, rate_code: str):
        """
        Set K-LD2 sampling rate.
        Codes: 0405 = 20480 Hz (fast, for golf)
               0406 = 10240 Hz
               0407 = 5120 Hz (slower but more sensitive)
        """
        cmd = f"$S{rate_code}"
        response = self.send_command(cmd)
        self.signals.status_changed.emit(f"Sampling: {rate_code}", "green")
        return response

    def _poll_loop(self):
        """Background thread: poll radar and emit readings"""
        buffer = ""

        while self._running and self.serial_port:
            try:
                self.serial_port.write(self.CMD_GET_SPEED)
                time.sleep(0.05)  # 20 Hz polling

                if self.serial_port.in_waiting > 0:
                    data = self.serial_port.read(self.serial_port.in_waiting)
                    buffer += data.decode('ascii', errors='ignore')

                    while '\n' in buffer:
                        line, buffer = buffer.split('\n', 1)
                        line = line.strip()

                        if line and not line.startswith('$') and not line.startswith('@'):
                            self._parse_and_emit(line)

            except Exception as e:
                if self._running:
                    time.sleep(0.1)

    def _parse_and_emit(self, line: str):
        """Parse response and emit signal"""
        try:
            parts = line.split(';')
            if len(parts) >= 4:
                approaching = int(parts[0])
                receding = int(parts[1])
                app_mag = int(parts[2])
                rec_mag = int(parts[3])
                self.signals.reading_received.emit(approaching, receding, app_mag, rec_mag)
        except (ValueError, IndexError):
            pass


# =============================================================================
# Detection State Machine
# =============================================================================

class DetectionStateMachine(QObject):
    """
    State machine for detecting real shots vs practice swings.

    Flow:
    IDLE → (approaching > club_threshold) → ARMED
    ARMED → (receding > ball_threshold within timeout) → TRIGGERED
    ARMED → (timeout, no ball) → PRACTICE_SWING → IDLE
    TRIGGERED → (complete) → IDLE
    """

    state_changed = Signal(str, str)  # state_name, color
    shot_detected = Signal(float, float)  # club_speed, ball_speed
    practice_swing = Signal(float)  # club_speed
    event_logged = Signal(str)  # log message

    def __init__(self):
        super().__init__()

        # Thresholds (adjustable via UI)
        self.club_threshold = 40.0  # mph - minimum to arm
        self.ball_threshold = 60.0  # mph - minimum to trigger
        self.arm_timeout_ms = 200   # ms - window after club detection

        # State
        self._state = DetectionState.IDLE
        self._armed_time: Optional[float] = None
        self._max_club_speed = 0.0
        self._max_ball_speed = 0.0

        # Timeout timer
        self._timeout_timer = QTimer()
        self._timeout_timer.setSingleShot(True)
        self._timeout_timer.timeout.connect(self._on_timeout)

    @property
    def state(self) -> DetectionState:
        return self._state

    def set_club_threshold(self, value: float):
        self.club_threshold = value

    def set_ball_threshold(self, value: float):
        self.ball_threshold = value

    def set_timeout(self, value_ms: int):
        self.arm_timeout_ms = value_ms

    def process_reading(self, approaching: int, receding: int):
        """Process a radar reading through the state machine"""

        # === IDLE STATE ===
        if self._state == DetectionState.IDLE:
            # Look for club approaching (downswing)
            if approaching >= self.club_threshold:
                self._state = DetectionState.ARMED
                self._armed_time = time.time()
                self._max_club_speed = approaching
                self._max_ball_speed = 0.0

                # Start timeout timer
                self._timeout_timer.start(self.arm_timeout_ms)

                self.state_changed.emit("ARMED", "#FFA500")  # Orange
                self.event_logged.emit(
                    f"[{self._timestamp()}] ⛳ ARMED: Club {approaching} mph detected"
                )

        # === ARMED STATE ===
        elif self._state == DetectionState.ARMED:
            # Track max club speed
            if approaching > self._max_club_speed:
                self._max_club_speed = approaching

            # Check for ball (receding speed)
            if receding >= self.ball_threshold:
                self._timeout_timer.stop()
                self._max_ball_speed = receding
                self._state = DetectionState.TRIGGERED

                self.state_changed.emit("TRIGGERED", "#00FF00")  # Green
                self.event_logged.emit(
                    f"[{self._timestamp()}] 🎯 TRIGGERED: Ball {receding} mph detected!"
                )
                self.shot_detected.emit(self._max_club_speed, receding)

                # Auto-reset after short delay
                QTimer.singleShot(1500, self._reset_to_idle)

        # === TRIGGERED STATE ===
        elif self._state == DetectionState.TRIGGERED:
            # Track max ball speed during trigger window
            if receding > self._max_ball_speed:
                self._max_ball_speed = receding

    def _on_timeout(self):
        """Called when arm timeout expires without ball detection"""
        if self._state == DetectionState.ARMED:
            self._state = DetectionState.PRACTICE_SWING

            self.state_changed.emit("PRACTICE", "#808080")  # Gray
            self.event_logged.emit(
                f"[{self._timestamp()}] 🏌️ PRACTICE SWING: Club {self._max_club_speed} mph (no ball)"
            )
            self.practice_swing.emit(self._max_club_speed)

            # Reset after short delay
            QTimer.singleShot(500, self._reset_to_idle)

    def _reset_to_idle(self):
        """Reset state machine to idle"""
        self._state = DetectionState.IDLE
        self._armed_time = None
        self._max_club_speed = 0.0
        self._max_ball_speed = 0.0
        self.state_changed.emit("IDLE", "#4444FF")  # Blue

    def reset(self):
        """Manual reset"""
        self._timeout_timer.stop()
        self._reset_to_idle()
        self.event_logged.emit(f"[{self._timestamp()}] ↺ Manual reset")

    def _timestamp(self) -> str:
        return datetime.now().strftime("%H:%M:%S.%f")[:-3]


# =============================================================================
# Main GUI Window
# =============================================================================

class RadarTestWindow(QMainWindow):
    """Main window for radar testing GUI"""

    def __init__(self):
        super().__init__()

        self.setWindowTitle("K-LD2 Radar Test GUI")
        self.setMinimumSize(900, 700)

        # Components
        self.radar = RadarConnection()
        self.state_machine = DetectionStateMachine()

        # Connect signals
        self.radar.signals.reading_received.connect(self._on_reading)
        self.radar.signals.status_changed.connect(self._on_radar_status)
        self.radar.signals.connected.connect(self._on_connected)

        self.state_machine.state_changed.connect(self._on_state_changed)
        self.state_machine.shot_detected.connect(self._on_shot_detected)
        self.state_machine.practice_swing.connect(self._on_practice_swing)
        self.state_machine.event_logged.connect(self._log_event)

        # Stats
        self.shot_count = 0
        self.practice_count = 0

        # Build UI
        self._setup_ui()

        # Update timer for UI refresh
        self._update_timer = QTimer()
        self._update_timer.timeout.connect(self._update_displays)
        self._update_timer.start(100)  # 10 Hz UI update

        # Current readings
        self._current_approaching = 0
        self._current_receding = 0
        self._current_app_mag = 0
        self._current_rec_mag = 0

    def _setup_ui(self):
        """Build the UI"""
        central = QWidget()
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setSpacing(10)

        # === TOP: Connection & Status ===
        top_layout = QHBoxLayout()

        # Connection controls
        conn_group = QGroupBox("Connection")
        conn_layout = QHBoxLayout(conn_group)

        self.port_combo = QComboBox()
        self.port_combo.addItems(["Auto", "/dev/serial0", "/dev/ttyAMA0", "/dev/ttyS0"])
        self.port_combo.setMinimumWidth(120)
        conn_layout.addWidget(QLabel("Port:"))
        conn_layout.addWidget(self.port_combo)

        self.connect_btn = QPushButton("Connect")
        self.connect_btn.clicked.connect(self._toggle_connection)
        conn_layout.addWidget(self.connect_btn)

        self.status_label = QLabel("Disconnected")
        self.status_label.setStyleSheet("color: gray; font-weight: bold;")
        conn_layout.addWidget(self.status_label)

        top_layout.addWidget(conn_group)

        # State display
        state_group = QGroupBox("Detection State")
        state_layout = QHBoxLayout(state_group)

        self.state_label = QLabel("IDLE")
        self.state_label.setAlignment(Qt.AlignCenter)
        self.state_label.setFont(QFont("Arial", 24, QFont.Bold))
        self.state_label.setStyleSheet("""
            background-color: #4444FF;
            color: white;
            padding: 10px 30px;
            border-radius: 10px;
        """)
        state_layout.addWidget(self.state_label)

        top_layout.addWidget(state_group)

        main_layout.addLayout(top_layout)

        # === MIDDLE: Speed Displays & Controls ===
        middle_splitter = QSplitter(Qt.Horizontal)

        # Left: Speed displays
        speed_widget = QWidget()
        speed_layout = QVBoxLayout(speed_widget)

        # Approaching (Club) speed
        club_group = QGroupBox("Club Speed (Approaching)")
        club_layout = QVBoxLayout(club_group)

        self.club_speed_label = QLabel("0")
        self.club_speed_label.setAlignment(Qt.AlignCenter)
        self.club_speed_label.setFont(QFont("Arial", 48, QFont.Bold))
        self.club_speed_label.setStyleSheet("color: #FF6600;")
        club_layout.addWidget(self.club_speed_label)

        club_layout.addWidget(QLabel("mph", alignment=Qt.AlignCenter))

        # Club magnitude (signal strength)
        self.club_mag_label = QLabel("Signal: --")
        self.club_mag_label.setAlignment(Qt.AlignCenter)
        self.club_mag_label.setStyleSheet("color: #888;")
        club_layout.addWidget(self.club_mag_label)

        speed_layout.addWidget(club_group)

        # Receding (Ball) speed
        ball_group = QGroupBox("Ball Speed (Receding)")
        ball_layout = QVBoxLayout(ball_group)

        self.ball_speed_label = QLabel("0")
        self.ball_speed_label.setAlignment(Qt.AlignCenter)
        self.ball_speed_label.setFont(QFont("Arial", 48, QFont.Bold))
        self.ball_speed_label.setStyleSheet("color: #00AA00;")
        ball_layout.addWidget(self.ball_speed_label)

        ball_layout.addWidget(QLabel("mph", alignment=Qt.AlignCenter))

        # Ball magnitude (signal strength)
        self.ball_mag_label = QLabel("Signal: --")
        self.ball_mag_label.setAlignment(Qt.AlignCenter)
        self.ball_mag_label.setStyleSheet("color: #888;")
        ball_layout.addWidget(self.ball_mag_label)

        speed_layout.addWidget(ball_group)

        middle_splitter.addWidget(speed_widget)

        # Right: Controls
        controls_widget = QWidget()
        controls_layout = QVBoxLayout(controls_widget)

        # Thresholds
        thresh_group = QGroupBox("Detection Thresholds")
        thresh_layout = QGridLayout(thresh_group)

        # Club threshold
        thresh_layout.addWidget(QLabel("Club Threshold:"), 0, 0)
        self.club_thresh_slider = QSlider(Qt.Horizontal)
        self.club_thresh_slider.setRange(10, 100)
        self.club_thresh_slider.setValue(40)
        self.club_thresh_slider.valueChanged.connect(self._on_club_thresh_changed)
        thresh_layout.addWidget(self.club_thresh_slider, 0, 1)
        self.club_thresh_label = QLabel("40 mph")
        thresh_layout.addWidget(self.club_thresh_label, 0, 2)

        # Ball threshold
        thresh_layout.addWidget(QLabel("Ball Threshold:"), 1, 0)
        self.ball_thresh_slider = QSlider(Qt.Horizontal)
        self.ball_thresh_slider.setRange(20, 150)
        self.ball_thresh_slider.setValue(60)
        self.ball_thresh_slider.valueChanged.connect(self._on_ball_thresh_changed)
        thresh_layout.addWidget(self.ball_thresh_slider, 1, 1)
        self.ball_thresh_label = QLabel("60 mph")
        thresh_layout.addWidget(self.ball_thresh_label, 1, 2)

        # Timeout
        thresh_layout.addWidget(QLabel("Arm Timeout:"), 2, 0)
        self.timeout_spin = QSpinBox()
        self.timeout_spin.setRange(50, 500)
        self.timeout_spin.setValue(200)
        self.timeout_spin.setSuffix(" ms")
        self.timeout_spin.valueChanged.connect(self._on_timeout_changed)
        thresh_layout.addWidget(self.timeout_spin, 2, 1)

        controls_layout.addWidget(thresh_group)

        # Radar Settings
        radar_group = QGroupBox("Radar Settings")
        radar_layout = QGridLayout(radar_group)

        # Sampling rate
        radar_layout.addWidget(QLabel("Sampling Rate:"), 0, 0)
        self.sampling_combo = QComboBox()
        self.sampling_combo.addItems([
            "20480 Hz (Fast - Default)",
            "10240 Hz (Medium)",
            "5120 Hz (Slow - More Sensitive)"
        ])
        self.sampling_combo.currentIndexChanged.connect(self._on_sampling_changed)
        radar_layout.addWidget(self.sampling_combo, 0, 1)

        # Custom command
        radar_layout.addWidget(QLabel("Custom Cmd:"), 1, 0)
        self.cmd_combo = QComboBox()
        self.cmd_combo.setEditable(True)
        self.cmd_combo.addItems([
            "$C01",      # Get speed with direction
            "$C00",      # Get speed without direction
            "$S0405",    # 20480 Hz
            "$S0406",    # 10240 Hz
            "$S0407",    # 5120 Hz
            "$R00",      # Get detection config
            "$I00",      # Get info
        ])
        radar_layout.addWidget(self.cmd_combo, 1, 1)

        self.send_cmd_btn = QPushButton("Send")
        self.send_cmd_btn.clicked.connect(self._on_send_command)
        radar_layout.addWidget(self.send_cmd_btn, 1, 2)

        controls_layout.addWidget(radar_group)

        # Stats
        stats_group = QGroupBox("Session Stats")
        stats_layout = QGridLayout(stats_group)

        stats_layout.addWidget(QLabel("Shots Detected:"), 0, 0)
        self.shots_label = QLabel("0")
        self.shots_label.setFont(QFont("Arial", 16, QFont.Bold))
        self.shots_label.setStyleSheet("color: #00AA00;")
        stats_layout.addWidget(self.shots_label, 0, 1)

        stats_layout.addWidget(QLabel("Practice Swings:"), 1, 0)
        self.practice_label = QLabel("0")
        self.practice_label.setFont(QFont("Arial", 16, QFont.Bold))
        self.practice_label.setStyleSheet("color: #888888;")
        stats_layout.addWidget(self.practice_label, 1, 1)

        stats_layout.addWidget(QLabel("Last Club:"), 2, 0)
        self.last_club_label = QLabel("-- mph")
        stats_layout.addWidget(self.last_club_label, 2, 1)

        stats_layout.addWidget(QLabel("Last Ball:"), 3, 0)
        self.last_ball_label = QLabel("-- mph")
        stats_layout.addWidget(self.last_ball_label, 3, 1)

        controls_layout.addWidget(stats_group)

        # Buttons
        btn_layout = QHBoxLayout()

        self.reset_btn = QPushButton("Reset State")
        self.reset_btn.clicked.connect(self.state_machine.reset)
        btn_layout.addWidget(self.reset_btn)

        self.clear_btn = QPushButton("Clear Log")
        self.clear_btn.clicked.connect(self._clear_log)
        btn_layout.addWidget(self.clear_btn)

        controls_layout.addLayout(btn_layout)
        controls_layout.addStretch()

        middle_splitter.addWidget(controls_widget)
        middle_splitter.setSizes([500, 400])

        main_layout.addWidget(middle_splitter)

        # === BOTTOM: Event Log ===
        log_group = QGroupBox("Event Log")
        log_layout = QVBoxLayout(log_group)

        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setFont(QFont("Consolas", 10))
        self.log_text.setMaximumHeight(200)
        log_layout.addWidget(self.log_text)

        main_layout.addWidget(log_group)

        # === Capture Simulation Indicator ===
        self.capture_indicator = QLabel("")
        self.capture_indicator.setAlignment(Qt.AlignCenter)
        self.capture_indicator.setFont(QFont("Arial", 14, QFont.Bold))
        self.capture_indicator.setStyleSheet("""
            background-color: #333;
            color: white;
            padding: 10px;
            border-radius: 5px;
        """)
        self.capture_indicator.hide()
        main_layout.addWidget(self.capture_indicator)

    # === Slots ===

    def _toggle_connection(self):
        """Connect or disconnect from radar"""
        if self.radar.serial_port:
            self.radar.stop_polling()
            self.radar.disconnect()
            self.connect_btn.setText("Connect")
        else:
            port = self.port_combo.currentText()
            if port == "Auto":
                port = ""

            if self.radar.connect(port):
                self.radar.start_polling()
                self.connect_btn.setText("Disconnect")

    def _on_connected(self, connected: bool):
        """Handle connection state change"""
        self.connect_btn.setText("Disconnect" if connected else "Connect")

    def _on_radar_status(self, message: str, color: str):
        """Update status label"""
        self.status_label.setText(message)
        self.status_label.setStyleSheet(f"color: {color}; font-weight: bold;")

    def _on_reading(self, approaching: int, receding: int, app_mag: int, rec_mag: int):
        """Handle incoming radar reading"""
        self._current_approaching = approaching
        self._current_receding = receding
        self._current_app_mag = app_mag
        self._current_rec_mag = rec_mag

        # Feed to state machine
        self.state_machine.process_reading(approaching, receding)

    def _on_state_changed(self, state_name: str, color: str):
        """Update state display"""
        self.state_label.setText(state_name)
        self.state_label.setStyleSheet(f"""
            background-color: {color};
            color: white;
            padding: 10px 30px;
            border-radius: 10px;
        """)

    def _on_shot_detected(self, club_speed: float, ball_speed: float):
        """Handle detected shot"""
        self.shot_count += 1
        self.shots_label.setText(str(self.shot_count))
        self.last_club_label.setText(f"{club_speed:.0f} mph")
        self.last_ball_label.setText(f"{ball_speed:.0f} mph")

        # Show capture simulation
        self.capture_indicator.setText(f"📸 CAPTURE: Club {club_speed:.0f} mph → Ball {ball_speed:.0f} mph")
        self.capture_indicator.setStyleSheet("""
            background-color: #00AA00;
            color: white;
            padding: 10px;
            border-radius: 5px;
        """)
        self.capture_indicator.show()
        QTimer.singleShot(2000, self.capture_indicator.hide)

    def _on_practice_swing(self, club_speed: float):
        """Handle practice swing"""
        self.practice_count += 1
        self.practice_label.setText(str(self.practice_count))
        self.last_club_label.setText(f"{club_speed:.0f} mph")
        self.last_ball_label.setText("-- mph")

        # Show practice indicator
        self.capture_indicator.setText(f"🏌️ PRACTICE SWING: Club {club_speed:.0f} mph (ignored)")
        self.capture_indicator.setStyleSheet("""
            background-color: #666;
            color: white;
            padding: 10px;
            border-radius: 5px;
        """)
        self.capture_indicator.show()
        QTimer.singleShot(1500, self.capture_indicator.hide)

    def _on_club_thresh_changed(self, value: int):
        """Update club threshold"""
        self.club_thresh_label.setText(f"{value} mph")
        self.state_machine.set_club_threshold(float(value))

    def _on_ball_thresh_changed(self, value: int):
        """Update ball threshold"""
        self.ball_thresh_label.setText(f"{value} mph")
        self.state_machine.set_ball_threshold(float(value))

    def _on_timeout_changed(self, value: int):
        """Update arm timeout"""
        self.state_machine.set_timeout(value)

    def _on_sampling_changed(self, index: int):
        """Change radar sampling rate"""
        rate_codes = ["0405", "0406", "0407"]
        if 0 <= index < len(rate_codes):
            response = self.radar.set_sampling_rate(rate_codes[index])
            self._log_event(f"[{datetime.now().strftime('%H:%M:%S')}] Sampling rate changed: {rate_codes[index]}")

    def _on_send_command(self):
        """Send custom command to radar"""
        cmd = self.cmd_combo.currentText().strip()
        if cmd:
            response = self.radar.send_command(cmd)
            self._log_event(f"[{datetime.now().strftime('%H:%M:%S')}] CMD: {cmd} → {response}")

    def _log_event(self, message: str):
        """Add event to log"""
        self.log_text.append(message)
        # Auto-scroll
        self.log_text.verticalScrollBar().setValue(
            self.log_text.verticalScrollBar().maximum()
        )

    def _clear_log(self):
        """Clear event log"""
        self.log_text.clear()

    def _update_displays(self):
        """Update speed displays (called by timer)"""
        self.club_speed_label.setText(str(self._current_approaching))
        self.ball_speed_label.setText(str(self._current_receding))

        # Update magnitude displays with signal strength indicator
        # Magnitude 0-100: weak, 100-200: medium, 200+: strong
        self._update_mag_label(self.club_mag_label, self._current_app_mag)
        self._update_mag_label(self.ball_mag_label, self._current_rec_mag)

        # Color based on threshold
        if self._current_approaching >= self.state_machine.club_threshold:
            self.club_speed_label.setStyleSheet("color: #FF0000; font-weight: bold;")
        elif self._current_approaching > 0:
            self.club_speed_label.setStyleSheet("color: #FF6600;")
        else:
            self.club_speed_label.setStyleSheet("color: #CCCCCC;")

        if self._current_receding >= self.state_machine.ball_threshold:
            self.ball_speed_label.setStyleSheet("color: #00FF00; font-weight: bold;")
        elif self._current_receding > 0:
            self.ball_speed_label.setStyleSheet("color: #00AA00;")
        else:
            self.ball_speed_label.setStyleSheet("color: #CCCCCC;")

    def _update_mag_label(self, label: QLabel, mag: int):
        """Update magnitude label with color-coded signal strength"""
        if mag == 0:
            label.setText("Signal: --")
            label.setStyleSheet("color: #666;")
        elif mag < 50:
            label.setText(f"Signal: {mag} (WEAK)")
            label.setStyleSheet("color: #FF4444;")
        elif mag < 100:
            label.setText(f"Signal: {mag} (LOW)")
            label.setStyleSheet("color: #FFAA00;")
        elif mag < 150:
            label.setText(f"Signal: {mag} (OK)")
            label.setStyleSheet("color: #AAAA00;")
        else:
            label.setText(f"Signal: {mag} (GOOD)")
            label.setStyleSheet("color: #44FF44;")

    def closeEvent(self, event):
        """Clean up on close"""
        self.radar.stop_polling()
        self.radar.disconnect()
        event.accept()


# =============================================================================
# Main
# =============================================================================

def main():
    app = QApplication(sys.argv)

    # Dark theme
    app.setStyle("Fusion")
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(53, 53, 53))
    palette.setColor(QPalette.WindowText, Qt.white)
    palette.setColor(QPalette.Base, QColor(25, 25, 25))
    palette.setColor(QPalette.AlternateBase, QColor(53, 53, 53))
    palette.setColor(QPalette.ToolTipBase, Qt.white)
    palette.setColor(QPalette.ToolTipText, Qt.white)
    palette.setColor(QPalette.Text, Qt.white)
    palette.setColor(QPalette.Button, QColor(53, 53, 53))
    palette.setColor(QPalette.ButtonText, Qt.white)
    palette.setColor(QPalette.BrightText, Qt.red)
    palette.setColor(QPalette.Link, QColor(42, 130, 218))
    palette.setColor(QPalette.Highlight, QColor(42, 130, 218))
    palette.setColor(QPalette.HighlightedText, Qt.black)
    app.setPalette(palette)

    window = RadarTestWindow()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
