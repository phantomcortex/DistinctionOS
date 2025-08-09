# Install all distinction OS curated apps
distinction-install: distinction-install-flatpaks distinction-install-brews distinction-install-omz distinction-install-p10k distinction-install-nvchad

# Installs shell and terminal related things
distinction-install-shell-configuration: distinction-install-omz distinction-install-p10k distinction-install-nvchad

# Install only Flatpaks
distinction-install-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing Flatpaks..."
    xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/flatpaks) flatpak --system -y install
    echo "Flatpaks installation complete."

# Install only Homebrews
distinction-install-brews:
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Installing Homebrews..."
    xargs -a <(curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/brews) brew install
    echo "Homebrews installation complete."
    
# shell enhancements
distinction-install-omz:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Installing oh-my-zsh!"
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    
    echo "Install complete"
    
#zsh theme
distinction-install-p10k:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Installing powerlevel10k"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    wget https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/system_files/etc/skel/.zshrc "~/.zshrc"
    echo "Install complete"

#neovim environment
distinction-install-nvchad:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing NVChad"
   clear -x && read -n 1 -p "nvim will configure it itself for a few seconds...\n After it's done please enter ':MasonInstallAll' matching exactly!"
  git clone https://github.com/NvChad/starter ~/.config/nvim && nvim
   echo "Install complete"
