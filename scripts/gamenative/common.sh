#!/usr/bin/env bash
# Shared helpers for GameNative-related Mesa Android builds (mesa-mirror checkout).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# mesa-mirror repository root (scripts/gamenative -> ../..)
MESA_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

require_ndk() {
  if [[ -z "${ANDROID_NDK_ROOT:-}" || ! -d "${ANDROID_NDK_ROOT}" ]]; then
    echo "error: set ANDROID_NDK_ROOT to your Android NDK installation path" >&2
    exit 1
  fi
}

require_backend() {
  case "$1" in
    panvk|freedreno|virpipe) ;;
    *)
      echo "error: backend must be panvk, freedreno, or virpipe (got: $1)" >&2
      exit 1
      ;;
  esac
}

ndk_prebuilt_host() {
  case "$(uname -s)" in
    Linux*) echo "linux-x86_64" ;;
    Darwin*) echo "darwin-x86_64" ;;
    *)
      echo "error: unsupported host OS for NDK prebuilt selection" >&2
      exit 1
      ;;
  esac
}

# Write a minimal Meson cross file for aarch64 Android (API level configurable).
# Override output path with first argument; default is under this scripts dir.
write_android_aarch64_cross_file() {
  local out="${1:-${SCRIPT_DIR}/.generated-android-aarch64.cross}"
  local prebuilt api ndk
  prebuilt="$(ndk_prebuilt_host)"
  api="${ANDROID_API_LEVEL:-34}"
  ndk="${ANDROID_NDK_ROOT}"
  mkdir -p "$(dirname "${out}")"
  cat > "${out}" <<INI
[constants]
ndk_path = '${ndk}'

[binaries]
ar = ndk_path / 'toolchains/llvm/prebuilt/${prebuilt}/bin/llvm-ar'
c = ndk_path / 'toolchains/llvm/prebuilt/${prebuilt}/bin/aarch64-linux-android${api}-clang'
cpp = ndk_path / 'toolchains/llvm/prebuilt/${prebuilt}/bin/aarch64-linux-android${api}-clang++'
strip = ndk_path / 'toolchains/llvm/prebuilt/${prebuilt}/bin/llvm-strip'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8'
endian = 'little'
INI
  printf '%s\n' "${out}"
}

meta_json_fields_doc() {
  cat <<'DOC'
Adrenotools-style driver zips include a top-level `meta.json` consumed by GameNative / Winlator:

  name            Display / folder name for the driver bundle (string).
  libraryName     Primary hookable shared library file name (string), e.g. `libvulkan_freedreno.so`.
  driverVersion   Version string shown in UI and compatibility checks (string).

The packaging helper emits this file at the root of the zip next to optional `lib/` layout.
DOC
}
