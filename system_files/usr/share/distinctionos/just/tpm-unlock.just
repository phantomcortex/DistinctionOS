# TPM2 LUKS Unlock Configuration

# NOTE: recipe written by Anthropic's Claude Opus 4.1
# At the time of writing: (September 7th, 2025) recipe is untested
distinction-tpm-unlock-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    
    # Colours for better readability
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Colour
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}     DistinctionOS TPM2 Unlock Configuration${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check for root privileges
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${YELLOW}This recipe requires root privileges. Elevating...${NC}"
        exec sudo "$0" "$@"
    fi
    
    # Check if system has TPM2
    if ! systemd-cryptenroll --tpm2-device=list &>/dev/null; then
        echo -e "${RED}❌ No TPM2 device found on this system!${NC}"
        exit 1
    fi
    
    # Detect encrypted partitions
    echo -e "${BLUE}→ Detecting encrypted partitions...${NC}"
    LUKS_DEVICES=$(lsblk -o NAME,FSTYPE,MOUNTPOINT | grep crypto_LUKS | awk '{print $1}' | sed 's/[├─└│]//g' | tr -d ' ')
    
    if [ -z "$LUKS_DEVICES" ]; then
        echo -e "${RED}❌ No LUKS encrypted devices found!${NC}"
        exit 1
    fi
    
    # Show found devices
    echo -e "${GREEN}✓ Found encrypted devices:${NC}"
    echo "$LUKS_DEVICES" | while read -r device; do
        echo "  • /dev/$device"
    done
    echo ""
    
    # Interactive PCR bank selection
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                PCR Bank Selection${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "PCR banks determine what system changes will require re-entering your password:"
    echo ""
    echo "  PCR 0:  Firmware (UEFI/BIOS version)"
    echo "  PCR 1:  Firmware configuration"
    echo "  PCR 2:  External code (Option ROMs)"
    echo "  PCR 3:  External code configuration"
    echo "  PCR 4:  Boot loader (GRUB/systemd-boot)"
    echo "  PCR 5:  Boot loader configuration"
    echo "  PCR 6:  Power state events"
    echo "  PCR 7:  Secure Boot state"
    echo "  PCR 8:  Kernel command line"
    echo "  PCR 9:  Kernel and initrd"
    echo ""
    
    # Preset configurations
    echo -e "${BLUE}Choose a preset configuration:${NC}"
    echo ""
    echo "  1) 🔒 Maximum Security (PCR 0,1,4,5,7,8,9)"
    echo "     → Requires password after ANY system change"
    echo ""
    echo "  2) ⚖️  Balanced (PCR 0,4,7,9)"
    echo "     → Firmware, bootloader, Secure Boot, kernel"
    echo ""
    echo "  3) 🔓 Convenience (PCR 7)"
    echo "     → Only Secure Boot state"
    echo ""
    echo "  4) 🎯 Custom"
    echo "     → Select your own PCR banks"
    echo ""
    
    read -p "Enter your choice (1-4): " PRESET_CHOICE
    
    case $PRESET_CHOICE in
        1)
            PCR_BANKS="0+1+4+5+7+8+9"
            echo -e "${GREEN}✓ Selected: Maximum Security${NC}"
            ;;
        2)
            PCR_BANKS="0+4+7+9"
            echo -e "${GREEN}✓ Selected: Balanced${NC}"
            ;;
        3)
            PCR_BANKS="7"
            echo -e "${GREEN}✓ Selected: Convenience${NC}"
            ;;
        4)
            echo ""
            echo "Enter PCR banks to use (comma-separated, e.g., 0,4,7,9):"
            read -p "PCR banks: " CUSTOM_PCRS
            PCR_BANKS=$(echo "$CUSTOM_PCRS" | tr ',' '+')
            echo -e "${GREEN}✓ Selected: Custom (PCR $PCR_BANKS)${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    
    # Check Secure Boot status
    echo -e "${BLUE}→ Checking Secure Boot status...${NC}"
    if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
        echo -e "${GREEN}✓ Secure Boot is ENABLED${NC}"
        SECURE_BOOT="enabled"
    else
        echo -e "${YELLOW}⚠ Secure Boot is DISABLED${NC}"
        SECURE_BOOT="disabled"
        
        if [[ "$PCR_BANKS" == *"7"* ]]; then
            echo -e "${YELLOW}  Warning: PCR 7 selected but Secure Boot is disabled!${NC}"
            echo -e "${YELLOW}  TPM unlock will break if you enable Secure Boot later.${NC}"
            read -p "Continue anyway? (y/N): " CONTINUE
            if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                echo -e "${RED}❌ Aborted by user${NC}"
                exit 1
            fi
        fi
    fi
    
    echo ""
    
    # Wipe existing TPM2 enrollments
    echo -e "${BLUE}→ Removing existing TPM2 enrollments...${NC}"
    for device in $LUKS_DEVICES; do
        echo "  Processing /dev/$device..."
        
        # Check current enrollments
        if systemd-cryptenroll /dev/$device --tpm2-device=list 2>/dev/null | grep -q "tpm2"; then
            echo "  → Wiping existing TPM2 enrollment..."
            systemd-cryptenroll /dev/$device --wipe-slot=tpm2
            echo -e "  ${GREEN}✓ Cleared${NC}"
        else
            echo "  → No existing TPM2 enrollment found"
        fi
    done
    
    echo ""
    
    # Enroll new TPM2 configuration
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}           Enrolling TPM2 Configuration${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}You will be prompted for your LUKS password for each device.${NC}"
    echo ""
    
    for device in $LUKS_DEVICES; do
        echo -e "${BLUE}→ Enrolling /dev/$device with PCR banks: $PCR_BANKS${NC}"
        
        if systemd-cryptenroll /dev/$device \
            --tpm2-device=auto \
            --tpm2-pcrs="$PCR_BANKS"; then
            echo -e "${GREEN}✓ Successfully enrolled /dev/$device${NC}"
        else
            echo -e "${RED}❌ Failed to enroll /dev/$device${NC}"
            echo "  You may need to manually unlock and try again."
        fi
        echo ""
    done
    
    # Update crypttab
    echo -e "${BLUE}→ Updating /etc/crypttab...${NC}"
    if [ -f /etc/crypttab ]; then
        cp /etc/crypttab /etc/crypttab.bak
        echo -e "${GREEN}✓ Backup created: /etc/crypttab.bak${NC}"
        
        # Add tpm2-device=auto option to crypttab entries
        sed -i 's/\(luks\),\?/\1,tpm2-device=auto/' /etc/crypttab
        echo -e "${GREEN}✓ Updated /etc/crypttab${NC}"
    else
        echo -e "${YELLOW}⚠ /etc/crypttab not found - manual configuration may be needed${NC}"
    fi
    
    # Rebuild initramfs
    echo ""
    echo -e "${BLUE}→ Rebuilding initramfs...${NC}"
    if command -v dracut &>/dev/null; then
        dracut -f
        echo -e "${GREEN}✓ Initramfs rebuilt${NC}"
    else
        echo -e "${YELLOW}⚠ Dracut not found - please rebuild initramfs manually${NC}"
    fi
    
    # Save configuration
    echo ""
    echo -e "${BLUE}→ Saving configuration...${NC}"
    mkdir -p /var/lib/distinction-tpm
    cat > /var/lib/distinction-tpm/config <<EOF
