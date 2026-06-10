#!/bin/bash 
set -euo pipefail

# ============================================================================
# Custom Kernel Installer
# ============================================================================

# Source utility functions
source /ctx/95-utility-functions.sh

for pkg in kernel kernel-core kernel-modules kernel-devel-matched; do 
  rpm --erase $pkg --nodeps
done 

pushd /usr/lib/kernel/install.d 
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install 
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install 
chmod +x 05-rpmostree.install 50-dracut.install 
popd

dnf5 -y copr enable bieszczaders/kernel-cachyos-lto
dnf5 -y install kernel-cachyos-lto kernel-cachyos-lto-devel-matched
dnf5 -y copr disable bieszczaders/kernel-cachyos-lto
