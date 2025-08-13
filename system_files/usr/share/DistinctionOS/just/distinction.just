# Install all distinction OS curated apps
distinction-install: distinction-install-flatpaks distinction-install-brews distinction-install-custom-shell distinction-install-nvchad

# Installs shell and terminal related things
distinction-install-shell: distinction-install-custom-shell distinction-install-nvchad

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
    echo "build tldr cache..."
    tldr --update
    echo "Homebrews installation complete."
    
# custom shell
distinction-install-custom-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Installing custom shell"
    sleep 2
    echo "STEP: Change shell to zsh"
    sleep 2
    sudo chsh -s /usr/bin/zsh $USER
    sudo chsh -s /usr/bin/zsh root
    echo "This may take effect after you reboot"
    sleep 2
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/phantomcortex/dotfiles/main/install_new.sh)"
    sleep 2
    echo "apply to root"
    sudo cp -r ~/.dotfiles /root/
    echo "Install complete"
    
#neovim environment
distinction-install-nvchad:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing NVChad"
  # check if neovim is installed:::brew:or:layered
  if [ ! -f /home/linuxbrew/.linuxbrew/bin/nvim] && [ ! -f /usr/bin/nvim ]; then
    echo -e "\033[34m...nvim is not installed\033[0m"
    brew install neovim  
  fi
  git clone https://github.com/NvChad/starter ~/.config/nvim && nvim
  sleep 5
  echo "Install to root user"
  sudo cp -r ~/.config/nvim /root/.config/
  sudo cp -r~/.local/share/nvim /root/.local/share/

  echo "Install complete"

#install nautilus scripts
distinction-install-nautilus-scripts:
  #!/usr/bin/env bash
  set -euo pipefail

  echo "Installing nautilus scripts"
  git clone https://github.com/cfgnunes/nautilus-scripts.git /tmp/nautilus-scripts
  bash /tmp/nautilus-scripts/install.sh
  rm -rf /tmp/nautilus-scripts
