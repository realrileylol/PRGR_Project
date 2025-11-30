#!/usr/bin/env python3
"""
GNU Radio Flowgraph for KLD2 Doppler Radar Sensor
Live visualization of golf swing data from KLD2 sensor
"""

import sys
import numpy as np
from gnuradio import gr, blocks, analog, fft, filter as gr_filter
from gnuradio.fft import window
try:
    from gnuradio import qtgui
    from PyQt5 import Qt
    HAS_QT = True
except ImportError:
    HAS_QT = False
    print("⚠️ Qt GUI not available, using WX GUI or headless mode")

from kld2_sensor import KLD2Sensor


class KLD2SourceBlock(gr.sync_block):
    """
    GNU Radio source block for KLD2 sensor data
    """

    def __init__(self, sample_rate=10000, simulation=False, adc_channel=0):
        """
        Initialize KLD2 source block

        Args:
            sample_rate: Sampling rate in Hz
            simulation: Use simulated data
            adc_channel: ADC channel to read from (0-7)
        """
        gr.sync_block.__init__(
            self,
            name="KLD2 Sensor Source",
            in_sig=None,  # No input
            out_sig=[np.float32]  # Output float samples
        )

        self.sensor = KLD2Sensor(sample_rate=sample_rate, simulation=simulation)
        self.sample_rate = sample_rate
        self.adc_channel = adc_channel
        self.sensor.start_stream()

    def work(self, input_items, output_items):
        """
        Generate output samples from sensor

        Args:
            input_items: Unused (no inputs)
            output_items: Output buffer to fill

        Returns:
            int: Number of samples produced
        """
        num_samples = len(output_items[0])
        samples = self.sensor.get_samples(num_samples, channel=self.adc_channel)

        # Normalize to -1 to 1 range for signal processing
        # Assuming 3.3V reference, 1.65V is center
        normalized = (samples - 1.65) / 1.65

        output_items[0][:] = normalized.astype(np.float32)
        return num_samples

    def stop(self):
        """Stop the sensor stream"""
        self.sensor.stop_stream()
        return super().stop()


