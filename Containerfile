# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image
FROM ghcr.io/ublue-os/bazzite-gnome:latest as distinction
#FROM quay.io/fedora/fedora-bootc:42


## Other possible base images include:
# FROM ghcr.io/ublue-os/bazzite:latest
# FROM ghcr.io/ublue-os/bluefin-nvidia:stable
# 
# ... and so on, here are more base images
# Universal Blue Images: https://github.com/orgs/ublue-os/packages
# Fedora base image: quay.io/fedora/fedora-bootc:41
# CentOS base images: quay.io/centos-bootc/centos-bootc:stream10

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

# Setup Copr repos

# Cleanup & Finalize
COPY system_files/ /
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    echo -e "\033[31mBUILD SCRIPT >>>>\033[0m" && \
    /ctx/build.sh && \ 
    /ctx/kernel_modules.sh && \
    echo -e "\033[31mREMOTE GRABBER >>>>\033[0m" && \
    /ctx/remote_grabber.sh && \
     echo -e "\033[31mWINE INSTALLER >>>>\033[0m" && \
    /ctx/wine-installer.sh && \
    echo -e "\033[31mOSTREE COMMIT\033[0m" && \
    ostree container commit


    
### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
