# Daten-Directory an Container binden

## Container bauen

### Automatisch eingebundene Pfade (Standard-Binds)

| Pfad | Zweck |
|---|---|
| `$HOME` (dein Home-Verzeichnis) | Damit du direkt auf deine eigenen Dateien zugreifen kannst |
| `/tmp` | Temporäre Dateien |
| `/proc` | Systeminformationen (Prozesse) – technisch nötig, damit der Container überhaupt läuft |
| `/sys` | Systeminformationen (Hardware/Kernel) |
| `/dev` | Geräte-Dateien (z. B. `/dev/null`, `/dev/zero`) |
| `$PWD` (aktuelles Arbeitsverzeichnis) | Damit relative Pfade beim Aufruf funktionieren |
| `/etc/hosts` | Namensauflösung (welche IP zu welchem Hostnamen gehört) |
| `/etc/resolv.conf` | DNS-Konfiguration |

## Bind Mount

Mit Bind Mount trennst du Code/Umgebung (im Container, unveränderlich) von Daten (auf dem Host bzw. später im Cluster-Dateisystem, veränderlich). Das ist auch der in der Praxis übliche Ansatz bei HPC-Workflows. So kannst du die Daten außerhalb des Containers speichern und den Container mit anderen teilen, sodass jede*r seine persönlichen Daten mit dem Container verarbeiten kann. Dafür muss weder das Skript noch der Container selbst geändert werden.

### Bind Mount lokal laufen lassen

```bash
apptainer run --bind /pfad/zu/deinen/echten/daten:/opt/spacemed/data spacemed26_data.sif
```

Dabei:

- `/pfad/zu/deinen/echten/daten` = wo deine echten Messdaten auf deinem Host liegen (z. B. `~/Dokumente/data`)
- `/opt/spacemed/data` = der Pfad, den der Code intern erwartet (basierend auf deiner `.def`-Datei, wo alles unter `/opt/spacemed` liegt)

#### Falls dein Skript einen Pfad als Argument braucht

`plot_heart_rate.py` nimmt den Datenpfad als Kommandozeilen-Argument entgegen, keinen festen Pfad. Der `%runscript` deiner `.def`-Datei ruft direkt Python auf:

```
%runscript
    exec /opt/conda/envs/spacemed26/bin/python "$@"
```

Das heißt, du rufst den Container so auf:

```bash
apptainer run --bind ~/Dokumente/data:/data spacemed26_data.sif -m spacemed.plot_heart_rate /data/pulse_data.csv
```

Hier:

- `~/Dokumente/data:/data` → dein externes Datenverzeichnis wird nach `/data` im Container gemountet (du kannst den Zielnamen frei wählen, da nichts fest verdrahtet ist)
- `-m spacemed.plot_heart_rate /data/pulse_data.csv` → wird als `"$@"` an Python durchgereicht, ruft also dein Modul mit dem Pfad zur Datei im gemounteten Verzeichnis auf
- `/data/pulse_data.csv` → der Pfad zur Datei innerhalb des Containers, den `plot_heart_rate.py` als Argument bekommt (passt zum gewählten Zielpfad `/data`)

### Bind Mount auf dem Cluster

Analog zum lokalen Test müssen wir das Skript kennen: Hat es intern einen Pfad für die Daten fest hinterlegt oder nimmt die Funktion einen Dateipfad als Parameter entgegen (`fname`, `args.data`)? In letzterem Fall kannst du dem Skript beim Aufruf einfach sagen, wo die Datei liegt – z. B.:

```bash
apptainer exec spacemed_data.sif python -m spacemed.plot_heart_rate /data/pulse_data.csv
```

Dabei wäre `/data` dann dein Bind-Mount-Ziel:

```bash
apptainer exec --bind /host/pfad/zu/messungen:/data spacemed_data.sif python -m spacemed.plot_heart_rate /data/pulse_data.csv
```

#### Neuer Job mit Bind Mount

```bash
nano ~/Apptainer/spacemed/phr_bind.sh
```

Inhalt:

```bash
#!/bin/bash
#SBATCH --job-name="plot heart rate bind"
#SBATCH --partition=compute
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --time=01:00:00
#SBATCH --output=/home/kigr11/Apptainer/spacemed_data/slurm-%j.out

pwd
apptainer exec --bind /home/kigr11/Data/apptainer_spacemed_data:/data /home/kigr11/Apptainer/spacemed_data/spacemed26_data.sif sm_plot_heart /data/pulse_data.csv -o /home/kigr11/Apptainer/spacemed_data/phr_bind.png
```

Was sich geändert hat, gegenüber der ersten Version:

- `--bind /home/kigr11/Data/apptainer_spacemed_data:/data` direkt nach `apptainer exec` eingefügt — das ist genau der gleiche Bind-Mount-Syntax, den du schon beim allerersten Test (`apptainer exec --bind ... ls /data`) verwendet hast
- Der Datenpfad ist jetzt `/data/pulse_data.csv` statt `/opt/spacemed/data/pulse_data.csv` — weil `/data` jetzt der Mount-Punkt ist, hinter dem dein externer `apptainer_spacemed_data`-Ordner "versteckt" liegt
- Output-Dateiname zu `phr_bind.png` geändert, damit er sich nicht mit dem vorherigen `phr.png` überschneidet — so kannst du hinterher beide Ergebnisse vergleichen

#### Anmerkung

Technisch gesehen bräuchte es hier `--bind` nicht. Da `~/Data/apptainer_spacemed_data/` ja sowieso schon direkt in deinem Home-Verzeichnis liegt, hätten wir auch einfach direkt schreiben können:

```bash
apptainer exec /home/kigr11/Apptainer/spacemed_data/spacemed26_data.sif sm_plot_heart /home/kigr11/Data/apptainer_spacemed_data/pulse_data.csv -o /home/kigr11/Apptainer/spacemed_data/phr_bind.png
```

— ganz ohne `--bind`, und es hätte genauso funktioniert. Der `--bind`-Ansatz mit `/data` als Zielpfad war in dem Fall eine bewusste Übung/Demonstration des Bind-Mount-Prinzips, nicht eine technische Notwendigkeit für genau diesen Datensatz. Dies ist der Test, dass `/data` im Container ein frei wählbarer, neuer Pfad ist, der zu einem beliebigen externen Ordner zeigt — quasi als "Übung", einen komplett neuen Mount-Punkt zu definieren, unabhängig davon, wo die Datei eigentlich auf dem Host-System liegt.
