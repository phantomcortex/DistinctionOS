# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Pre-cached RPMs — packages that install cleanly but live on custom or at-risk remotes.
# Built by .github/workflows/build-cache.yml, pushed to GHCR on demand.
# Artifacts are tagged both `:latest` (rolling) and `:YYYYMMDD` (pinned).
# For reproducible builds, replace `:latest` with a specific date tag.
#FROM ghcr.io/phantomcortex/distinctionos-cache:latest AS cache-rpms

# Force-install RPMs — packages requiring rpm --force --nodeps due to file conflicts.
# Built by .github/workflows/build-force-install.yml, pushed to GHCR on demand.
# Artifacts are tagged both `:latest` (rolling) and `:YYYYMMDD` (pinned).
# For reproducible builds, replace `:latest` with a specific date tag.
#FROM ghcr.io/phantomcortex/distinctionos-force-install:latest AS force-install-rpms

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:testing as DistinctionOS
#FROM quay.io/fedora/fedora-bootc:42

ARG IMAGE_NAME="distinctionos"
ARG IMAGE_VENDOR="phantomcortex"
ARG IMAGE_BRANCH="main"
ARG BASE_IMAGE_NAME="bazzite-gnome"
ARG VERSION_DATE="00000000"

# Pre-cached RPMs (must NOT be under /tmp — tmpfs mount would shadow them)
#COPY --from=cache-rpms /rpms/ /var/tmp/cache-rpms/

# Force-install RPMs (must NOT be under /tmp — tmpfs mount would shadow them)
#COPY --from=force-install-rpms /rpms/ /var/tmp/force-install-rpms/


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
    echo -e "\033[31mCACHE INSTALL >>>>\033[0m" && \
    /ctx/05-cache-install.sh && \
    echo -e "\033[31mREMOTE GRABBER >>>>\033[0m" && \
    /ctx/06-remote-grabber.sh && \
    echo -e "\033[31mFORCE INSTALL >>>>\033[0m" && \
    /ctx/07-force-install.sh && \
    echo -e "\033[31mVALIDATE >>>>\033[0m" && \
    /ctx/08-validate.sh && \
    echo -e "\033[31mIMAGE INFO >>>>\033[0m" && \
    /ctx/image-info && \
    echo -e "\033[31mOSTREE COMMIT\033[0m" && \
    ostree container commit


    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
