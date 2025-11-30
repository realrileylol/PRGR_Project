# Using GNU Radio Companion GUI for KLD2 Sensor Monitoring

This guide explains how to use the **GNU Radio Companion (GRC)** graphical interface to monitor your KLD2 sensor in real-time.

## 🎯 What is GNU Radio Companion?

GNU Radio Companion is a **visual programming tool** where you:
- Drag and drop signal processing blocks
- Connect them visually with your mouse
- Run the flowgraph and see live visualizations
- Adjust parameters in real-time

No coding required - it's all graphical!

---

## 📦 Installation

```bash
# Install GNU Radio Companion
sudo apt-get update
sudo apt-get install -y gnuradio

# Verify installation
gnuradio-companion --version
```

---

## 🚀 Method 1: Use the Pre-Built Flowgraph (Easiest)

### Step 1: Open GNU Radio Companion

```bash
cd /home/user/PRGR_Project
gnuradio-companion kld2_monitor.grc
```

This will open the GUI with a pre-built flowgraph for KLD2 monitoring.

### Step 2: Understanding the Flowgraph

You'll see blocks connected like this:

```
[Signal Source] ──┐
                  ├─→ [Add] ─→ [Throttle] ─→ [Low Pass Filter] ─┬─→ [Time Sink (GUI)]
[Noise Source] ───┘                                              ├─→ [Freq Sink (GUI)]
                                                                  └─→ [File Sink]
```

**Current blocks:**
- **Signal Source** - Simulates Doppler signal (temporary)
- **Noise Source** - Adds realistic noise
- **Add** - Combines signal and noise
- **Throttle** - Controls CPU usage
- **Low Pass Filter** - Removes high-frequency noise
- **Time Sink** - Time domain plot (GUI)
- **Freq Sink** - Frequency domain plot (GUI)
- **File Sink** - Records data to file

### Step 3: Run in Simulation Mode

1. Click the **Execute** button (▶ Play icon) or press **F6**
2. Two plot windows will appear:
   - Time domain plot (signal over time)
   - Frequency domain plot (FFT/Doppler)
3. You'll see a simulated Doppler signal
4. Click **Stop** button (■) or press **F7** to stop

### Step 4: Adjust Parameters While Running

You can modify parameters in real-time:
- **samp_rate** - Change sampling rate
- **Signal Source frequency** - Change Doppler frequency
- **Filter cutoff** - Adjust filtering

---

## 🔧 Method 2: Create Custom KLD2 Source Block

To connect your real KLD2 sensor, you need to replace the simulation with a custom block.

### Option A: Use Embedded Python Block (Recommended)

#### Step 1: Add Python Block

1. In GNU Radio Companion, search for **"Embedded Python Block"** in the block list
2. Drag it into your flowgraph
3. Delete the "Signal Source" and "Noise Source" blocks
4. Connect the Python block to the Add block

#### Step 2: Configure Python Block

Double-click the Python block and add this code:

```python
import numpy as np
from gnuradio import gr
import sys
sys.path.append('/home/user/PRGR_Project')
from kld2_sensor import KLD2Sensor

class KLD2SourceBlock(gr.sync_block):
    def __init__(self, sample_rate=10000):
        gr.sync_block.__init__(
            self,
            name="KLD2 Source",
            in_sig=None,
            out_sig=[np.float32]
        )
        self.sensor = KLD2Sensor(sample_rate=sample_rate, simulation=False)
        self.sensor.start_stream()

    def work(self, input_items, output_items):
        num_samples = len(output_items[0])
        samples = self.sensor.get_samples(num_samples)
        # Normalize to -1 to 1 range
        normalized = (samples - 1.65) / 1.65
        output_items[0][:] = normalized.astype(np.float32)
        return num_samples
```

#### Step 3: Set Block Parameters

- **Output Type**: `float`
- **Sample Rate**: `samp_rate` (use the variable)

### Option B: Use File Source (For Recorded Data)

If you want to replay recorded data:

1. First record some data:
   ```bash
   python3 gnuradio_kld2_monitor.py
   # Swing club, then stop
   # Data saved to /tmp/kld2_sensor_data.bin
   ```

2. In GRC, add **File Source** block:
   - **File**: `/tmp/kld2_sensor_data.bin`
   - **Output Type**: `float`
   - **Repeat**: `Yes` (to loop playback)

