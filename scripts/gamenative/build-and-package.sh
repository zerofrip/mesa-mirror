#!/usr/bin/env bash
# Build one backend and package a GameNative ZIP from actual build outputs.
#
# Usage:
#   build-and-package.sh <panvk|freedreno|virpipe> <driver-version> [out-dir]
#
# Output:
#   <out-dir>/gamenative-<backend>-<driver-version>.zip
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  echo "Usage: $0 <panvk|freedreno|virpipe> <driver-version> [out-dir]" >&2
  exit 1
}

[[ "${#}" -ge 2 ]] || usage
BACKEND="$1"
VERSION="$2"
OUT_DIR="${3:-${MESA_ROOT}/dist-gamenative}"
require_backend "${BACKEND}"
require_ndk

mkdir -p "${OUT_DIR}"
OUT_DIR="$(realpath -m "${OUT_DIR}")"

BUILD_DIR="${MESA_ROOT}/build-gamenative-${BACKEND}"
"${SCRIPT_DIR}/build-backend.sh" "${BACKEND}" "${BUILD_DIR}"

tmp="$(mktemp -d)"
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

zip_name="gamenative-${BACKEND}-${VERSION}.zip"
zip_path="${OUT_DIR}/${zip_name}"

find_one() {
  local pattern="$1"
  python3 - <<PY
import os
import re
import sys

build_dir = ${BUILD_DIR@Q}
pattern = re.compile(${pattern@Q})

for root, _, files in os.walk(build_dir):
    for name in files:
        rel = os.path.relpath(os.path.join(root, name), build_dir)
        if pattern.search(rel):
            print(os.path.join(build_dir, rel))
            sys.exit(0)

sys.exit(1)
PY
}

write_meta() {
  local name="$1"
  local lib_name="$2"
  local stack="$3"
  local icd_rel="$4"
  local lib_rel="$5"
  python3 - <<PY
import json, os
meta = {
  "name": ${name@Q},
  "libraryName": ${lib_name@Q},
  "driverVersion": ${VERSION@Q},
  "driverStack": ${stack@Q},
  "icdRelativePath": ${icd_rel@Q},
  "libDirRelative": ${lib_rel@Q},
}
with open(os.path.join(${tmp@Q}, "meta.json"), "w", encoding="utf-8") as f:
    f.write(json.dumps(meta, indent=2) + "\\n")
PY
}

case "${BACKEND}" in
  freedreno)
    libvk="$(find_one 'src/freedreno/vulkan/libvulkan_freedreno\\.so$')" || {
      echo "error: freedreno build missing libvulkan_freedreno.so" >&2; exit 1; }
    icd="$(find_one 'src/freedreno/vulkan/freedreno_icd\\..*\\.json$')" || {
      echo "error: freedreno build missing ICD json" >&2; exit 1; }

    mkdir -p "${tmp}/lib" "${tmp}/share/vulkan/icd.d"
    cp "${libvk}" "${tmp}/lib/libvulkan_freedreno.so"
    cp "${icd}" "${tmp}/share/vulkan/icd.d/freedreno_icd.aarch64.json"
    write_meta "freedreno-${VERSION}" "libvulkan_freedreno.so" "adrenotools" \
      "share/vulkan/icd.d/freedreno_icd.aarch64.json" "lib"
    ;;

  panvk)
    libvk="$(find_one 'libvulkan_panfrost\\.so$')" || {
      echo "error: panvk build missing libvulkan_panfrost.so" >&2; exit 1; }
    icd="$(find_one 'panfrost_icd\\..*\\.json$|panvk.*icd.*\\.json$')" || {
      echo "error: panvk build missing panfrost/panvk ICD json" >&2; exit 1; }

    mkdir -p "${tmp}/lib" "${tmp}/share/vulkan/icd.d"
    cp "${libvk}" "${tmp}/lib/libvulkan_panfrost.so"
    cp "${icd}" "${tmp}/share/vulkan/icd.d/panfrost_icd.aarch64.json"
    write_meta "panvk-${VERSION}" "libvulkan_panfrost.so" "panvk" \
      "share/vulkan/icd.d/panfrost_icd.aarch64.json" "lib"
    ;;

  virpipe)
    libgl="$(find_one 'libGL\\.so(\\.1)?$')" || \
      libgl="$(find_one 'libGLESv2\\.so(\\.2)?$')" || {
      echo "error: virpipe build missing libGL.so/libGLESv2.so" >&2; exit 1; }
    glapi="$(find_one 'libglapi\\.so(\\.0)?$')" || {
      echo "error: virpipe build missing libglapi.so" >&2; exit 1; }

    mkdir -p "${tmp}/lib"
    cp "${libgl}" "${tmp}/lib/libGL.so.1"
    cp "${glapi}" "${tmp}/lib/libglapi.so.0"
    write_meta "virpipe-${VERSION}" "libGL.so.1" "adrenotools" "" "lib"
    ;;
esac

(
  cd "${tmp}"
  zip -qr "${zip_path}" .
)

echo "wrote ${zip_path}"
