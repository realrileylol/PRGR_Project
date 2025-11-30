#!/usr/bin/env python3
"""
Simple KLD2 Sensor Monitor
Live visualization without GNU Radio - uses matplotlib for plotting
"""

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from scipy import signal
from collections import deque
import time
from kld2_sensor import KLD2Sensor


class SimpleKLD2Monitor:
    """Simple real-time monitor for KLD2 sensor"""

    def __init__(self, sample_rate=1000, buffer_size=2000, simulation=True):
        """
        Initialize the monitor

        Args:
            sample_rate: Sampling rate in Hz
            buffer_size: Number of samples to display
            simulation: Use simulated data
        """
        self.sample_rate = sample_rate
        self.buffer_size = buffer_size
        self.sensor = KLD2Sensor(sample_rate=sample_rate, simulation=simulation)

        # Data buffers
        self.time_buffer = deque(maxlen=buffer_size)
        self.voltage_buffer = deque(maxlen=buffer_size)

        # For swing detection
        self.swing_detected = False
        self.swing_threshold = 0.5  # Voltage threshold for swing detection
        self.max_swing_speed = 0.0

        # Setup plot
        self.setup_plot()

        print("=" * 60)
        print("🏌️  Simple KLD2 Golf Swing Monitor")
        print("=" * 60)
        print(f"Sample Rate: {sample_rate} Hz")
        print(f"Buffer Size: {buffer_size} samples ({buffer_size/sample_rate:.1f}s)")
        print(f"Mode: {'Simulation' if simulation else 'Live Sensor'}")
        print("\nMonitoring for golf swings...")
        print("Press Ctrl+C or close window to stop")
        print("=" * 60)

    def setup_plot(self):
        """Setup matplotlib figure and axes"""
        # Create figure with subplots
        self.fig, (self.ax1, self.ax2) = plt.subplots(2, 1, figsize=(12, 8))
        self.fig.suptitle('KLD2 Doppler Radar - Golf Swing Monitor', fontsize=16, fontweight='bold')

        # Time domain plot
        self.ax1.set_title('Sensor Signal (Time Domain)')
        self.ax1.set_xlabel('Time (s)')
        self.ax1.set_ylabel('Voltage (V)')
        self.ax1.set_ylim(0, 3.3)
        self.ax1.grid(True, alpha=0.3)
        self.line1, = self.ax1.plot([], [], 'b-', linewidth=1, label='Sensor Signal')
        self.threshold_line = self.ax1.axhline(y=self.swing_threshold + 1.65,
                                                color='r', linestyle='--',
                                                label='Swing Threshold')
        self.ax1.legend()

        # Frequency domain plot (FFT)
        self.ax2.set_title('Doppler Frequency Spectrum')
        self.ax2.set_xlabel('Frequency (Hz)')
        self.ax2.set_ylabel('Magnitude')
        self.ax2.set_xlim(0, self.sample_rate / 2)
        self.ax2.grid(True, alpha=0.3)
        self.line2, = self.ax2.plot([], [], 'g-', linewidth=1)

        # Status text
        self.status_text = self.fig.text(0.02, 0.02, '', fontsize=10,
                                         bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))

        plt.tight_layout()

    def detect_swing(self, voltage):
        """
        Detect golf swing from voltage pattern

        Args:
            voltage: Current voltage reading

        Returns:
            bool: True if swing detected
        """
        # Center voltage around 1.65V (half of 3.3V)
        deviation = abs(voltage - 1.65)

        if deviation > self.swing_threshold:
            if not self.swing_detected:
                self.swing_detected = True
                print(f"🏌️  SWING DETECTED! Signal: {voltage:.3f}V")
            self.max_swing_speed = max(self.max_swing_speed, deviation)
            return True
        elif self.swing_detected and deviation < self.swing_threshold * 0.5:
            # Swing ended
            print(f"✅ Swing complete. Max speed indicator: {self.max_swing_speed:.3f}V")
            self.swing_detected = False
            self.max_swing_speed = 0.0

        return False

    def update(self, frame):
        """
        Animation update function

        Args:
            frame: Frame number (unused)

        Returns:
            list: Artists to update
        """
        # Read new samples
        num_samples = 10  # Read 10 samples per frame
        samples = self.sensor.get_samples(num_samples)

        # Add to buffer
        current_time = time.time()
        for i, voltage in enumerate(samples):
            self.time_buffer.append(current_time + i / self.sample_rate)
            self.voltage_buffer.append(voltage)

            # Detect swings
            self.detect_swing(voltage)

        # Update time domain plot
        if len(self.time_buffer) > 1:
            times = np.array(self.time_buffer)
            times = times - times[0]  # Normalize to start at 0
            voltages = np.array(self.voltage_buffer)

            self.line1.set_data(times, voltages)
            self.ax1.set_xlim(0, max(times[-1], 2.0))

        # Update frequency domain plot (FFT)
        if len(self.voltage_buffer) >= 256:
            voltages = np.array(self.voltage_buffer)
            # Remove DC component
            voltages = voltages - np.mean(voltages)

            # Compute FFT
            n = len(voltages)
            freqs = np.fft.rfftfreq(n, 1/self.sample_rate)
            fft = np.abs(np.fft.rfft(voltages))

            # Apply window to reduce spectral leakage
            window = signal.windows.hann(n)
            fft_windowed = np.abs(np.fft.rfft(voltages * window))

            self.line2.set_data(freqs, fft_windowed)
            self.ax2.set_ylim(0, np.max(fft_windowed) * 1.1 if np.max(fft_windowed) > 0 else 1)

        # Update status text
        status = f"Samples: {len(self.voltage_buffer)} | "
        status += f"Current: {self.voltage_buffer[-1]:.3f}V | "
        status += f"Swing: {'ACTIVE 🏌️' if self.swing_detected else 'Idle'}"
        self.status_text.set_text(status)

        return self.line1, self.line2, self.status_text

    def run(self):
        """Start the monitoring loop"""
        self.sensor.start_stream()

        # Create animation
        anim = FuncAnimation(
            self.fig,
            self.update,
            interval=50,  # Update every 50ms (20 FPS)
            blit=False,
            cache_frame_data=False
        )

        # Show plot
        try:
            plt.show()
        except KeyboardInterrupt:
            print("\n\n⚠️ Stopped by user")
        finally:
            self.sensor.stop_stream()
            self.sensor.cleanup()

        print("\n✅ Monitoring stopped")


def main():
    """Main entry point"""
    import sys

    # Parse arguments
    simulation = '--sim' in sys.argv or '--simulation' in sys.argv
    sample_rate = 1000  # 1 kHz default

    # Check for sample rate argument
    for arg in sys.argv:
        if arg.startswith('--rate='):
            try:
                sample_rate = int(arg.split('=')[1])
            except ValueError:
                print(f"⚠️ Invalid sample rate: {arg}")

    # Check for buffer size argument
    buffer_size = 2000
    for arg in sys.argv:
        if arg.startswith('--buffer='):
            try:
                buffer_size = int(arg.split('=')[1])
            except ValueError:
                print(f"⚠️ Invalid buffer size: {arg}")

    # Create and run monitor
    monitor = SimpleKLD2Monitor(
        sample_rate=sample_rate,
        buffer_size=buffer_size,
        simulation=simulation
    )

    monitor.run()


if __name__ == '__main__':
    main()