3. Connect File Source → Throttle → Low Pass Filter → Sinks

---

## 🎨 Method 3: Build Flowgraph from Scratch

### Step 1: Create New Flowgraph

1. Open GNU Radio Companion
2. Click **File → New** (Ctrl+N)
3. Save as `my_kld2_monitor.grc`

### Step 2: Set Variables

Add these variable blocks:

```
Variable ID: samp_rate
Value: 10000

Variable ID: fft_size
Value: 1024
```

### Step 3: Add Source Block

For now, use **Signal Source** for testing:
- **Sample Rate**: `samp_rate`
- **Waveform**: `Cosine`
- **Frequency**: `100` (simulates 100 Hz Doppler)
- **Amplitude**: `0.5`
- **Output Type**: `float`

### Step 4: Add Throttle Block

Search for **Throttle** and add it:
- **Type**: `float`
- **Sample Rate**: `samp_rate`

Connect: Signal Source → Throttle

### Step 5: Add Low Pass Filter

Search for **Low Pass Filter**:
- **Sample Rate**: `samp_rate`
- **Cutoff Freq**: `500` (Hz)
- **Transition Width**: `100`
- **Window**: `Hamming`
- **Type**: `Float→Float (Decimating)`

Connect: Throttle → Low Pass Filter

### Step 6: Add Time Sink (Scope)

Search for **QT GUI Time Sink**:
- **Type**: `float`
- **Number of Points**: `2048`
- **Sample Rate**: `samp_rate`
- **Name**: `"KLD2 Time Domain"`
- **Y Axis Label**: `"Voltage"`
- **Y min**: `-1`
- **Y max**: `1`

Connect: Low Pass Filter → Time Sink

### Step 7: Add Frequency Sink (FFT)

Search for **QT GUI Frequency Sink**:
- **Type**: `float`
- **FFT Size**: `fft_size`
- **Sample Rate**: `samp_rate`
- **Name**: `"KLD2 Frequency Domain"`
- **Y min**: `-140`
- **Y max**: `10`

Connect: Low Pass Filter → Freq Sink

### Step 8: Optional - Add File Sink

Search for **File Sink**:
- **File**: `/tmp/kld2_data.bin`
- **Type**: `float`

Connect: Low Pass Filter → File Sink

### Step 9: Run It!

Click **Execute** (▶) or press **F6**

---

## 🎛️ Real-Time Controls and Sliders

You can add GUI controls to adjust parameters while running!

### Add a Slider for Frequency

1. Search for **QT GUI Range**
2. Add to flowgraph
3. Configure:
   - **ID**: `doppler_freq`
   - **Label**: `"Doppler Frequency"`
   - **Default**: `100`
   - **Start**: `0`
   - **Stop**: `500`
   - **Step**: `10`
   - **Widget**: `Counter Slider`

4. Update Signal Source:
   - **Frequency**: `doppler_freq` (use the variable)

Now you can adjust the frequency with a slider while the flowgraph runs!

### Add Sliders for Filter

Similarly, add sliders for:
- Filter cutoff frequency
- Sample rate (requires restart)
- Signal amplitude

---

## 🔍 Analyzing Your Golf Swings

### What to Look For

#### Time Domain Plot:
```
Resting: ════════════ (flat line at ~0V)

Swing:   ╱╲╱╲╱╲╱╲╱╲╱╲ (oscillating)

Fast:    ╱╲╱╲╱╲╱╲╱╲╱╲ (high frequency, amplitude)
```

#### Frequency Domain Plot:
```
No motion:     |          (spike at DC/0 Hz)
               |____________________

Slow motion:   |  ▄       (low frequency peak)
               |_/█\__________________

Fast swing:    |      ▄   (high frequency peak)
               |_____/█\______________
```

### Measuring Club Speed

The peak in the frequency plot tells you the Doppler shift:

**For 24 GHz radar:**
```
Doppler Freq = (2 × Radar Freq × Speed) / Speed_of_Light

Speed (m/s) = (Doppler Freq × 3×10^8) / (2 × 24×10^9)
            = Doppler Freq × 6.25
```

**Quick conversion:**
- 100 Hz → 0.625 m/s → 2.25 km/h
- 1 kHz → 6.25 m/s → 22.5 km/h
- 10 kHz → 62.5 m/s → 225 km/h (Pro level!)

---

## 💡 Tips and Tricks

