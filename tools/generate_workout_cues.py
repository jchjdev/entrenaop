"""Genera los pitidos originales de EntrenaOP, sin archivos de terceros."""

import math
from pathlib import Path
import struct
import wave

SAMPLE_RATE = 44100
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/workout"
# Frecuencia, duración y pausa posterior en segundos. Fundido de 8 ms para
# evitar chasquidos, con volumen moderado y diferencias de ritmo reconocibles.
TONES = {
    "preparation": [(700, 0.10, 0.0)],
    "start": [(1200, 0.28, 0.0)],
    "halfway": [(650, 0.10, 0.06), (850, 0.10, 0.0)],
    "ten_seconds": [(1050, 0.08, 0.04)] * 3,
    "finish": [(1000, 0.12, 0.06), (700, 0.25, 0.0)],
}


def generate():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name, tones in TONES.items():
        samples = []
        for frequency, duration, pause in tones:
            count = round(duration * SAMPLE_RATE)
            fade = round(0.008 * SAMPLE_RATE)
            for index in range(count):
                envelope = min(1, index / fade, (count - 1 - index) / fade)
                value = 0.45 * envelope * math.sin(
                    2 * math.pi * frequency * index / SAMPLE_RATE
                )
                samples.append(round(32767 * value))
            samples.extend([0] * round(pause * SAMPLE_RATE))
        destination = OUTPUT / f"{name}.wav"
        with wave.open(str(destination), "wb") as audio:
            audio.setnchannels(1)
            audio.setsampwidth(2)
            audio.setframerate(SAMPLE_RATE)
            audio.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        print(f"{destination.name}: {len(samples) / SAMPLE_RATE:.2f} s")


if __name__ == "__main__":
    generate()
