#!/bin/sh
# DistinctionOS dnf / dnf5 guard — route interactive shells through the
# read-only wrapper so live install attempts get an instructive refusal
# rather than a cryptic EROFS deep inside a transaction.
#
# Direct /usr/bin/dnf and /usr/bin/dnf5 invocations bypass these aliases
# intentionally — they are the escape hatch for scripts that have already
# unlocked the deployment.

alias dnf='/usr/bin/distinction-dnf'
alias dnf5='/usr/bin/distinction-dnf'

# Preserve aliases through sudo so `sudo dnf install foo` is also caught
# in interactive shells. Trailing space tells bash/zsh to expand the next
# word as an alias too.
alias sudo='sudo '
