# Quick maintenance commands for TPM management

# Quick re-enrollment after system update
distinction-tpm-reenrol:
    #!/usr/bin/env bash
    echo "🔄 Quick TPM Re-enrollment"
    echo "══════════════════════════"
    sudo distinction-tpm-monitor --reenrol

# Check if re-enrollment is needed
distinction-tpm-check:
    #!/usr/bin/env bash
    echo "🔍 Checking for system changes..."
    if sudo distinction-tpm-monitor --check; then
        echo "⚠ Changes detected - TPM re-enrollment recommended!"
        echo "Run: ujust distinction-tpm-reenrol"
    else
        echo "✅ No changes detected - TPM unlock should work fine"
    fi

# Force immediate check (useful after manual updates)
distinction-tpm-force-check:
    #!/usr/bin/env bash
    echo "🔄 Forcing TPM monitor check..."