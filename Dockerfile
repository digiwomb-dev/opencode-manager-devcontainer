# Base: ghcr.io/chriswritescode-dev/opencode-manager:0.18.0
# Pinned by Manifest-List-Digest for multi-arch support
FROM ghcr.io/chriswritescode-dev/opencode-manager@sha256:b3f1963af2bd8d19aa9920bfe7f3f69021116853f690a3b3cc63536734419e00

# Snapshot fallback timestamp for Debian packages
# Ensure snapshot timestamp matches or follows pinned package versions
ARG SNAPSHOT_TS=20260918T000000Z

# Install Podman stack using precise package pins and a snapshot fallback
RUN echo "Types: deb\n\
URIs: http://snapshot.debian.org/archive/debian/${SNAPSHOT_TS}\n\
Suites: trixie\n\
Components: main\n\
Signed-By: /usr/share/keyrings/debian-archive-keyring.pgp" > /etc/apt/sources.list.d/snapshot.sources && \
    apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Retries=3 -o Acquire::http::Timeout=60 update && \
    apt-get install -y --no-install-recommends \
        podman=5.4.2+ds1-2+b2 \
        crun=1.21-1 \
        conmon=2.1.12-4 \
        netavark=1.14.0-2 \
        aardvark-dns=1.14.0-3 \
        passt=0.0~git20250503.587980c-2+deb13u1 \
        fuse-overlayfs=1.14-1+b1 \
        catatonit=0.2.1-2+b14 && \
    rm /etc/apt/sources.list.d/snapshot.sources && \
    rm -rf /var/lib/apt/lists/*

# Empty subuid and subgid files to force podman into rootless Single-UID-Mapping mode.
# Without this, podman attempts to use newuidmap (multi-range), which fails because
# the entrypoint drops the required CAP_SETUID capability.
RUN touch /etc/subuid /etc/subgid && > /etc/subuid && > /etc/subgid

# Install devcontainers CLI
RUN npm install -g @devcontainers/cli@0.89.0

# Configure Podman
COPY containers.conf /etc/containers/containers.conf
COPY storage.conf /etc/containers/storage.conf
