#!/usr/bin/env bash
# Rebuilds Pulse and relaunches it. Usage: scripts/run.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/build.sh "${1:-release}"
pkill -x Pulse 2>/dev/null || true
open build/Pulse.app
