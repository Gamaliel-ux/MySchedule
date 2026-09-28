import math
import os
import struct
import wave

out_dir = os.path.join('android', 'app', 'src', 'main', 'res', 'raw')
os.makedirs(out_dir, exist_ok=True)

samples = 22050

def make_tone(path, freq, duration=1.2, volume=0.6):
    with wave.open(path, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(samples)
        frames = []
        total_samples = int(samples * duration)
        for i in range(total_samples):
            t = i / samples
            value = volume * math.sin(2 * math.pi * freq * t)
            frames.append(struct.pack('<h', int(value * 32767)))
        wav_file.writeframes(b''.join(frames))

make_tone(os.path.join(out_dir, 'alarm_default.wav'), 880, duration=1.2)
make_tone(os.path.join(out_dir, 'soft_chime.wav'), 660, duration=1.4, volume=0.35)
make_tone(os.path.join(out_dir, 'urgent_buzz.wav'), 1200, duration=0.9, volume=0.8)

print('Generated alarm tones in', out_dir)