class KLD2MonitorFlowgraph(gr.top_block):
    """
    GNU Radio flowgraph for monitoring KLD2 sensor
    """

    def __init__(self, sample_rate=10000, fft_size=1024, simulation=True):
        """
        Initialize the flowgraph

        Args:
            sample_rate: Sampling rate in Hz
            fft_size: FFT size for frequency analysis
            simulation: Use simulated data
        """
        gr.top_block.__init__(self, "KLD2 Golf Swing Monitor")

        self.sample_rate = sample_rate
        self.fft_size = fft_size

        ##################################################
        # Blocks
        ##################################################

        # KLD2 Sensor Source
        self.kld2_source = KLD2SourceBlock(
            sample_rate=sample_rate,
            simulation=simulation
        )

        # Low-pass filter to remove high-frequency noise
        # Golf swing frequencies are typically 0-200 Hz
        self.lpf = gr_filter.fir_filter_fff(
            1,  # Decimation
            gr_filter.firdes.low_pass(
                1,  # Gain
                sample_rate,
                500,  # Cutoff frequency (Hz)
                100,  # Transition width (Hz)
                window.WIN_HAMMING
            )
        )

        # FFT for frequency analysis
        self.fft_block = fft.fft_vfc(fft_size, True, window.blackmanharris(fft_size))

        # Stream to vector for FFT
        self.stream_to_vector = blocks.stream_to_vector(
            gr.sizeof_float,
            fft_size
        )

        # Complex to magnitude for FFT display
        self.complex_to_mag = blocks.complex_to_mag(fft_size)

        # Throttle to limit CPU usage (only needed in simulation)
        if simulation:
            self.throttle = blocks.throttle(gr.sizeof_float, sample_rate)

        # File sink for recording data
        self.file_sink = blocks.file_sink(
            gr.sizeof_float,
            '/tmp/kld2_sensor_data.bin',
            False
        )
        self.file_sink.set_unbuffered(False)

        ##################################################
        # GUI Sinks (if Qt is available)
        ##################################################

        if HAS_QT:
            # Time domain plot
            self.time_sink = qtgui.time_sink_f(
                1024,  # Number of points
                sample_rate,  # Sample rate
                "KLD2 Sensor - Time Domain",  # Title
                1  # Number of inputs
            )
            self.time_sink.set_update_time(0.10)
            self.time_sink.set_y_axis(-1, 1)
            self.time_sink.set_y_label('Amplitude', 'V')
            self.time_sink.enable_tags(-1, True)
            self.time_sink.set_trigger_mode(qtgui.TRIG_MODE_FREE, qtgui.TRIG_SLOPE_POS, 0.0, 0, 0, "")
            labels = ['Sensor Signal', '', '', '', '', '', '', '', '', '']
            widths = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
            colors = ['blue', 'red', 'green', 'black', 'cyan', 'magenta', 'yellow', 'dark red', 'dark green', 'dark blue']
            styles = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
            markers = [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
            alphas = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
            for i in range(1):
                self.time_sink.set_line_label(i, labels[i])
                self.time_sink.set_line_width(i, widths[i])
                self.time_sink.set_line_color(i, colors[i])
                self.time_sink.set_line_style(i, styles[i])
                self.time_sink.set_line_marker(i, markers[i])
                self.time_sink.set_line_alpha(i, alphas[i])

            # Frequency domain plot (FFT)
            self.freq_sink = qtgui.freq_sink_f(
                fft_size,
                window.WIN_BLACKMAN_hARRIS,
                0,  # Center frequency
                sample_rate,
                "KLD2 Sensor - Frequency Domain (Doppler)",
                1
            )
            self.freq_sink.set_update_time(0.10)
            self.freq_sink.set_y_axis(-140, 10)
            self.freq_sink.set_y_label('Relative Gain', 'dB')
            self.freq_sink.enable_autoscale(False)
            self.freq_sink.enable_grid(True)

        ##################################################
        # Connections
        ##################################################

        if simulation:
            self.connect((self.kld2_source, 0), (self.throttle, 0))
            self.connect((self.throttle, 0), (self.lpf, 0))
        else:
            self.connect((self.kld2_source, 0), (self.lpf, 0))

        # Connect to file sink for recording
        self.connect((self.lpf, 0), (self.file_sink, 0))

        if HAS_QT:
            # Connect to time domain display
            self.connect((self.lpf, 0), (self.time_sink, 0))

            # Connect to frequency domain display
            self.connect((self.lpf, 0), (self.freq_sink, 0))

        print("=" * 60)
        print("🏌️  KLD2 Golf Swing Doppler Radar Monitor")
        print("=" * 60)
        print(f"Sample Rate: {sample_rate} Hz")
        print(f"FFT Size: {fft_size}")
        print(f"Mode: {'Simulation' if simulation else 'Live Sensor'}")
        print(f"Recording to: /tmp/kld2_sensor_data.bin")
        print("\nPress Ctrl+C to stop")
        print("=" * 60)


def main():
    """Main entry point"""

    # Parse arguments
    simulation = '--sim' in sys.argv or '--simulation' in sys.argv
    sample_rate = 10000  # 10 kHz default

    # Check for sample rate argument
    for arg in sys.argv:
        if arg.startswith('--rate='):
            try:
                sample_rate = int(arg.split('=')[1])
            except ValueError:
                print(f"⚠️ Invalid sample rate: {arg}")

    if not HAS_QT:
        print("=" * 60)
        print("⚠️  Qt GUI not available!")
        print("=" * 60)
        print("\nTo install Qt support:")
        print("  sudo apt-get install -y gnuradio python3-pyqt5")
        print("  pip3 install --break-system-packages pyqtgraph")
        print("\nFalling back to headless mode (data will be recorded to file)")
        print("=" * 60)

    # Create flowgraph
    tb = KLD2MonitorFlowgraph(
        sample_rate=sample_rate,
        fft_size=1024,
        simulation=simulation
    )

    # Start flowgraph
    tb.start()

    if HAS_QT:
        # Start Qt application
        qapp = Qt.QApplication(sys.argv)
        tb.show()
        qapp.exec_()
    else:
        # Run headless
        try:
            print("\n📡 Recording sensor data...")
            print("Press Ctrl+C to stop\n")
            tb.wait()
        except KeyboardInterrupt:
            print("\n\n⚠️ Stopped by user")

    # Stop flowgraph
    tb.stop()
    tb.wait()

    print("\n✅ Monitoring stopped")
    print(f"📁 Data saved to: /tmp/kld2_sensor_data.bin")


if __name__ == '__main__':
    main()