### Zoom and Pan
- **Mouse wheel**: Zoom in/out
- **Right-click drag**: Pan
- **Auto-scale**: Click the plot toolbar icons

### Pause Display
- Click **Pause** button on plot to freeze display
- Useful for examining a specific swing

### Adjust Update Rate
In Time Sink and Freq Sink blocks:
- **Update Period**: `0.10` = 10 FPS
- Lower = smoother but more CPU
- Higher = less CPU but choppier

### Trigger on Swings
In Time Sink block:
- **Trigger Mode**: `Normal`
- **Trigger Slope**: `Positive`
- **Trigger Level**: `0.3` (adjust to your signal)
- **Trigger Channel**: `0`

This will only show the plot when signal exceeds threshold!

### Multiple Channels
You can monitor multiple sensors or compare before/after filtering:
- Set **Number of Inputs**: `2` on Time Sink
- Connect both filtered and unfiltered signals
- Each will show in different colors

---

## 🔧 Troubleshooting GNU Radio Companion

### Error: "ImportError: No module named gnuradio"

```bash
sudo apt-get install -y python3-gnuradio
```

### Error: "Qt platform plugin error"

```bash
export QT_QPA_PLATFORM=xcb
gnuradio-companion
```

### Error: "Block key not found"

- Update GNU Radio: `sudo apt-get update && sudo apt-get upgrade gnuradio`
- Some blocks may have different names in different versions

### Flowgraph Won't Run

1. Check all blocks are connected (no red warnings)
2. Check all variables are defined
3. Look at console output for error messages
4. Try **Tools → Reload Blocks** (Ctrl+R)

### GUI Windows Don't Appear

- Check **Generate Options** in Options block is `QT GUI`
- Not `No GUI` or `WX GUI`

### Plots Are Empty

1. Check source is producing data
2. Verify sample rate is reasonable
3. Check Y-axis scaling (auto-scale first)

---

## 📚 Advanced: Creating Custom OOT Module

For a fully integrated KLD2 block (Out-of-Tree module):

```bash
# Install development tools
sudo apt-get install -y cmake swig doxygen

# Create OOT module
cd ~
gr_modtool newmod kld2

# Add source block
cd gr-kld2
gr_modtool add -t sync kld2_source

# Edit the generated files with sensor code
# Then build and install
mkdir build && cd build
cmake ..
make
sudo make install
sudo ldconfig
```

Then your KLD2 block will appear in GRC block list under its own category!

---

## 🎓 Learning Resources

### GNU Radio Companion Tutorials
- [Official Tutorials](https://wiki.gnuradio.org/index.php/Tutorials)
- [GRC Basics](https://wiki.gnuradio.org/index.php/Guided_Tutorial_GRC)
- [Understanding Flowgraphs](https://wiki.gnuradio.org/index.php/Flowgraph_Python_Code)

### Example Flowgraphs
```bash
# GRC examples are usually here:
ls /usr/share/gnuradio/examples/
```

### Video Tutorials
- Search YouTube for "GNU Radio Companion tutorial"
- Look for RF and SDR beginner guides

---

## 📋 Quick Reference

### Keyboard Shortcuts
- **F6**: Execute flowgraph
- **F7**: Stop flowgraph
- **Ctrl+N**: New flowgraph
- **Ctrl+S**: Save
- **Ctrl+R**: Reload blocks
- **Ctrl+F**: Find blocks
- **Delete**: Remove selected block

### Common Block Categories
- **Sources**: Signal generators, file inputs, hardware
- **Sinks**: Displays, file outputs, hardware
- **Filters**: Low pass, high pass, band pass
- **Math**: Add, multiply, etc.
- **QT GUI**: Visual displays and controls
- **Stream**: Throttle, null sink, etc.

### File Locations
- **Flowgraphs**: Save as `.grc` files
- **Generated Python**: Same name as `.grc` but `.py`
- **Example flowgraphs**: `/usr/share/gnuradio/examples/`

---

## 🚀 Next Steps

1. **Open the pre-built flowgraph**: `gnuradio-companion kld2_monitor.grc`
2. **Run it in simulation mode** (click Execute)
3. **Understand each block** (double-click to see properties)
4. **Modify parameters** (change frequencies, filters)
5. **Add sliders** (for real-time control)
6. **Replace simulation** with real sensor block
7. **Experiment!** Try different signal processing

---

**Happy signal processing! 📡🏌️**
