# GPU-Unterstützung

## Wofür das Ganze

GPUs lohnen sich, wenn eine Aufgabe in viele ähnliche, unabhängige Rechenschritte zerlegt werden kann, die dann in das Aufgabenergebnis integriert werden müssen, wie etwa beim Deep Learning, der Bildverarbeitung oder der groß angelegten linearen Algebra. Genau dafür sind GPUs gebaut.

**Faustregel:**

| Aufgabentyp | Beste Hardware |
|---|---|
| Wenige, aber komplexe, verzweigte Schritte (viel Entscheidungslogik, Abhängigkeiten zwischen Schritten) | CPU |
| Sehr viele, identische, einfache Rechenschritte, die unabhängig voneinander parallel laufen können | GPU |

## Technischer Hintergrund

Die GPU-Beschleunigung ist eine bewusste Ausnahme von der vollständigen Isolation des Containers vom Host. Der Grund dafür ist, dass der NVIDIA- oder AMD-Treiber eng an den Kernel des Hosts und an die physische GPU-Hardware gebunden ist und daher nicht einfach in ein tragbares Container-Image verpackt werden kann. Apptainer handhabt dies mit dem Flag `--nv` für NVIDIA-GPUs (und dem entsprechenden Flag `--rocm` für AMD-GPUs): Zur Laufzeit findet Apptainer die erforderlichen Treiberdateien auf dem Host und stellt sie im laufenden Container zur Verfügung, ohne sie in das Image selbst zu kopieren (vergleichbar mit dem Befehl bind-mount).

Das CUDA-Toolkit ist ein Software-Entwicklungspaket von NVIDIA zum Programmieren von GPU-Anwendungen. Es liegt direkt im Container-Image, da es an das Programm gebunden ist (z. B. PyTorch). NVIDIA sorgt dafür, dass die Treiber abwärtskompatibel sind: Ein neuerer Treiber auf dem Host kann eine ältere CUDA-Version im Container ausführen, aber nicht umgekehrt. Also nur falls die CUDA-Version im Container neuer ist als der Treiber des Hosts, gibt es Kompatibilitätsprobleme.

AMD-GPUs nutzen kein CUDA, sondern das eigene ROCm/HIP-Ökosystem, das funktionell vergleichbar ist.

## Test als Batch-Skript (gpu_test.sh)

### Neues Batch-Skript anlegen:

```bash
nano ~/GPU-Test/jobs/gpu_test_nvidia.sh
nano ~/GPU-Test/jobs/gpu_test_amd.sh
```

### Inhalt `gpu_test_nvidia.sh`:

```bash
#!/bin/bash
#SBATCH --job-name="torch gpu test"
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:10:00
#SBATCH --output=/home/kigr11/Apptainer/gpu_test/slurm-%j.out

pwd
apptainer exec --nv /home/kigr11/Apptainer/gpu_test/gpu_test_nvidia.sif python /opt/gpu_test/src/gpu_test.py -o /home/kigr11/Apptainer/gpu_test/matmul_result_nvidia.pt
```

#### Kurz erklärt, was neu ist

- `--partition=gpu` statt `compute` — GPU-Node anfordern
- `--gres=gpu:1` — eine GPU-Einheit zuweisen lassen
- `--nv` beim `apptainer exec` — Treiber-Durchreichung aktivieren
- `python -c "..."` — statt eines separaten Skripts hier ein kurzer Inline-Python-Befehl, der direkt prüft, ob CUDA verfügbar ist und welche GPU erkannt wird
- `--mem=16G`/`--cpus-per-task=4` — bewusst kleiner als bei den compute-Jobs, weil wir hier nur einen schnellen Check machen, keine echte Rechenlast

### Inhalt `gpu_test_amd.sh`:

```bash
#!/bin/bash
#SBATCH --job-name="torch gpu test amd"
#SBATCH --partition=agpu
#SBATCH --gres=gpu:1
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --time=00:10:00
#SBATCH --output=/home/kigr11/Apptainer/gpu_test/slurm-%j.out

pwd
apptainer exec --rocm /home/kigr11/Apptainer/gpu_test/gpu_test_amd.sif python /opt/gpu_test/src/gpu_test.py -o /home/kigr11/Apptainer/gpu_test/matmul_result_amd.pt
```

#### Was sich in der AMD- gegenüber der NVIDIA-Version geändert hat

- `--partition=gpu` → `--partition=agpu` (die eine AMD-Node aus der Wiki-Tabelle, `s-sc-agpu001`)
- `--nv` → `--rocm` (AMDs Treiber-Durchreichung statt NVIDIAs)
- Container-Pfad zeigt jetzt auf `gpu_test_amd.sif` statt `gpu_test_nvidia.sif`
- Job-Name leicht angepasst, damit du beide Jobs in `squeue` unterscheiden kannst
