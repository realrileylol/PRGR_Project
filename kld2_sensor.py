"""
KLD2 Doppler Radar Sensor Reader for Raspberry Pi
Reads sensor data via GPIO and provides it as a signal source
"""

import numpy as np
import time
try:
    import RPi.GPIO as GPIO
    import spidev
    HAS_GPIO = True
except ImportError:
    HAS_GPIO = False
    print("⚠️ RPi.GPIO not available - running in simulation mode")

class KLD2Sensor:
    """Interface for KLD2 Doppler radar sensor via SPI/ADC"""

    def __init__(self, spi_channel=0, spi_device=0, sample_rate=1000, simulation=False):
        """
        Initialize KLD2 sensor reader

        Args:
            spi_channel: SPI channel (usually 0)
            spi_device: SPI device (0 or 1, depends on CE pin)
            sample_rate: Samples per second
            simulation: If True, generate simulated data
        """
        self.sample_rate = sample_rate
        self.simulation = simulation or not HAS_GPIO
        self.running = False

        if not self.simulation:
            # Initialize SPI for ADC (MCP3008 or similar)
            self.spi = spidev.SpiDev()
            self.spi.open(spi_channel, spi_device)
            self.spi.max_speed_hz = 1000000  # 1MHz
            print(f"✅ KLD2 sensor initialized on SPI{spi_channel}.{spi_device}")
        else:
            self.spi = None
            print("⚠️ Running in simulation mode - generating synthetic swing data")

    def read_adc(self, channel=0):
        """
        Read analog value from ADC channel (0-7 for MCP3008)

        Args:
            channel: ADC channel (0-7)

        Returns:
            int: 10-bit ADC value (0-1023)
        """
        if self.simulation:
            # Generate simulated Doppler signal
            # Simulate a golf swing with increasing then decreasing frequency
            t = time.time()
            # Create a swing pattern: slow -> fast -> slow
            swing_freq = 50 * np.sin(2 * np.pi * 0.5 * t)  # 0.5 Hz swing rate
            signal = np.sin(2 * np.pi * swing_freq * t)
            # Add noise
            signal += 0.1 * np.random.randn()
            # Scale to 10-bit range (0-1023)
            return int(512 + 400 * signal)

        # MCP3008 command structure
        # Start bit, single-ended mode, channel select
        adc = self.spi.xfer2([1, (8 + channel) << 4, 0])
        data = ((adc[1] & 3) << 8) + adc[2]
        return data

    def read_voltage(self, channel=0, vref=3.3):
        """
        Read voltage from ADC channel

        Args:
            channel: ADC channel
            vref: Reference voltage (usually 3.3V)

        Returns:
            float: Voltage (0 to vref)
        """
        adc_value = self.read_adc(channel)
        voltage = (adc_value * vref) / 1023.0
        return voltage

    def start_stream(self):
        """Start continuous data streaming"""
        self.running = True
        print(f"📡 Starting KLD2 sensor stream at {self.sample_rate} Hz")

    def stop_stream(self):
        """Stop data streaming"""
        self.running = False
        print("🛑 Stopping KLD2 sensor stream")

    def get_samples(self, num_samples, channel=0):
        """
        Get a batch of samples

        Args:
            num_samples: Number of samples to collect
            channel: ADC channel to read from

        Returns:
            np.array: Array of voltage samples
        """
        samples = []
        sample_interval = 1.0 / self.sample_rate

        for _ in range(num_samples):
            start_time = time.time()
            voltage = self.read_voltage(channel)
            samples.append(voltage)

            # Maintain sample rate
            elapsed = time.time() - start_time
            sleep_time = sample_interval - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)

        return np.array(samples)

    def cleanup(self):
        """Cleanup GPIO and SPI resources"""
        if self.spi:
            self.spi.close()
        if HAS_GPIO:
            GPIO.cleanup()
        print("✅ KLD2 sensor cleanup complete")

    def __del__(self):
        """Destructor"""
        self.cleanup()


# GNU Radio compatible source block
class KLD2Source:
    """GNU Radio compatible source for KLD2 sensor"""

    def __init__(self, sample_rate=1000, simulation=False):
        self.sensor = KLD2Sensor(sample_rate=sample_rate, simulation=simulation)
        self.sample_rate = sample_rate

    def work(self, output_items):
        """
        GNU Radio work function

        Args:
            output_items: Output buffer to fill

        Returns:
            int: Number of items produced
        """
        num_samples = len(output_items[0])
        samples = self.sensor.get_samples(num_samples)
        output_items[0][:] = samples
        return num_samples


if __name__ == "__main__":
    # Test the sensor
    print("🏌️ KLD2 Golf Swing Sensor Test")
    print("=" * 50)

    sensor = KLD2Sensor(simulation=True, sample_rate=1000)
    sensor.start_stream()

    try:
        print("\n📊 Reading 10 samples...")
        for i in range(10):
            voltage = sensor.read_voltage()
            adc = sensor.read_adc()
            print(f"Sample {i+1}: ADC={adc:4d}, Voltage={voltage:.3f}V")
            time.sleep(0.1)

        print("\n✅ Sensor test complete!")
        print("\nTo use with GNU Radio:")
        print("  python3 gnuradio_kld2_monitor.py")

    except KeyboardInterrupt:
        print("\n\n⚠️ Test interrupted by user")
    finally:
        sensor.stop_stream()
        sensor.cleanup()
