# PRGR Launch Monitor - Optics & Capture Guide

## What This Document Covers
This is a plain-language explanation of the optical and capture concepts that determine whether a camera-based golf launch monitor can accurately measure ball spin. Every section builds on the previous one. No prior knowledge required.

---

## 1. Ball Pixel Diameter — Why Size on the Sensor Matters

### The Concept
When a camera looks at a golf ball from several feet away, the ball only occupies a small portion of the image. "Ball pixel diameter" is how many pixels across the ball appears in the camera's frame.

Think of it like a TV screen: if the golf ball only covers a 10x10 pixel area, you can barely tell it's round. If it covers 75x75 pixels, you can see details on its surface — logos, dots, dimple patterns. Those surface details are what the software uses to calculate spin.

### Why It Matters for Spin
To measure spin, the software needs to track markers (dots, logos, lines) on the ball across multiple frames. If the ball is too small in the image, those markers are just 1-2 blurry pixels and the software can't distinguish them from noise.

**Rule of thumb for fiducial (dot/marker) tracking:**

| Ball Diameter (pixels) | Marker Resolution | Spin Tracking Viability |
|---|---|---|
| < 30 px | Markers are ~2 px, unresolvable | Not viable |
| 40-50 px | Markers are ~4-5 px, minimum | Marginal — works in ideal conditions |
| 60-80 px | Markers are ~6-7 px, clear | Good — reliable tracking |
| 80-120 px | Markers are ~8-10 px, detailed | Excellent — diminishing returns above this |

### What Controls Ball Pixel Diameter
Three things determine how big the ball appears on the sensor:

1. **Focal length of the lens** — Longer focal length = more zoom = bigger ball image. A 12mm lens shows the ball ~1.5x bigger than an 8mm lens.
2. **Distance from the camera to the ball** — Closer = bigger. Moving from 8ft to 5ft increases ball size by ~60%.
3. **Pixel pitch of the sensor** — Smaller pixels = more pixels across the same image. The OV9281's 3.0 micron pixels are standard for this class.

### The Formula (Pinhole Camera Model)
```
ball_pixels = (ball_diameter_mm x focal_length_mm) / (distance_mm x pixel_pitch_mm)
```

**Golf ball = 42.67mm, OV9281 pixel pitch = 0.003mm**

| Lens | Distance | Ball Diameter (px) |
|---|---|---|
| 12mm | 8 ft (2438mm) | ~70 px |
| 12mm | 7 ft (2133mm) | ~80 px |
| 12mm | 5 ft (1524mm) | ~112 px |
| 8mm | 8 ft (2438mm) | ~47 px |
| 8mm | 7 ft (2133mm) | ~53 px |
| 8mm | 5 ft (1524mm) | ~75 px |
| 2.8mm | 7 ft (2133mm) | ~19 px |
| 2.8mm | 5 ft (1524mm) | ~26 px |

### The Tradeoff
A longer lens gives you more pixels on the ball, but it also narrows the camera's field of view. At some point, the view is so narrow that any slight misalignment means the ball isn't even in the frame. This is why lens choice depends on distance — what works at 8ft may be too tight at 5ft.

---

## 2. Frame Rate (FPS) — Catching the Ball in Flight

### The Concept
Frames Per Second (FPS) is how many individual pictures the camera takes each second. At 30 FPS (a standard video camera), each frame is 33 milliseconds apart. At 240 FPS, each frame is only 4.17 milliseconds apart.

### Why It Matters
A golf ball hit by a 7-iron travels around 130 mph (58 meters per second). At that speed:

| Frame Rate | Time Between Frames | Ball Movement Per Frame |
|---|---|---|
| 30 FPS | 33.3 ms | ~77 inches (6.4 ft) |
| 120 FPS | 8.3 ms | ~19 inches |
| 180 FPS | 5.6 ms | ~13 inches |
| **240 FPS** | **4.17 ms** | **~9.6 inches** |
| 320 FPS | 3.1 ms | ~7.2 inches |

