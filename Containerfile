# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:stable as DistinctionOS
#FROM quay.io/fedora/fedora-bootc:42



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
    echo -e "\033[31mOSTREE COMMIT\033[0m" && \
    ostree container commit


    
### LINTING
## Verify final image and contents are correct.
#RUN bootc container lint
