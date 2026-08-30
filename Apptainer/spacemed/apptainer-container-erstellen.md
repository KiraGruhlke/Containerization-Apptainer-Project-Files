# Container erstellen

## Lokal

### Apptainer installieren

```bash
sudo apt install apptainer
```

- `sudo apt install uidmap` ermöglicht "User Namespaces": Dein normaler Nutzer kann sich innerhalb des Containers wie Root verhalten
- `sudo apt install squashfs-tools` um beim Bauen eines Containers so ein Dateisystem zu erzeugen bzw. beim Ausführen zu lesen
- `sudo apt install fuse-overlayfs` wenn ein Container läuft, muss er "so tun", als könnte er in sein eigenes (read-only) Dateisystem schreiben, z. B. temporäre Dateien anlegen. Dafür wird eine beschreibbare Schicht über das eigentliche Image gelegt (Overlay)

#### Prüfung der Einrichtung von uidmap (subuid/subgid)

Damit dein normaler Nutzer sich innerhalb eines Containers wie root verhalten kann (ohne echte Root-Rechte auf dem System), muss ihm ein Bereich zusätzlicher User-/Group-IDs zugewiesen sein.

**1. Prüfen, ob ein Eintrag existiert:**

```bash
grep "$USER" /etc/subuid
grep "$USER" /etc/subgid
```

Erwartete Ausgabe, wenn dein Nutzername `beispiel` ist:

```
beispiel:100000:65536
```

Das bedeutet: dir steht der UID-Bereich von 100000 bis 165535 zur Verfügung (65536 IDs), den Apptainer intern für den "fake root" im Container nutzt. `/etc/subgid` sollte analog aussehen.

Wenn nichts ausgegeben wird, nachtragen:

```bash
sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 "$USER"
```

Danach nochmal mit `grep` prüfen, ob der Eintrag jetzt da ist.

**2. Prüfen, ob unprivilegierte User-Namespaces erlaubt sind:**

```bash
cat /proc/sys/kernel/unprivileged_userns_clone
```

Erwartete Ausgabe:

```
1
```

Falls `0` steht, aktivierst du es dauerhaft:

```bash
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-userns.conf
sudo sysctl --system
```

**3. Funktionstest:**

```bash
apptainer run --fakeroot docker://alpine echo "Fakeroot funktioniert"
```

Läuft das ohne Fehler durch (und lädt dabei automatisch das kleine Alpine-Image herunter), ist alles korrekt eingerichtet und wir können mit dem ersten "richtigen" Container-Build loslegen.

### Definitionsdatei (.def) schreiben

Eine `.def`-Datei ist eine Bauanleitung: Sie beschreibt, welches Basissystem verwendet wird, was darin installiert wird, und was passiert, wenn der fertige Container gestartet wird.

**Welche Art Programm ist es und seine Abhängigkeiten?**

Dateien aus dem Repository, die es erläutern:

- `spacemed.yml`
- `README.md`
- `setup.py` und `setup.cfg`

Die `.def`-Datei ist einfach eine Textdatei – du kannst sie mit jedem Editor erstellen. Im Terminal am gängigsten:

```bash
nano spacemed26.def
```

Dann den Inhalt reinschreiben/einfügen, speichern mit `Strg+O`, `Enter`, verlassen mit `Strg+X`.

**Bootstrap** legt fest, woher das Basis-Image kommt. Häufige Optionen:

- `docker` → zieht ein Image von Docker Hub (am gebräuchlichsten, riesige Auswahl)
- `library` → Apptainer/Singularity-eigene HPC-fokussierte Container-Bibliothek (aber nicht gewartet, von Privatpersonen geteilte Projekte)
- `localimage` → ein lokal bereits vorhandenes `.sif` als Basis nutzen

Das Basis-Image bestimmt:

- Welches Betriebssystem du hast (Debian, Ubuntu, Alpine, ...)
- Was schon vorinstalliert ist – spart dir Arbeit im Post-Abschnitt
- Wie groß der fertige Container wird

```
Bootstrap: docker
From: debian:trixie
```

Diese Zeile sagt: "Hol dir das Image `debian:trixie` von Docker Hub"

#### `%post`

**1. System-Pakete installieren**

Bevor du irgendwas klonen oder installieren kannst, brauchst du Basis-Werkzeuge, die in `debian:trixie` evtl. noch fehlen. Typischerweise:

- `git` - zum Klonen deines Repos
- `wget` oder `curl` - zum Herunterladen des Miniconda-/Mambaforge-Installers
- `ca-certificates` - wichtig, damit HTTPS-Downloads (z. B. von GitHub, github.com für Conda-Installer) funktionieren

```
apt-get update && apt-get install -y git wget ca-certificates
```

**2. Conda-Umgebung herunterladen und installieren**

Installer-Skript herunterladen (wget):

```
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh
```

Skript ausführen mit einem Zielpfad (z. B. `/opt/conda`):

```
bash /tmp/miniforge.sh -b -p /opt/conda
```

Installer-Datei danach löschen:

```
rm /tmp/miniforge.sh
```

**3. GitHub-Repo klonen**

```
git clone https://github.com/KiraGruhlke/spacemed.git /opt/spacemed
```

**4. Conda-Umgebung aus `spacemed.yml` erstellen**

```
cd /opt/spacemed
/opt/conda/bin/mamba env create -f spacemed.yml
```

**5. Temporären `build/`-Ordner im Quellverzeichnis entfernen**

```
rm -rf /opt/spacemed/build
```

#### `%environment`

Hier legst du Umgebungsvariablen fest, die zur Laufzeit gelten sollen.

```
export PATH=/opt/conda/envs/spacemed26/bin:$PATH
```

Sorgt dafür, dass wir automatisch die Programme der „spacemed"-Umgebung starten und keine falschen Systemprogramme.

#### `%runscript`

Das definiert das Standardverhalten, wenn jemand `apptainer run spacemed.sif` aufruft.

```
exec /opt/conda/envs/spacemed26/bin/python "$@"
```

Ich starte direkt in Python statt in der Shell des Containers.

#### Weitere optionale Abschnitte (nicht im Beispiel, aber gut zu kennen)

- **`%files`**: Dateien vom Host in den Container kopieren (z. B. lokale Konfigs statt aus git zu klonen)

  ```
  z.B. /home/kira/Dokumente/spacemed_lokal /opt/spacemed
  ```

- **`%labels`**: Metadaten wie Version, Autor
- **`%help`**: Text, der bei `apptainer run-help` angezeigt wird
- **`%test`**: Wird nach dem Build ausgeführt, um zu prüfen, ob alles funktioniert (z. B. `python -c "import spacemed"`)

### Container bauen

```bash
sudo apptainer build spacemed26.sif spacemed26.def
```

### Auf den Charité-HPC-Cluster übertragen (vom Frontend)

```bash
rsync -avz --progress /home/kira/Apptainer/ USERNAME@s-sc-frontend2.charite.de:~/Apptainer/
```
