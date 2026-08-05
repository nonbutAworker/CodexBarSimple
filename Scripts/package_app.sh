#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
configuration="${1:-release}"
app_dir="${project_dir}/CodexBarSimple.app"

cd "${project_dir}"
swift build -c "${configuration}" --product CodexBarSimple
binary_dir="$(swift build -c "${configuration}" --show-bin-path)"

rm -rf "${app_dir}"
mkdir -p "${app_dir}/Contents/MacOS"
install -m 755 "${binary_dir}/CodexBarSimple" "${app_dir}/Contents/MacOS/CodexBarSimple"
install -m 644 "${project_dir}/Support/Info.plist" "${app_dir}/Contents/Info.plist"

resource_bundle="${binary_dir}/CodexBarSimple_CodexBarSimple.bundle"
if [[ -d "${resource_bundle}" ]]; then
    mkdir -p "${app_dir}/Contents/Resources"
    cp -R "${resource_bundle}" "${app_dir}/Contents/Resources/"
fi

codesign --force --sign - --timestamp=none "${app_dir}"

echo "Packaged ${app_dir}"
