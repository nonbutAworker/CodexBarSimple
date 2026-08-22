#!/bin/bash

set -euo pipefail

readonly repository="nonbutAworker/CodexBarSimple"
readonly archive_name="CodexBarSimple-macOS-arm64.zip"
readonly checksum_name="SHA256SUMS.txt"
readonly release_base="https://github.com/${repository}/releases/latest/download"

if [[ "$(/usr/bin/uname -s)" != "Darwin" ]]; then
    echo "CodexBarSimple supports macOS only." >&2
    exit 1
fi

if [[ "$(/usr/bin/uname -m)" != "arm64" ]]; then
    echo "CodexBarSimple currently supports Apple Silicon Macs only." >&2
    exit 1
fi

temporary_directory="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/codexbarsimple-install.XXXXXX")"

cleanup() {
    if [[ -n "${temporary_directory:-}" && -d "$temporary_directory" ]]; then
        /bin/rm -rf "$temporary_directory"
    fi
}
trap cleanup EXIT INT TERM

archive_path="$temporary_directory/$archive_name"
checksum_path="$temporary_directory/$checksum_name"
extract_directory="$temporary_directory/extracted"

echo "Downloading CodexBarSimple…"
/usr/bin/curl --fail --location --silent --show-error \
    "$release_base/$archive_name" \
    --output "$archive_path"
/usr/bin/curl --fail --location --silent --show-error \
    "$release_base/$checksum_name" \
    --output "$checksum_path"

expected_checksum="$(
    /usr/bin/awk -v archive="$archive_name" '$2 == archive { print $1; exit }' "$checksum_path"
)"
actual_checksum="$(/usr/bin/shasum -a 256 "$archive_path" | /usr/bin/awk '{ print $1 }')"

if [[ -z "$expected_checksum" || "$actual_checksum" != "$expected_checksum" ]]; then
    echo "The downloaded package failed checksum verification. Please try again later." >&2
    exit 1
fi

/bin/mkdir -p "$extract_directory"
/usr/bin/ditto -x -k "$archive_path" "$extract_directory"

installer_path="$extract_directory/Install CodexBarSimple.command"
if [[ ! -f "$installer_path" ]]; then
    echo "The downloaded package is incomplete." >&2
    exit 1
fi

/bin/chmod 755 "$installer_path"
/bin/zsh "$installer_path"

echo "CodexBarSimple is installed and running. Your remaining usage is now visible in the menu bar."
