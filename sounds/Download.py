"""Generate simple beep sounds for the app"""
import numpy as np
import wave
import os

def generate_beep(filename, frequency=800, duration=0.1, sample_rate=44100):
    """Generate a simple beep sound"""
    # Create sounds directory if it doesn't exist
    os.makedirs("sounds", exist_ok=True)
    
    # Generate beep
    t = np.linspace(0, duration, int(sample_rate * duration))
    # Add envelope to avoid clicks
    envelope = np.exp(-t * 10)
    audio = np.sin(2 * np.pi * frequency * t) * envelope * 0.3
    
    # Convert to 16-bit integers
    audio = (audio * 32767).astype(np.int16)
    
    # Write to WAV file
    filepath = os.path.join("sounds", filename)
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(audio.tobytes())
    
    print(f"Created: {filepath}")

if __name__ == "__main__":
    # Install numpy if needed: pip install numpy
    
    # Generate click sound (short, high pitch)
    generate_beep("click.wav", frequency=1200, duration=0.05)
    
    # Generate success sound (lower, longer)
    generate_beep("success.wav", frequency=600, duration=0.15)
    
    print("\n🎵 Sound files created successfully!")
    print("Run your app now: python main.py")