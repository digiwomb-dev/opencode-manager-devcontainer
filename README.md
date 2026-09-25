# OpenCode Manager with Dev Container Support

This repository builds an extended image of the OpenCode Manager (`opencode-manager`) that integrates a full rootless Podman stack and the `devcontainer` CLI.

## Purpose

The goal is to run Dev Containers directly *inside* the Manager container (Nested Containers) rather than starting them as sibling containers on the host system via a mounted Docker socket. This improves isolation and removes the need to expose the Docker socket to the container.

## Usage

The image can be used in a `docker-compose.yml` as follows:

```yaml
services:
  opencode-manager:
    image: ghcr.io/digiwomb-dev/opencode-manager-devcontainer:0.18.0-b14
    security_opt:
      - unmask=ALL
      - seccomp=unconfined
    devices:
      - /dev/net/tun:/dev/net/tun
      - /dev/fuse:/dev/fuse
    volumes:
      - opencode-containers:/home/node/.local/share/containers
```

### Image tags

The upstream version alone does not identify a build of this image, because this
repository adds its own package pins on top. Several different builds can share
one upstream version, so a tag like `0.18.0` cannot stay fixed.

| Tag | Example | Stability |
| --- | --- | --- |
| `<version>-b<build>` | `0.18.0-b14` | **Immutable.** Never reassigned. Use this to pin. |
| `sha-<commit>` | `sha-417040d…` | **Immutable.** Same image, addressed by commit. |
| `<version>` | `0.18.0` | Moving. Latest build for that upstream version. |
| `latest` | `latest` | Moving. Latest build overall. |

Pin an immutable tag for anything you depend on. The moving tags are convenience
pointers and will silently change underneath you when a new build is published.
If you want byte-exact reproducibility, pin the digest (`@sha256:…`), which the
immutable tags resolve to anyway.

### Why these compose options are required

- **`security_opt: unmask=ALL`**: Without this option, every nested container fails with `VFS: Mount too revealing`. Podman needs to mount a fresh `procfs`, which is prevented by the masked `/proc` submounts of the outer container. This option removes the mask.
- **`security_opt: seccomp=unconfined`**: Allows the container to execute system calls (syscalls) that are required to run nested containers (e.g., by `crun` and `podman`).
- **`devices: /dev/net/tun`**: Required for the nested network (netavark/pasta) to create network interfaces for the inner containers.
- **`devices: /dev/fuse`**: Required as a storage fallback in case native unprivileged `overlayfs` is unavailable.
- **`volumes: /home/node/.local/share/containers`**: Mandatory. An unprivileged `overlayfs` directly on top of the container rootfs (overlay-on-overlay) will fail. Mounting a host volume bypasses this issue and allows for performant native overlay (works on XFS and Ext4).
- **No Docker Socket**: Passing through the Docker socket is completely omitted. Podman operates daemonless; it requires neither a socket nor a background service.

## Internal Execution

To start a Dev Container, the Manager internally uses the following command:

```bash
devcontainer up --docker-path podman
```

## Security & Rootless Mode

The image is optimized for a strictly nested rootless execution context without privileges like `CAP_SETUID`.
The `uidmap` package has been explicitly excluded from this setup to minimize the attack surface by removing the setuid-root binaries `newuidmap`/`newgidmap`. Instead, Podman falls back entirely to standard rightless single-UID mappings.
Files like `/etc/subuid` and `/etc/subgid` are kept empty intentionally to enforce this mapping behavior.
To make this single-UID context work without permission errors during image extractions, `ignore_chown_errors = "true"` is set within the overlay storage configuration.

## Reproducibility & Snapshot Fallback

To guarantee stable and reproducible container builds, all installed Debian packages are pinned to exact versions. Since the regular live Debian archive only retains the latest versions, we use a **Snapshot Fallback** during installation:
A secondary `apt` source (`snapshot.debian.org`) with a defined timestamp is configured.
By default, `apt-get` accesses the fast live archive. If a pinned package is no longer available there due to an update, `apt` seamlessly falls back to the snapshot. After the installation, the snapshot source is removed to keep the final image clean.

The timestamp is supplied by the build workflow from the commit date, so it always matches or follows the package versions pinned in that same commit. The `SNAPSHOT_TS` default in the Dockerfile is only a fallback for local builds.

## Migration Note: Storage Location Change

If you are updating from an earlier version of this image, you will notice that your previously pulled images and container layers are no longer visible to Podman.
This is expected behavior: The image now explicitly enforces the `rootless_storage_path` to point to the dedicated `/home/node/.local/share/containers` volume, overriding the dynamically set `XDG_DATA_HOME` variable that previously caused layers to be placed within your workspace directory.
You will need to pull your Dev Container images once again. You can safely delete the old Podman storage directories from your workspace to free up disk space.