Spin detection algorithms need at least 2-3 consecutive frames where the ball is visible and the markers are trackable. If your camera's field of view is 14 inches tall and the ball moves 13 inches per frame (180 FPS), you might only get 1-2 usable frames. At 240 FPS with 9.6 inches per frame, you're more likely to get 2-3 frames — enough for reliable spin calculation.

### The 240 FPS Target
The Rapsodo MLM2 Pro uses 240 FPS for its Impact Vision camera. This is the benchmark. Higher FPS gives more frames in the critical window, but the sensor has to sacrifice resolution to read data fast enough (see Section 5 on ROI cropping).

### FPS Does NOT Control Blur
A common misconception: higher FPS does not automatically mean sharper images. FPS controls how often you take a picture. Shutter speed (exposure time) controls how long each picture's "window" stays open. You can shoot 240 FPS with a slow shutter and get 240 blurry frames per second. FPS and exposure must be configured independently.

---

## 3. Exposure Time (Shutter Speed) — Freezing the Ball

### The Concept
Exposure time is how long the camera sensor collects light for each frame. A longer exposure lets in more light (brighter image) but anything moving during that time gets smeared across the sensor, creating motion blur. A shorter exposure freezes motion but the image is darker.

### The Motion Blur Math
At 160 mph (71.5 mm per millisecond), a golf ball moves:

