#!/usr/bin/env bash
# File: system_files/usr/bin/distinction-tpm-monitor
# DistinctionOS TPM Recovery Monitor
# Detects system changes that will break TPM unlock and proactively re-enrols

set -euo pipefail

# Configuration
CONFIG_FILE="/var/lib/distinction-tpm/config"
STATE_FILE="/var/lib/distinction-tpm/state"
CHECKSUM_FILE="/var/lib/distinction-tpm/checksums"
LOG_FILE="/var/log/distinction-tpm-monitor.log"

# Colours for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running interactively
is_interactive() {
    [ -t 0 ] && [ -t 1 ]
}

# Send notification to user
send_notification() {
    local urgency="$1"
    local summary="$2"
    local body="$3"
    
    # Try to send desktop notification if we have a display
    if [ -n "${DISPLAY:-}" ] && command -v notify-send &>/dev/null; then
        notify-send --urgency="$urgency" "$summary" "$body"
    fi
    
    # Also log to systemd journal
    echo "$summary: $body" | systemd-cat -t "distinction-tpm-monitor" -p "${urgency,,}"
}

# Calculate checksums of critical boot components
calculate_checksums() {
    local temp_file=$(mktemp)
    
    # Kernel and initrd (affects PCR 9)
    if [ -f /boot/vmlinuz ]; then
        sha256sum /boot/vmlinuz >> "$temp_file"
    fi
    if [ -f /boot/initramfs.img ]; then
        sha256sum /boot/initramfs.img >> "$temp_file"
    fi
    
    # Bootloader files (affects PCR 4, 5)
    if [ -d /boot/efi/EFI ]; then
        find /boot/efi/EFI -type f -name "*.efi" -exec sha256sum {} \; >> "$temp_file"
    fi
    if [ -f /boot/grub2/grub.cfg ]; then
        sha256sum /boot/grub2/grub.cfg >> "$temp_file"
    fi
    
    # UEFI firmware version (affects PCR 0)
    if command -v dmidecode &>/dev/null; then
        dmidecode -s bios-version 2>/dev/null | sha256sum >> "$temp_file"
    fi
    
    # Secure Boot state (affects PCR 7)
    mokutil --sb-state 2>/dev/null | sha256sum >> "$temp_file"
    
    # rpm-ostree deployment checksum
    if command -v rpm-ostree &>/dev/null; then
        rpm-ostree status --json | jq -r '.deployments[0].checksum' | sha256sum >> "$temp_file"
    fi
    
    echo "$temp_file"
}

# Check if boot components have changed
check_for_changes() {
    local current_checksums=$(calculate_checksums)
    local changes_detected=false
    local change_list=""
    
    # Create state directory if it doesn't exist
    mkdir -p "$(dirname "$CHECKSUM_FILE")"
    
    # First run - just save checksums
    if [ ! -f "$CHECKSUM_FILE" ]; then
        mv "$current_checksums" "$CHECKSUM_FILE"
        log_message "Initial checksums saved"
        return 1
    fi
    
    # Compare checksums
    if ! diff -q "$CHECKSUM_FILE" "$current_checksums" &>/dev/null; then
        changes_detected=true
        
        # Identify what changed
        if ! grep -q "$(sha256sum /boot/vmlinuz 2>/dev/null)" "$CHECKSUM_FILE" 2>/dev/null; then
            change_list="${change_list}• Kernel updated\n"
        fi
        
        if ! grep -q "$(sha256sum /boot/initramfs.img 2>/dev/null)" "$CHECKSUM_FILE" 2>/dev/null; then
            change_list="${change_list}• Initramfs updated\n"
        fi
        
        if [ -d /boot/efi/EFI ]; then
            local current_efi=$(find /boot/efi/EFI -type f -name "*.efi" -exec sha256sum {} \; | sha256sum)
            local saved_efi=$(grep "\.efi" "$CHECKSUM_FILE" | sha256sum)
            if [ "$current_efi" != "$saved_efi" ]; then
                change_list="${change_list}• Bootloader updated\n"
            fi
        fi
        
        local current_sb=$(mokutil --sb-state 2>/dev/null | sha256sum)
        local saved_sb=$(tail -2 "$CHECKSUM_FILE" | head -1)
        if [ "$current_sb" != "$saved_sb" ]; then
            change_list="${change_list}• Secure Boot state changed\n"
        fi
    fi
    
    rm -f "$current_checksums"
    
    if [ "$changes_detected" = true ]; then
        echo -e "$change_list"
        return 0
    else
        return 1
    fi
}

# Check for pending rpm-ostree deployment
check_pending_deployment() {
    if ! command -v rpm-ostree &>/dev/null; then
        return 1
    fi
    
    local deployments=$(rpm-ostree status --json | jq '.deployments | length')
    if [ "$deployments" -gt 1 ]; then
        local pending=$(rpm-ostree status --json | jq -r '.deployments[1].booted')
        if [ "$pending" = "false" ]; then
            return 0
        fi
    fi
    return 1
}

