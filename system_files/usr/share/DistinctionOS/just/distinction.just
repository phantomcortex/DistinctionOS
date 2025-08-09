# Install all distinction OS curated apps
distinction-install: distinction-install-flatpaks distinction-install-brews distinction-install-custom-shell distinction-install-nvchad

# Installs shell and terminal related things
distinction-install-shell-configuration: distinction-install-custom-shell distinction-install-nvchad

# Install only Flatpaks
distinction-install-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing Flatpaks..."
    xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/flatpaks) flatpak --system -y install
    sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0 sudo flatpak override --filesystem=$XDG_DATA_HOME/icons:ro
    echo "Flatpaks installation complete."

# Install only Homebrews
distinction-install-brews:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing Homebrews..."
    xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/brews) brew install
    echo "Homebrews installation complete."
    
# custom shell
distinction-install-custom-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Installing oh-my-zsh!"
    git clone https://github.com/phantomcortex/dotfiles.git ~/.dotfiles
    bash ~/.dotfiles/install.sh
    #sh -c "$(curl -fsSL https://raw.githubusercontent.com/phantomcortex/dotfiles/master/tools/install.sh)"
    echo "Install complete"
    
#neovim environment
distinction-install-nvchad:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing NVChad"
  git clone https://github.com/NvChad/starter ~/.config/nvim && nvim
  echo "Install complete"

#install nautilus scripts
distinction-install-nautilus-scripts:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing nautilus scripts"
  git clone https://github.com/cfgnunes/nautilus-scripts.git /tmp/nautilus-scripts
  bash /tmp/nautilus-scripts/install.sh
  rm -rf /tmp/nautilus-scripts
