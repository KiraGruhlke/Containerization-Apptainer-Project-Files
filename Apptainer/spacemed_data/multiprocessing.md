# Multiprocessing

## Wann nutze ich Parallelisierung mit CPUs

Ich habe viele größere Rechenjobs, die ich völlig unabhängig voneinander mehrfach ausführen möchte. Beispiel: Ich habe ein Python-Skript, das verschiedene Datensätze Satz für Satz auswerten soll.

## Parallelisierung außerhalb des Containers

### Das Grundprinzip

Der Container selbst enthält nur das eigentliche Programm (single-process) und weiß gar nichts von Parallelisierung. Die Verteilung auf mehrere Prozesse übernimmt Slurm, außerhalb des Containers: Der Container wird einfach mehrfach parallel gestartet, eine Instanz pro Prozess/Kern.

Das ist der auf HPC-Clustern übliche, empfohlene Ansatz, aus zwei Gründen:

- **Praktischer Vorteil**: Kein neuer Container, keine `.def`-Datei-Änderung nötig. Jeder bestehende Container (auch einer, der später für echte Berechnungen genutzt wird) lässt sich einfach mehrfach parallel aufrufen, ohne ihn anzupassen.

### Job schreiben

Anpassen, nach dem gleichen Muster wie bisher:

```bash
nano ~/Apptainer/spacemed/ps.sh
```

Inhalt:

```bash
#!/bin/bash
#SBATCH --job-name="generate slices bind"
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --array=0-31
#SBATCH --output=/home/kigr11/Apptainer/spacemed_data/slurm-%A_%a.out

pwd
apptainer exec --bind /home/kigr11/Data/apptainer_spacemed_data:/data /home/kigr11/Apptainer/spacemed_data/spacemed26_data.sif sm_process_slice /data/3_fMRI_TR2sec_3mm_3min.nii ${SLURM_ARRAY_TASK_ID} /home/kigr11/Apptainer/spacemed_data/ps_output_${SLURM_ARRAY_TASK_ID}.png
```

#### Was sich geändert hat bei Array-Jobs

- `#SBATCH --array=0-31` sagt SLURM: "Reiche diesen Job nicht einmal ein, sondern 32-mal — als eigenständige, parallel laufende Teilaufgaben." Jede dieser 32 Teilaufgaben bekommt automatisch eine eigene Umgebungsvariable `${SLURM_ARRAY_TASK_ID}` zugewiesen (0, 1, 2, ... 31) — das ist der einzige Unterschied zwischen den sonst identischen Teilaufgaben.

  In diesem Beispiel nutzt `sm_process_slice` diese ID als Parameter: Task 0 verarbeitet Slice 0 der fMRI-Daten, Task 1 verarbeitet Slice 1, usw. Alle 32 Teilaufgaben laufen (sofern genug Ressourcen frei sind) gleichzeitig auf verschiedenen Compute-Nodes – das ist "Parallelisierung außerhalb des Containers".

- `--output=.../slurm-%A_%a.out` — hier gibt's zwei Platzhalter statt nur `%j`: `%A` ist die Job-ID des gesamten Array-Jobs, `%a` ist die einzelne Task-ID (0 bis 31). So bekommst du 32 separate Log-Dateien, eine pro Teilaufgabe, statt dass sich alle eine Datei teilen (was sonst zu chaotisch vermischtem Text führen würde, weil ja 32 Prozesse gleichzeitig reinschreiben würden)

- `sm_process_slice <nii-datei> ${SLURM_ARRAY_TASK_ID} <output-datei>`

  Hier sagt `${SLURM_ARRAY_TASK_ID}` dem Programm: "verarbeite genau diese eine Slice-Nummer". Das ist der eigentliche Steuerungsmechanismus der Parallelisierung — Task 0 bekommt hier den Wert 0 übergeben und verarbeitet Slice 0, Task 5 bekommt 5 und verarbeitet Slice 5, usw.

- Output-Bildname bleibt mit `${SLURM_ARRAY_TASK_ID}` durchnummeriert — wichtig, sonst würden sich alle 32 parallelen Tasks gegenseitig überschreiben

### Wie viele CPUs pro Task

Die Frage "wie viele CPUs brauche ich" wird durch Testen beantwortet:

- **Skalierungsexperimente**: Laufzeit mit 2, 4, 8, 16 Tasks messen – ab einem gewissen Punkt bringt mehr Parallelisierung oft keinen Geschwindigkeitsvorteil mehr, weil der Kommunikations-Overhead den Nutzen übersteigt (Skalierungsgrenze des jeweiligen Problems).
- **Art des Problems**: "Embarrassingly parallel" (komplett unabhängige Teilaufgaben, z. B. viele unabhängige Datensätze) skaliert meist sehr gut mit vielen Kernen; Probleme mit viel Kommunikation zwischen Prozessen skalieren schlechter.
- **Für den Anfang**: mit einer moderaten Zahl (z. B. 4–8) testen, Laufzeit/Skalierung beobachten, dann gezielt erhöhen.

#### Beispiel

Ich habe ein Skript, das MRT-Slices Schicht für Schicht verarbeitet. Einfache Idee: für jede Schichtaufnahme möchte ich einen CPU-Job laufen lassen.