# Re-enrol TPM with user authentication
reenrol_tpm() {
    local pcr_banks=""
    local luks_devices=""
    
    # Load saved configuration
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        pcr_banks="${PCR_BANKS:-7}"
        luks_devices="${LUKS_DEVICES:-}"
    else
        log_message "ERROR: No saved TPM configuration found"
        return 1
    fi
    
    # If no devices configured, detect them
    if [ -z "$luks_devices" ]; then
        luks_devices=$(lsblk -o NAME,FSTYPE | grep crypto_LUKS | awk '{print $1}' | sed 's/[├─└│]//g' | tr -d ' ')
    fi
    
    log_message "Re-enrolling TPM with PCR banks: $pcr_banks"
    
    # Request authentication
    if is_interactive; then
        echo -e "${YELLOW}System changes detected that will break TPM unlock.${NC}"
        echo -e "${YELLOW}TPM re-enrollment required.${NC}"
        echo ""
        read -sp "Enter your LUKS password: " LUKS_PASS
        echo ""
    else
        # Non-interactive mode - send notification and exit
        send_notification "critical" "TPM Re-enrollment Required" \
            "System changes detected. Run 'sudo distinction-tpm-monitor --reenrol' to fix TPM unlock before rebooting."
        return 1
    fi
    
    # Re-enrol each device
    local success=true
    for device in $luks_devices; do
        log_message "Re-enrolling /dev/$device..."
        
        # Wipe existing TPM slot
        echo "$LUKS_PASS" | systemd-cryptenroll /dev/$device --wipe-slot=tpm2 2>/dev/null || true
        
        # Enrol new configuration
        if echo "$LUKS_PASS" | systemd-cryptenroll /dev/$device \
            --tpm2-device=auto \
            --tpm2-pcrs="$pcr_banks" 2>/dev/null; then
            log_message "Successfully re-enrolled /dev/$device"
        else
            log_message "ERROR: Failed to re-enrol /dev/$device"
            success=false
        fi
    done
    
    # Clear password from memory
    unset LUKS_PASS
    
    if [ "$success" = true ]; then
        # Update checksums to new state
        local new_checksums=$(calculate_checksums)
        mv "$new_checksums" "$CHECKSUM_FILE"
        log_message "TPM re-enrollment complete and checksums updated"
        send_notification "normal" "TPM Re-enrollment Successful" \
            "Your system will unlock automatically after the next reboot."
        return 0
    else
        log_message "ERROR: TPM re-enrollment failed"
        return 1
    fi
}

# Main monitoring function
monitor_mode() {
    log_message "Starting TPM monitor service"
    
    while true; do
        # Check for changes
        if changes=$(check_for_changes); then
            log_message "Boot component changes detected:"
            echo "$changes" | while read -r line; do
                [ -n "$line" ] && log_message "  $line"
            done
            
            # Check if this is from a pending deployment
            if check_pending_deployment; then
                log_message "Changes are from pending rpm-ostree deployment"
                send_notification "critical" "TPM Unlock Will Break on Next Boot" \
                    "System update detected. Run 'sudo distinction-tpm-monitor --reenrol' before rebooting to maintain TPM unlock."
            else
                log_message "Changes detected in current deployment"
                send_notification "urgent" "TPM Configuration May Be Broken" \
                    "Boot components have changed. You may need to re-enrol TPM."
            fi
            
            # Try to auto-reenrol if we have saved credentials (future feature)
            # For now, just alert the user
        fi
        
        # Sleep for 5 minutes before next check
        sleep 300
    done
}

# Interactive re-enrollment mode
interactive_reenrol() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}     DistinctionOS TPM Recovery Tool${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check what changed
    if changes=$(check_for_changes); then
        echo -e "${YELLOW}The following changes were detected:${NC}"
        echo -e "$changes"
    else
        echo -e "${GREEN}✓ No system changes detected${NC}"
        echo ""
        read -p "Re-enrol anyway? (y/N): " FORCE
        if [[ ! "$FORCE" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    echo ""
    reenrol_tpm
}

# Parse command line arguments
case "${1:-}" in
    --monitor)
        monitor_mode
        ;;
    --reenrol|--re-enrol)
        interactive_reenrol
        ;;
    --check)
        if changes=$(check_for_changes); then
            echo "Changes detected:"
            echo "$changes"
            exit 0
        else
            echo "No changes detected"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [--monitor|--reenrol|--check]"
        echo ""
        echo "  --monitor   Run as daemon, monitoring for changes"
        echo "  --reenrol   Interactively re-enrol TPM"
        echo "  --check     Check for changes and exit"
        exit 1
        ;;
esac