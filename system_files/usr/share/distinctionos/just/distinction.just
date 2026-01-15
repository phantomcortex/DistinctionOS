# Install all distinction OS curated apps
distinction-install: distinction-install-flatpaks distinction-install-brews distinction-install-custom-shell distinction-install-nvchad
    @echo "✅ All DistinctionOS components installed successfully!"

# Installs shell and terminal related things such as nvchad
distinction-install-shell: distinction-install-custom-shell distinction-install-nvchad
    @echo "✅ Shell environment setup complete!"

# Install only Flatpaks
distinction-install-flatpaks:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📦 Installing Flatpaks..."
    
    # Fetch and install flatpaks
    if curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/flatpaks | xargs flatpak --system -y install; then
        echo "✓ Flatpaks installed successfully"
    else
        echo "⚠ Some flatpaks may have failed to install"
    fi
    
    # Apply overrides for theming
    echo "🎨 Applying theme overrides..."
    sudo flatpak override --filesystem=xdg-config/gtk-3.0
    sudo flatpak override --filesystem=xdg-config/gtk-4.0
    sudo flatpak override --filesystem=$XDG_DATA_HOME/icons:ro
    
    echo "✅ Flatpaks installation complete."

# Install only Homebrews
distinction-install-brews:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🍺 Installing Homebrews..."
    
    # Check if brew is available
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first."
        exit 1
    fi
    
    # Install packages from list
    if curl --retry 3 -sL https://raw.githubusercontent.com/phantomcortex/distinction-ublue-internal/main/repo_files/brews | xargs brew install; then
        echo "✓ Brew packages installed"
    else
        echo "⚠ Some packages may have failed"
    fi
    
    # Build tldr cache
    echo "📚 Building tldr cache..."
    if command -v tldr &> /dev/null; then
        tldr --update
        echo "✓ tldr cache updated"
    fi
    
    echo "✅ Homebrews installation complete."

# Custom shell configuration
distinction-install-custom-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🐚 Installing custom shell configuration..."
    
    # Change shell to zsh
    echo "→ Changing shell to zsh..."
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        sudo chsh -s /usr/bin/zsh $USER
        echo "✓ User shell changed to zsh"
    else
        echo "✓ Shell already set to zsh"
    fi
    
    # Set root shell
    sudo chsh -s /usr/bin/zsh root
    echo "✓ Root shell changed to zsh"
    
    # Install dotfiles
    echo "→ Installing dotfiles..."
    if [ ! -d ~/.dotfiles ]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/phantomcortex/dotfiles/main/install_claude.sh)"
        echo "✓ Dotfiles installed"
    else
        echo "✓ Dotfiles already present"
    fi
    
    # Link zshrc if needed
    if [ -e ~/.dotfiles/.zshrc ] && [ ! -e ~/.zshrc ]; then
        ln -s ~/.dotfiles/.zshrc ~/.zshrc
        echo "✓ .zshrc linked"
    fi
    
    # Copy to root (preserving structure)
    echo "→ Applying configuration to root..."
    sudo cp -r ~/.dotfiles /root/
    [ -e /root/.zshrc ] || sudo ln -s /root/.dotfiles/.zshrc /root/.zshrc
    
    echo "✅ Shell configuration complete. Restart your terminal to apply changes."

# Neovim environment with NvChad
distinction-install-nvchad:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📝 Installing NvChad..."
    
    # Check if neovim is installed
    if [ ! -f /home/linuxbrew/.linuxbrew/bin/nvim ] && [ ! -f /usr/bin/nvim ]; then
        echo "→ Installing Neovim via Homebrew..."
        brew install neovim
    else
        echo "✓ Neovim already installed"
    fi
    
    # Install NvChad for user
    if [ ! -d ~/.config/nvim ]; then
        echo "→ Cloning NvChad configuration..."
        git clone https://github.com/NvChad/starter ~/.config/nvim
        echo "✓ NvChad installed for user"
        echo "  Run 'nvim' to complete setup"
    else
        echo "✓ NvChad configuration already exists"
    fi
    
    # Install for root user
    echo "→ Installing NvChad for root..."
    sudo mkdir -p /root/.config /root/.local/share
    [ -d /root/.config/nvim ] || sudo cp -r ~/.config/nvim /root/.config/
    [ -d /root/.local/share/nvim ] || sudo cp -r ~/.local/share/nvim /root/.local/share/ 2>/dev/null || true
    
    echo "✅ NvChad installation complete."

# Install nautilus scripts
distinction-install-nautilus-scripts:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "📂 Installing Nautilus scripts..."
    
    bash -c "$(curl -fsSL https://cfgnunes.github.io/nautilus-scripts/install.sh)" -- -n
