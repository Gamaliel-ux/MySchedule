"""
Generates proper alarm audio files for MySchedule app.
- Android: android/app/src/main/res/raw/  (no extension in code reference)
- iOS:     ios/Runner/                     (.caf or .wav extension)

Run: python generate_alarm_tones.py
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 44100

android_dir = os.path.join('android', 'app', 'src', 'main', 'res', 'raw')
ios_dir = os.path.join('ios', 'Runner')
os.makedirs(android_dir, exist_ok=True)
os.makedirs(ios_dir, exist_ok=True)


def write_wav(path, frames_bytes, channels=1, sampwidth=2, rate=SAMPLE_RATE):
    with wave.open(path, 'wb') as f:
        f.setnchannels(channels)
        f.setsampwidth(sampwidth)
        f.setframerate(rate)
        f.writeframes(frames_bytes)


def sample(value):
    """Clamp and pack a float [-1, 1] to a signed 16-bit int."""
    clamped = max(-1.0, min(1.0, value))
    return struct.pack('<h', int(clamped * 32767))


def make_alarm_default(duration_sec=6.0):
    """
    Classic repeating alarm: rapid beeps at 880 Hz + 1100 Hz alternating,
    grouped in bursts to create the iconic 'alarm clock' feel.
    Pattern: 3 beeps x 0.18s ON / 0.07s OFF, then 0.5s pause, repeat.
    """
    frames = []
    t = 0
    beep_on = 0.18
    beep_off = 0.07
    burst_count = 3
    burst_pause = 0.5
    freqs = [880, 1100, 880]

    total_samples = int(SAMPLE_RATE * duration_sec)
    i = 0
    burst = 0
    beep_idx = 0
    phase = 0.0  # 'on' or timer

    while i < total_samples:
        # Build one burst
        for b in range(burst_count):
            freq = freqs[b % len(freqs)]
            on_samples = int(SAMPLE_RATE * beep_on)
            off_samples = int(SAMPLE_RATE * beep_off)
            for s in range(on_samples):
                if i >= total_samples:
                    break
                ti = s / SAMPLE_RATE
                # Envelope: ramp up 10ms, ramp down 10ms
                env = 1.0
                ramp = int(0.01 * SAMPLE_RATE)
                if s < ramp:
                    env = s / ramp
                elif s > on_samples - ramp:
                    env = (on_samples - s) / ramp
                v = env * 0.85 * math.sin(2 * math.pi * freq * ti)
                frames.append(sample(v))
                i += 1
            for s in range(off_samples):
                if i >= total_samples:
                    break
                frames.append(sample(0.0))
                i += 1
        # Pause between bursts
        pause_samples = int(SAMPLE_RATE * burst_pause)
        for s in range(pause_samples):
            if i >= total_samples:
                break
            frames.append(sample(0.0))
            i += 1

    return b''.join(frames)


def make_soft_chime(duration_sec=4.0):
    """
    Soft ascending chime: two tones (660 Hz then 880 Hz), each with a slow decay.
    Gentler alarm for low-priority reminders.
    """
    frames = []
    total = int(SAMPLE_RATE * duration_sec)
    i = 0
    chime_pairs = [(660, 0.8), (880, 0.7), (1046, 0.6)]
    gap = int(0.3 * SAMPLE_RATE)

    for freq, vol in chime_pairs:
        note_len = int(0.7 * SAMPLE_RATE)
        for s in range(note_len):
            if i >= total:
                break
            ti = s / SAMPLE_RATE
            # Exponential decay envelope
            env = vol * math.exp(-3.5 * ti)
            v = env * math.sin(2 * math.pi * freq * ti)
            # Add slight second harmonic for richer tone
            v += (env * 0.2) * math.sin(2 * math.pi * freq * 2 * ti)
            frames.append(sample(v))
            i += 1
        for s in range(gap):
            if i >= total:
                break
            frames.append(sample(0.0))
            i += 1

    while i < total:
        frames.append(sample(0.0))
        i += 1

    return b''.join(frames)


def make_urgent_buzz(duration_sec=6.0):
    """
    Urgent repeating high-pitched alert: rapid square-ish buzz at 1400 Hz.
    High-priority alarm sound.
    """
    frames = []
    total = int(SAMPLE_RATE * duration_sec)
    beep_on = int(0.12 * SAMPLE_RATE)
    beep_off = int(0.05 * SAMPLE_RATE)
    long_pause = int(0.35 * SAMPLE_RATE)
    freq = 1400
    burst_count = 4

    i = 0
    while i < total:
        for b in range(burst_count):
            for s in range(beep_on):
                if i >= total:
                    break
                ti = s / SAMPLE_RATE
                ramp = int(0.005 * SAMPLE_RATE)
                env = 1.0
                if s < ramp:
                    env = s / ramp
                elif s > beep_on - ramp:
                    env = (beep_on - s) / ramp
                # Mix fundamental + 3rd harmonic for buzz quality
                v = env * 0.7 * math.sin(2 * math.pi * freq * ti)
                v += env * 0.15 * math.sin(2 * math.pi * freq * 3 * ti)
                frames.append(sample(v))
                i += 1
            for s in range(beep_off):
                if i >= total:
                    break
                frames.append(sample(0.0))
                i += 1
        for s in range(long_pause):
            if i >= total:
                break
            frames.append(sample(0.0))
            i += 1

    return b''.join(frames)


# ─────────────────────────────────────────────
# Generate and save all sounds
# ─────────────────────────────────────────────

sounds = {
    'alarm_default': make_alarm_default(),
    'soft_chime':    make_soft_chime(),
    'urgent_buzz':   make_urgent_buzz(),
}

for name, data in sounds.items():
    android_path = os.path.join(android_dir, f'{name}.wav')
    ios_path     = os.path.join(ios_dir, f'{name}.wav')
    write_wav(android_path, data)
    write_wav(ios_path, data)
    android_kb = os.path.getsize(android_path) / 1024
    print(f'  {name}.wav  ->  Android ({android_kb:.0f} KB)  +  iOS OK')

print('\nDone! Audio files generated for Android and iOS.')
print('Next steps:')
print('  Android : files are in res/raw/ -- no action needed.')
print('  iOS     : In Xcode, add the .wav files in ios/Runner/ to the Runner target.')
