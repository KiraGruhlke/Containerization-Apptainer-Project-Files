# Testet, ob PyTorch GPU-Zugriff hat (NVIDIA via CUDA oder AMD via ROCm)
# und führt eine echte Rechenoperation auf der GPU durch.

import argparse
import torch

# Pruefen, ob ueberhaupt eine GPU verfuegbar ist
gpu_available = torch.cuda.is_available()
print("GPU available:", gpu_available)
# Namen der zugewiesenen GPU anzeigen
if gpu_available:
    print("Device name:", torch.cuda.get_device_name(0))
    # Zeigt an, ob PyTorch intern mit CUDA (NVIDIA) oder ROCm/HIP (AMD) läuft
    if torch.version.hip is not None:
        print("Backend: ROCm (AMD)")
    else:
        print("Backend: CUDA (NVIDIA)")
else:
    print("Keine GPU erkannt - entweder ist dieser Container nicht mit")
    print("GPU-Unterstützung gebaut, oder es lief kein --nv/--rocm Flag mit.")

# Rechengerät festlegen: GPU falls verfügbar, sonst CPU als Rückfalloption. Genutztes Geraet ausgeben.
device = torch.device("cuda" if gpu_available else "cpu")
print("Using device:", device)

# Zwei zufällige 5000x5000-Matrizen direkt auf dem gewählten Gerät erzeugen
a = torch.rand(5000, 5000, device=device)
b = torch.rand(5000, 5000, device=device)

# Matrixmultiplikation ausführen - das ist die eigentliche Rechenlast,
# die bei einer GPU deutlich schneller laufen sollte als auf der CPU
result = torch.matmul(a, b)

# Kurze Kontrollausgaben, um das Ergebnis grob zu überprüfen
print("Result shape:", result.shape) # sollte wieder eine 5000*5000 Matrix sein. 
print("Result sum:", result.sum().item()) # addiert alle Einzelwerte und formatiert sie zu einer normalen zahl, sollte sehr hoch sein.

# Ergebnis als Datei abspeichern (.pt ist das Standardformat
# für gespeicherte PyTorch-Tensoren/Modelle)
# Ausgabepfad wird über das -o Flag übergeben, statt fest im Code zu stehen -
# so funktioniert das Skript für jeden Nutzer, unabhängig vom Home-Verzeichnis.
parser = argparse.ArgumentParser(description="GPU-Matrixmultiplikationstest mit PyTorch")
parser.add_argument("-o", "--output", default="matmul_result.pt",
                     help="Pfad zur Ausgabedatei (Standard: matmul_result.pt)")
args = parser.parse_args()

torch.save(result, args.output)
print("Saved result to", args.output)
