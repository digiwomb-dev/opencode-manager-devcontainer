# OpenCode Manager mit Dev Container Support

Dieses Repository baut ein erweitertes Image des OpenCode-Managers (`opencode-manager`), das einen vollständigen rootless-Podman-Stack sowie die `devcontainer`-CLI integriert.

## Wozu das Image da ist

Das Ziel ist es, Dev Container direkt *im* Manager-Container laufen zu lassen (Nested Containers), anstatt sie als Geschwister-Container über einen durchgereichten Docker-Socket auf dem Host-System zu starten. Das verbessert die Isolation und vermeidet die Notwendigkeit, den Docker-Socket in den Container durchzureichen.

## Einbindung

Das Image kann in einer `docker-compose.yml` wie folgt verwendet werden:

```yaml
services:
  opencode-manager:
    image: ghcr.io/digiwomb-dev/opencode-manager-devcontainer:0.18.0
    security_opt:
      - unmask=ALL
      - seccomp=unconfined
    devices:
      - /dev/net/tun:/dev/net/tun
      - /dev/fuse:/dev/fuse
    volumes:
      - opencode-containers:/home/node/.local/share/containers
```

### Warum diese Compose-Optionen benötigt werden

- **`security_opt: unmask=ALL`**: Ohne diese Option scheitert jeder verschachtelte Container mit `VFS: Mount too revealing`. Podman muss ein frisches `procfs` mounten, was durch die maskierten `/proc`-Submounts des äußeren Containers verhindert wird. Diese Option hebt die Maskierung auf.
- **`security_opt: seccomp=unconfined`**: Erlaubt dem Container, Systemaufrufe (Syscalls) durchzuführen, die für die Ausführung von verschachtelten Containern (z.B. durch `crun` und `podman`) notwendig sind.
- **`devices: /dev/net/tun`**: Notwendig für das nested Netzwerk (netavark/pasta), um Netzwerk-Interfaces für die inneren Container zu erstellen.
- **`devices: /dev/fuse`**: Wird als Storage-Fallback benötigt, falls das native unprivilegierte `overlayfs` nicht verfügbar ist.
- **`volumes: /home/node/.local/share/containers`**: Zwingend erforderlich. Ein unprivilegiertes `overlayfs` direkt auf dem Container-Rootfs (overlay-auf-overlay) schlägt fehl. Das Mounten eines Volumes umgeht dieses Problem und ermöglicht performantes natives Overlay (funktioniert auf XFS).
- **Kein Docker-Socket**: Der durchgereichte Docker-Socket entfällt komplett. Podman arbeitet daemonless; es wird weder ein Socket noch ein Hintergrund-Service benötigt.

## Aufruf

Um einen Dev Container zu starten, verwendet der Manager intern folgenden Befehl:

```bash
devcontainer up --docker-path podman
```

## Reproduzierbarkeit & Snapshot-Fallback

Um stabile und reproduzierbare Container-Builds zu garantieren, sind alle installierten Debian-Pakete auf exakte Versionen gepinnt. Da Debian im regulären Live-Archiv stets nur die aktuellste Version vorhält, nutzen wir bei der Installation einen **Snapshot-Fallback**:
Es wird eine zweite `apt`-Quelle (`snapshot.debian.org`) mit einem definierten Zeitstempel (z.B. `20260918T000000Z`) eingebunden.
So greift `apt-get` normalerweise auf das schnelle Live-Archiv zu. Sollte ein gepinntes Paket dort durch ein Update verschwunden sein, bedient sich `apt` nahtlos aus dem Snapshot. Nach der Installation wird die Snapshot-Quelle entfernt, um das fertige Image sauber zu halten.

## Manueller Schritt nach dem ersten Push

Das GHCR-Paket (GitHub Container Registry) ist standardmäßig privat. Nach dem ersten erfolgreichen Push durch die GitHub Actions muss das Image in den Repository-Einstellungen auf **öffentlich (public)** gestellt werden.
