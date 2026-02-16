#!/bin/bash
# lib.sh — shared library for debian-supplement provisioning scripts.
# Source this file; do not execute it directly.

# Include guard
[[ -n "${_LIB_SH_SOURCED:-}" ]] && return
readonly _LIB_SH_SOURCED=1

# ---------------------------------------------------------------------------
# Color constants
# ---------------------------------------------------------------------------
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()  { echo -e "${BLUE}[STEP]${NC} $*"; }

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

# Check if a command is available.
command_exists() {
    command -v "$1" &>/dev/null
}

# Return 0 (true) if $1 >= $2 using version-sort comparison.
version_gte() {
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

# Detect CPU architecture, normalised to the names used by GitHub releases.
# Exits with an error on unsupported architectures.
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64)  echo "x86_64"  ;;
        aarch64) echo "aarch64" ;;
        *)
            log_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

# Unified download helper.  Prefers wget (proxy-friendly), falls back to curl.
#   download <url> <output_file>
download() {
    local url="$1"
    local output="$2"
    if command_exists wget; then
        wget -O "$output" "$url"
    elif command_exists curl; then
        curl -Lo "$output" "$url"
    else
        log_error "Neither wget nor curl found — cannot download files"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Temp-file tracking for trap-based cleanup
# ---------------------------------------------------------------------------
_TEMP_FILES=()

# Register a temporary file for automatic cleanup.
register_temp() {
    _TEMP_FILES+=("$1")
}

# Remove all registered temporary files.  Safe to call multiple times.
cleanup_temp() {
    local f
    for f in "${_TEMP_FILES[@]+"${_TEMP_FILES[@]}"}"; do
        rm -f "$f"
    done
    _TEMP_FILES=()
}
