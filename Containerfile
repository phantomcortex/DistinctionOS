# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pre-built custom mesa stack — Fedora SRPM + freeworld codec patches applied.
# Built by .github/workflows/build-mesa.yml, published weekly to GHCR.
# All subpackages come from one SRPM so versions are guaranteed in sync.
#FROM ghcr.io/phantomcortex/distinctionos-mesa:latest AS mesa-rpms

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:testing as DistinctionOS
#FROM quay.io/fedora/fedora-bootc:42

ARG IMAGE_NAME="distinctionos"
ARG IMAGE_VENDOR="phantomcortex"
ARG IMAGE_BRANCH="main"
ARG BASE_IMAGE_NAME="bazzite-gnome"
ARG VERSION_DATE="00000000"

# Copy pre-built mesa RPMs into the image so 05-mesa-install.sh can install them
# NOTE: must NOT be under /tmp — the main RUN step mounts /tmp as tmpfs, which
# would shadow anything COPY'd there.
#COPY --from=mesa-rpms /rpms/ /var/tmp/mesa-rpms/


# Cleanup & Finalize
COPY system_files/ /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    echo -e "\033[31mBUILD SCRIPT >>>>\033[0m" && \
    /ctx/02-build.sh && \
    echo -e "\033[31mOPT FIXER >>>>\033[0m" && \
    /ctx/03-fix-opt.sh && \
    echo -e "\033[31mSYSTEM CONFIG >>>>\033[0m" && \
    /ctx/04-config.sh && \
    echo -e "\033[31mREMOTE GRABBER >>>>\033[0m" && \
    /ctx/06-remote-grabber.sh && \
    echo -e "\033[31mIMAGE INFO >>>>\033[0m" && \
    /ctx/image-info && \
    echo -e "\033[31mOSTREE COMMIT\033[0m" && \
    ostree container commit


    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