# DistinctionOS TPM Configuration
# Generated: $(date)
PCR_BANKS="$PCR_BANKS"
SECURE_BOOT="$SECURE_BOOT"
LUKS_DEVICES="$LUKS_DEVICES"
EOF
    chmod 600 /var/lib/distinction-tpm/config
    echo -e "${GREEN}✓ Configuration saved to /var/lib/distinction-tpm/config${NC}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}     ✅ TPM2 Unlock Configuration Complete!${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot your system to test TPM unlock"
    echo "  2. If unlock fails, use your password as fallback"
    echo "  3. Run 'distinction-tpm-verify' to check status"
    echo ""
    echo -e "${YELLOW}Remember: System updates affecting your selected PCR banks${NC}"
    echo -e "${YELLOW}will require re-entering your password once.${NC}"

# Verify TPM unlock status
distinction-tpm-verify:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔍 TPM2 Unlock Status Check"
    echo "═══════════════════════════════"
    echo ""
    
    # Check TPM2 availability
    echo "→ TPM2 Device:"
    if systemd-cryptenroll --tpm2-device=list &>/dev/null; then
        systemd-cryptenroll --tpm2-device=list
    else
        echo "  ❌ No TPM2 device found!"
    fi
    echo ""
    
    # Check enrolled devices
    echo "→ LUKS Devices with TPM2 enrollment:"
    FOUND_TPM=false
    for device in $(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print $1}' | sed 's/[├─└│]//g' | tr -d ' '); do
        echo -n "  • /dev/$device: "
        if systemd-cryptenroll /dev/$device --tpm2-device=list 2>/dev/null | grep -q "tpm2"; then
            echo "✅ TPM2 enrolled"
            FOUND_TPM=true
        else
            echo "❌ No TPM2 enrollment"
        fi
    done
    
    if [ "$FOUND_TPM" = false ]; then
        echo ""
        echo "⚠ No TPM2 enrollments found. Run 'ujust distinction-tpm-unlock-setup' to configure."
    fi
    
    # Check saved configuration
    echo ""
    echo "→ Saved Configuration:"
    if [ -f /var/lib/distinction-tpm/config ]; then
        cat /var/lib/distinction-tpm/config | sed 's/^/  /'
    else
        echo "  No configuration file found"
    fi

# Reset TPM unlock (requires authentication)
distinction-tpm-reset:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "🔄 TPM2 Unlock Reset"
    echo "═══════════════════════════════"
    echo ""
    echo "⚠ This will remove all TPM2 enrollments and require reconfiguration."
    echo ""
    
    # Require authentication
    read -sp "Enter your user password to continue: " USER_PASS
    echo ""
    
    # Verify password using sudo
    if ! echo "$USER_PASS" | sudo -S true 2>/dev/null; then
        echo "❌ Authentication failed!"
        exit 1
    fi
    
    echo "✓ Authentication successful"
    echo ""
    
    # Remove all TPM2 enrollments
    echo "→ Removing TPM2 enrollments..."
    for device in $(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print $1}' | sed 's/[├─└│]//g' | tr -d ' '); do
        echo "  • /dev/$device"
        sudo systemd-cryptenroll /dev/$device --wipe-slot=tpm2 2>/dev/null || true
    done
    
    # Remove configuration
    sudo rm -f /var/lib/distinction-tpm/config
    
    echo ""
    echo "✅ TPM2 configuration reset complete."
    echo "Run 'ujust distinction-tpm-unlock-setup' to reconfigure."
