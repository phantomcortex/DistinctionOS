#!/bin/bash 
set -euo pipefail

# ============================================================================
# Custom Kernel Installer
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

for pkg in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-devel-matched kernel-modules-akmods; do 
  rpm --erase $pkg --nodeps
done 

pushd /usr/lib/kernel/install.d 
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install 
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install 
chmod +x 05-rpmostree.install 50-dracut.install 
popd

dnf5 -y copr enable bieszczaders/kernel-cachyos
dnf5 -y install kernel-cachyos kernel-cachyos-devel-matched
dnf5 -y copr disable bieszczaders/kernel-cachyos
dnf5 versionlock add kernel-cachyos
