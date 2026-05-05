#!/usr/bin/env bash
# Build an Adrenotools-style zip with meta.json and an optional placeholder lib layout.
#
# Usage:
#   package-gamenative-zip.sh [-p] [-o path] [--name STR] [--library-name STR] [--driver-version STR]
#
#   -p    Add lib/<libraryName> plus share/vulkan/icd.d/placeholder_icd.json referencing it.
#
# meta.json: name, libraryName, driverVersion; optional driverStack ("panvk"|"adrenotools"),
# icdRelativePath, libDirRelative for PanVK / VK_ICD_FILENAMES layout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

OUT_ZIP="${PWD}/gamenative-mesa-driver.zip"
NAME="gamenative-mesa"
LIBRARY_NAME="libvulkan_panfrost.so"
DRIVER_VERSION="0.0.0-local"
DRIVER_STACK="panvk"
PLACEHOLDER=0

while [[ "${#}" -gt 0 ]]; do
  case "$1" in
    -p) PLACEHOLDER=1; shift ;;
    -o)
      OUT_ZIP="$2"
      shift 2
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --library-name)
      LIBRARY_NAME="$2"
      shift 2
      ;;
    --driver-version)
      DRIVER_VERSION="$2"
      shift 2
      ;;
    --driver-stack)
      DRIVER_STACK="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '1,25p' "$0" >&2
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

TMP="$(mktemp -d)"
cleanup() { rm -rf "${TMP}"; }
trap cleanup EXIT

export TMP NAME LIBRARY_NAME DRIVER_VERSION DRIVER_STACK
python3 - <<'PY'
import json, os
root = os.environ["TMP"]
payload = {
    "name": os.environ["NAME"],
    "libraryName": os.environ["LIBRARY_NAME"],
    "driverVersion": os.environ["DRIVER_VERSION"],
    "driverStack": os.environ["DRIVER_STACK"],
    "icdRelativePath": "share/vulkan/icd.d/panfrost_icd.aarch64.json",
    "libDirRelative": "lib",
}
with open(os.path.join(root, "meta.json"), "w", encoding="utf-8") as f:
    json.dump(payload, f, indent=2)
    f.write("\n")
PY

if [[ "${PLACEHOLDER}" -eq 1 ]]; then
  mkdir -p "${TMP}/lib" "${TMP}/share/vulkan/icd.d"
  printf 'placeholder shared-object stub (not a real ELF); for path/layout tests only\n' \
    > "${TMP}/lib/${LIBRARY_NAME}"
  python3 - <<PY
import json, os
lib = os.environ["LIBRARY_NAME"]
root = os.environ["TMP"]
icd = {
    "file_format_version": "1.0.0",
    "ICD": {
        "library_path": f"../../lib/{lib}",
        "api_version": "1.3.0",
    },
}
path = os.path.join(root, "share", "vulkan", "icd.d", "placeholder_icd.json")
with open(path, "w", encoding="utf-8") as f:
    json.dump(icd, f, indent=2)
    f.write("\n")
PY
fi

(
  cd "${TMP}"
  zip -qr "${OUT_ZIP}" .
)

echo "wrote ${OUT_ZIP}"
