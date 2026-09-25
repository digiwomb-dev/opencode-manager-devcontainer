# Pinned by Manifest-List-Digest for multi-arch support.
# The tag is kept alongside the digest so that Renovate tracks this specific
# release line, and so that the publish workflow can derive its output tag from
# it. Without the tag, Renovate would implicitly track `latest`.
FROM ghcr.io/chriswritescode-dev/opencode-manager:0.18.0@sha256:b3f1963af2bd8d19aa9920bfe7f3f69021116853f690a3b3cc63536734419e00

# Snapshot fallback timestamp for Debian packages.
# Must match or follow the pinned package versions, otherwise the snapshot
# would not contain them and the fallback would be useless. The build workflow
# passes the commit timestamp, so a Renovate bump and its snapshot always agree.
ARG SNAPSHOT_TS=20260925T053018Z

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
COPY registries.conf /etc/containers/registries.conf

# This image carries its own version line, so record which upstream release it
# was built on. Supplied by the build workflow.
ARG IMAGE_VERSION
ARG UPSTREAM_VERSION
ARG REVISION
LABEL org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.base.name="ghcr.io/chriswritescode-dev/opencode-manager:${UPSTREAM_VERSION}" \
      org.opencontainers.image.source="https://github.com/digiwomb-dev/opencode-manager-devcontainer"