| Exposure Time | Ball Movement During Exposure | Result |
|---|---|---|
| 1,000 us (1 ms) | 71.5 mm (2.8") | Completely smeared — ball is an oval streak |
| 500 us | 35.7 mm | Heavy blur — markers unreadable |
| 300 us | 21.5 mm | Moderate blur — club data OK, spin marginal |
| **200 us** | **14.3 mm** | **Manageable — starting point for spin** |
| **100 us** | **7.1 mm** | **Good — standard prosumer target for spin** |
| 50 us | 3.6 mm | Excellent — but needs intense light |
| 36 us | 2.6 mm | OV9281 hardware minimum — needs extreme light |

("us" = microseconds = millionths of a second)

### The Target Range: 100-200 Microseconds
The Rapsodo MLM2 Pro does not publish its exact exposure time, but based on its behavior (works well in bright conditions, struggles in dark rooms), it operates somewhere in the 100-200 microsecond range. This produces 7-14mm of motion blur — enough that the ball isn't perfectly frozen, but the markers are still distinct enough for algorithms to track.

### The Light Problem
At 100 microseconds, the sensor is only open for 1/10,000th of a second. Very little light reaches the sensor. The image will be dark unless:
- The environment is brightly lit (outdoor sunlight or strong indoor floods)
- The sensor's electronic gain (amplification) is increased — but too much gain creates noise
- The lens has a wide aperture (low F-number) to funnel more light in

This is why the MLM2 Pro struggles in dark rooms — it relies entirely on ambient light, and at 100-200 microsecond exposures, a dim room simply doesn't provide enough photons.

### Current PRGR Status
The PRGR system defaults to **4,000-8,000 microsecond** exposure — 20-80x too slow for spin tracking. At 4,000 microseconds and 160 mph, the ball smears 286mm (11 inches). This must be reduced to 100-200 microseconds for spin-viable capture.

---

## 4. Aperture (F-Number) — The Lens Light Gate

### The Concept
The aperture is the physical opening inside the lens that controls how much light passes through to the sensor. It's measured as an F-number (F-stop). Lower F-number = wider opening = more light.

### Why F1.2 Matters
The relationship is exponential, not linear:

| Aperture | Relative Light (vs F1.2) |
|---|---|
| **F1.2** | **100%** (maximum for these lenses) |
| F1.4 | 73% |
| F2.0 | 36% |
| F2.8 | 18% |
| F4.0 | 9% |

An F2.8 lens lets in only 18% of the light that an F1.2 lens does. When you're already fighting for photons at 100 microsecond exposures, that difference is the gap between a usable image and a black frame.

### PRGR Lens Selection
Both the 12mm and 8mm lenses for the impact camera are F1.2 — the fastest commonly available aperture for M12 lenses. This is not optional for spin detection with ambient light at short exposures. An F2.0 or slower lens would require either longer exposure (more blur) or higher gain (more noise), both of which degrade spin tracking.

---

## 5. Resolution and ROI Cropping — Trading Pixels for Speed

### The Concept
A camera sensor has a fixed maximum data throughput — it can only push so many pixels per second through its interface. The OV9281 on a Raspberry Pi uses a 2-lane MIPI CSI connection.

To increase frame rate, you must decrease the number of pixels read per frame. This is done through **Region of Interest (ROI) cropping** — telling the sensor to only read out a portion of its full pixel array.

### OV9281 Resolution vs Frame Rate

| Resolution | Total Pixels | Max FPS | Use Case |
|---|---|---|---|
| 1280 x 800 | 1,024,000 | 120 | Full sensor — maximum detail, half the target FPS |
| 1280 x 720 | 921,600 | 120 | HD crop — same bandwidth ceiling |
| 640 x 480 | 307,200 | 180-210 | VGA — good balance, current PRGR preview mode |
| **640 x 400** | **256,000** | **240-260** | **Target mode — matches MLM2 Pro frame rate** |
| 640 x 360 | 230,400 | ~280-320 | Slightly faster, marginal pixel loss |
| 320 x 240 | 76,800 | 420+ | Too low resolution for marker tracking |

### How Cropping Affects Field of View
When the sensor crops to a smaller region, there are two possible behaviors depending on the sensor mode:

**Center Crop (Windowing):**
The sensor only reads the center pixels at full native resolution. The field of view shrinks proportionally (like zooming in), but each pixel retains its full 3.0 micron detail. Ball pixel diameter stays the same as full resolution.

**Subsampling (Binning):**
The sensor reads the full chip but skips every other pixel (2x2 binning). The field of view stays the same, but effective pixel pitch doubles to 6.0 microns. Ball pixel diameter halves compared to full resolution.

**How to tell which your sensor is doing:**
Point the camera at a scene. Switch between 1280x800 and 640x400. If the view zooms in noticeably, it's center cropping. If the view stays the same but looks lower resolution, it's subsampling.

### Recommended Mode for Spin Detection
**640 x 400 @ 240 FPS** — This is the mode that achieves parity with the MLM2 Pro's frame rate while maintaining enough resolution for fiducial marker tracking at appropriate distances.

---

## 6. IR-Pass Filters and Day/Night Lenses — Seeing Invisible Light

### The Concept
Light exists on a spectrum. Human eyes see "visible light" (roughly 400-700 nanometer wavelengths). Beyond 700nm is "near-infrared" (NIR) — invisible to humans but perfectly real electromagnetic radiation that camera sensors can detect.

### How Standard Cameras Handle IR
Most consumer cameras (phones, webcams, GoPros) have an **IR-cut filter** — a thin piece of glass glued to the sensor that blocks all infrared light. This is done because IR light would corrupt color accuracy in photos and video. Without the filter, a green lawn would look washed out and reddish.

### Why a Monochrome Sensor is Different
The OV9281 is a monochrome (black and white) sensor. It has no color to corrupt. It also ships without a Bayer color filter array, meaning every pixel receives 100% of incoming light — visible AND near-infrared. This gives it roughly 3x the light sensitivity of an equivalent color sensor.

### What "IR Correction" / "Day/Night" Means on a Lens
A standard lens is optically designed so that visible light focuses sharply on the sensor. But infrared light has a different wavelength and bends differently through glass. On a regular lens, IR light focuses slightly in front of or behind the visible focal plane, producing a blurry haze.

An **IR-corrected (Day/Night)** lens is designed so that both visible AND near-infrared light focus on the same plane. This means:
- During the day: the lens works normally with visible light
- In low light: the sensor can use both visible AND infrared light simultaneously, with everything in focus
- With IR illumination: if you add invisible IR LED lights, the camera sees them as bright illumination while humans see nothing

### Why This Matters for PRGR
The OV9281 sensor is naturally sensitive to NIR light (850-940nm range). The IR-corrected lenses (both the 12mm and 8mm F1.2) allow the sensor to exploit this sensitivity without focus degradation. In practical terms:
- Outdoors: sunlight contains significant NIR — the sensor captures more total light than a color camera would
- Indoors: the sensor benefits from any incidental NIR in room lighting
- The sensor gets more usable photons per frame, supporting shorter exposure times

### PRGR Lens Status
Both the 12mm F1.2 and 8mm F1.2 impact camera lenses are IR-corrected day/night lenses. No additional filter hardware is needed.

---

## 7. Global Shutter vs Rolling Shutter — Why This is Non-Negotiable

### The Concept
The "shutter" mechanism determines HOW the sensor reads its pixels during an exposure.

**Rolling Shutter:** Reads the sensor row by row, top to bottom. Each row is exposed at a slightly different moment in time. On a 1280x800 sensor, the top row might be captured 1-2 milliseconds before the bottom row.

**Global Shutter:** Every pixel on the entire sensor is exposed at the exact same instant. The entire frame represents a single, precise moment in time.

### Why Rolling Shutter Fails for Golf
A golf ball at 160 mph moves ~71mm per millisecond. If the sensor takes 1.5ms to read from top to bottom (rolling shutter), the ball has physically moved ~107mm between the first row and the last row. The result:
- A perfectly round golf ball appears as a stretched, diagonal ellipse
- Straight lines on the ball (alignment marks, logos) appear curved or skewed
- The geometric distortion makes it mathematically impossible to calculate rotation accurately

### Why Global Shutter Works
With global shutter, the entire sensor captures at one instant. The ball's shape, the position of every marker, and the geometric relationships are all frozen perfectly. This is the only architecture that allows accurate spin measurement from sequential frames.

### PRGR Status
The OV9281 is a true global shutter sensor (OmniPixel3-GS technology). This requirement is already met. Never substitute a rolling shutter camera for the impact camera, regardless of how good its other specs may be.

---

## 8. Gain (Electronic Amplification) — Turning Up the Volume on Light

### The Concept
When the exposure time is very short (100-200 microseconds), very few photons reach each pixel. The electrical signal generated is extremely faint. "Gain" is electronic amplification — it multiplies the faint signal to produce a visible image. Think of it like turning up the volume on a quiet audio recording.

### The Problem with Gain
Amplification doesn't just boost the signal — it equally boosts the noise. Every sensor has baseline electronic noise (random fluctuations in voltage). At low gain, this noise is invisible. At high gain, it manifests as "salt and pepper" speckles — random bright and dark pixels scattered across the image.

This noise is destructive for spin detection because:
- Edge detection algorithms (Canny, Hough) interpret noise speckles as edges
- Blob detectors may confuse noise clusters with fiducial markers
- The software generates false positives — tracking random noise instead of actual ball rotation

### The Gain Sweet Spot
The goal is to use as little gain as possible while maintaining a bright enough image. The ball surface should reach approximately 80% luminance on the sensor without clipping (overexposing) the highlights. Overexposed highlights wash out the contrast between the white ball surface and the dark fiducial dots, making them invisible.

| Gain Level | Typical Use | Noise Impact |
|---|---|---|
| 1.0x - 2.0x | Bright outdoor sunlight | Minimal — ideal |
| 4.0x - 6.0x | Overcast / well-lit indoor | Moderate — acceptable |
| 8.0x - 12.0x | Indoor with supplemental lighting | Noticeable — workable with good algorithms |
| 16.0x+ | Dim indoor | Heavy — degrades marker detection significantly |

### Practical Strategy
**Maximize physical light first, use gain as a last resort.** A $30 LED work light placed 3 feet from the impact zone does more for image quality than any amount of electronic gain. The camera settings priority should always be:

1. Add more physical light to the hitting area
2. Use the fastest lens available (F1.2)
3. Set exposure to the longest acceptable duration (200us if blur is OK, 100us for maximum clarity)
4. Only then increase gain to reach target brightness

---

## 9. Putting It All Together — The Complete Capture Chain

### The Signal Chain
```
Sunlight/Lighting → Lens (F1.2, IR-corrected) → Sensor (OV9281, global shutter, monochrome)
→ Exposure (100-200 us) → Gain (as low as possible) → ROI Crop (640x400) → 240 FPS output
→ Software (detect ball, track markers, calculate spin)
```

Every link in this chain affects the final result. A weakness in any one link degrades the whole system.

### Recommended Configuration Summary

| Parameter | Recommended Setting | Why |
|---|---|---|
| **Sensor** | OV9281 (monochrome, global shutter) | 3x light advantage, no rolling shutter distortion |
| **Resolution** | 640 x 400 (ROI crop) | Enables 240 FPS on 2-lane MIPI |
| **Frame Rate** | 240 FPS | Matches MLM2 Pro, provides 2-3 frames in spin window |
| **Exposure** | 100-200 us | Freezes ball to 7-14mm blur (viable for marker tracking) |
| **Gain** | As low as conditions allow (1.0-8.0x) | Minimize noise, maximize marker contrast |
| **Lens Focal Length** | 8mm at 5ft distance, 12mm at 7-8ft | Balance between ball pixel size and field of view |
| **Lens Aperture** | F1.2 | Maximum light gathering for short exposures |
| **Lens Type** | IR-corrected (Day/Night) | Exploits sensor's NIR sensitivity without focus loss |
| **Orientation** | 90 degrees CW (portrait) | Maximizes vertical coverage for ball departure path |
| **Ball Requirement** | Fiducial-marked (RPT, Pix, or DIY dots) | Plain white balls are algorithmically untrackable |

---

## 10. Exposure Presets by Lighting Condition

These are starting-point configurations. Fine-tune gain until the ball surface reads ~80% brightness without clipping.

### Outdoor — Bright Sun
```
Exposure:  100 us
Gain:      1.0x - 2.0x
Expected:  Excellent contrast, minimal noise, best spin accuracy
Notes:     May need to decrease exposure further if image clips (overexposes)
```

### Outdoor — Overcast / Shade
```
Exposure:  150-200 us
Gain:      2.0x - 4.0x
Expected:  Good contrast, low noise, reliable spin tracking
Notes:     Standard outdoor operating condition
```

### Indoor — Bright Flood Lights (Simulating Outdoor)
```
Exposure:  150-200 us
Gain:      4.0x - 8.0x
Expected:  Moderate noise, workable for spin tracking
Notes:     Position LED floods 3-5 ft from impact zone, aimed directly at ball
```

### Indoor — Standard Room Lighting
```
Exposure:  300-500 us
Gain:      8.0x - 12.0x
Expected:  Increased blur and noise, spin tracking becomes unreliable
Notes:     This is where the MLM2 Pro also struggles. Add more light.
```

### Indoor — Dim / Simulator Bay
```
Exposure:  500+ us
Gain:      12.0x - 16.0x
Expected:  Heavy blur, heavy noise, spin tracking unlikely
Notes:     Not viable for spin detection. Must add supplemental lighting.
```

---

## 11. Quick Reference — Ball Pixel Diameter at Common Distances

### With 8mm F1.2 Lens (OV9281, native pixel pitch)

| Distance | Ball Diameter (px) | Spin Viable? |
|---|---|---|
| 4 ft (1219mm) | ~93 px | Excellent |
| **5 ft (1524mm)** | **~75 px** | **Good (recommended distance)** |
| 6 ft (1829mm) | ~62 px | Adequate |
| 7 ft (2133mm) | ~53 px | Marginal |
| 8 ft (2438mm) | ~47 px | Minimum viable |

### With 12mm F1.2 Lens (OV9281, native pixel pitch)

| Distance | Ball Diameter (px) | Spin Viable? |
|---|---|---|
| 4 ft (1219mm) | ~140 px | Overkill (FOV too narrow) |
| 5 ft (1524mm) | ~112 px | Excellent (but tight FOV at 640x400) |
| 6 ft (1829mm) | ~93 px | Very good |
| **7 ft (2133mm)** | **~80 px** | **Good (designed for this distance)** |
| 8 ft (2438mm) | ~70 px | Good |

### With 2.8mm Lens (Trajectory Camera)

| Distance | Ball Diameter (px) | Spin Viable? |
|---|---|---|
| 5 ft (1524mm) | ~26 px | No — trajectory tracking only |
| 7 ft (2133mm) | ~19 px | No — trajectory tracking only |

---

## 12. Glossary

| Term | Definition |
|---|---|
| **Ball Pixel Diameter** | How many pixels across the golf ball appears in the camera frame |
| **FPS (Frames Per Second)** | How many individual images the camera captures each second |
| **Exposure Time** | How long the sensor collects light for each frame (measured in microseconds) |
| **Motion Blur** | Smearing caused by object movement during the exposure window |
| **Global Shutter** | Sensor architecture that exposes all pixels simultaneously |
| **Rolling Shutter** | Sensor architecture that exposes pixels row-by-row (causes distortion on fast objects) |
| **Gain** | Electronic amplification of the sensor signal (higher = brighter but noisier) |
| **ROI Crop** | Reading only a portion of the sensor to increase frame rate |
| **Aperture (F-number)** | Size of the lens opening; lower number = more light |
| **IR-Corrected Lens** | Lens designed to focus both visible and infrared light on the same plane |
| **Monochrome Sensor** | Black-and-white sensor with no color filter; captures ~3x more light than color |
| **Fiducial Marker** | A high-contrast visual pattern on the ball used as a tracking anchor for spin detection |
| **RPT** | Rapsodo Precision Technology — printed dot pattern on golf balls for spin tracking |
| **NIR** | Near-Infrared — light wavelengths (700-1000nm) invisible to humans but visible to the OV9281 |
| **Pixel Pitch** | Physical size of each pixel on the sensor (OV9281 = 3.0 microns) |
| **Pinhole Camera Model** | Mathematical formula relating object size, distance, focal length, and pixel size |
| **MIPI CSI** | Camera Serial Interface — high-speed digital connection between sensor and processor |
| **Centroid** | The calculated center point of a detected marker or dot in the image |
| **Bayer Filter** | Color filter mosaic on consumer cameras that blocks ~65% of incoming light |
| **Clipping** | Overexposure where pixel values hit maximum (255), losing all detail in bright areas |

---

## Source Traceability

- MLM2 Pro 240 FPS and global shutter: Rapsodo product specifications, FCC filing 2AH3O-MLM2PRO
- MLM2 Pro ambient light reliance: FCC internal photos analysis (no flash/strobe hardware), confirmed by user reports of dark-room failures
- OV9281 specifications: OmniVision OV9281 product page and datasheet
- OV9281 FPS vs resolution: Datasheet max frame rates, confirmed by Raspberry Pi community benchmarks
- Exposure/blur calculations: Standard physics (distance = velocity x time)
- Monochrome ~3x advantage: Bayer filter blocks ~65% of light per pixel (red/blue pixels see only ~1/3 of spectrum, green ~1/3)
- Ball pixel diameter calculations: Pinhole camera model with verified sensor and lens specifications
- 36.4 microsecond OV9281 floor: Linux kernel driver analysis (4 readout lines minimum)
- Fiducial marker requirement: MLM2 Pro returns "N/A" for spin without RPT balls; confirmed by Rapsodo support documentation
