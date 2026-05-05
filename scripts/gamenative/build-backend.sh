#!/usr/bin/env bash
# Configure & compile Mesa for a GameNative Android backend using the NDK + Meson.
#
# Environment:
#   ANDROID_NDK_ROOT   Required. Path to the Android NDK.
#   ANDROID_API_LEVEL  Optional. Android API for clang triple (default: 34).
#   MESON_CROSS_FILE   Optional. Existing cross file; if unset, a default aarch64 file is generated.
#   MESON_EXTRA_ARGS   Optional. Extra args passed to `meson setup` (unquoted; use carefully).
#   PANVK_PRECOMP_COMPILER  Optional. Set to `system` to append `-Dprecomp-compiler=system` (panvk).
#
# Backends:
#   panvk       Panfrost / PanVK (Mali): gallium panfrost + vulkan panfrost, panfrost tools/precomp.
#   freedreno   Turnip-style KGSL stack: vulkan freedreno, freedreno-kmds=kgsl.
#   virpipe     VirtIO GL path mapped to Mesa gallium `virgl` (Mesa has no `virpipe` driver id).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

usage() {
  echo "Usage: $0 <panvk|freedreno|virpipe> [build-dir]" >&2
  exit 1
}

[[ "${#}" -ge 1 ]] || usage
BACKEND="$1"
shift || true
require_backend "${BACKEND}"
require_ndk

BUILD_DIR="${1:-${MESA_ROOT}/build-gamenative-${BACKEND}}"
[[ "${#}" -ge 1 ]] && shift || true

CROSS="${MESON_CROSS_FILE:-}"
if [[ -z "${CROSS}" ]]; then
  CROSS="$(write_android_aarch64_cross_file)"
fi

PRECOMP_FLAG=()
if [[ "${PANVK_PRECOMP_COMPILER:-}" == "system" ]]; then
  PRECOMP_FLAG=(-Dprecomp-compiler=system)
fi

case "${BACKEND}" in
  panvk)
    PRECOMP_FLAG=(-Dprecomp-compiler=system)
    DRIVER_OPTS=(
      -Dgallium-drivers=panfrost
      -Dvulkan-drivers=panfrost
      -Dtools=panfrost
      -Dinstall-precomp-compiler=false
    )
    EGL_OPT=(-Degl=disabled)
    ;;
  freedreno)
    DRIVER_OPTS=(
      -Dgallium-drivers=
      -Dvulkan-drivers=freedreno
      -Dfreedreno-kmds=kgsl
      -Dtools=
      -Dprecomp-compiler=system
      -Dinstall-precomp-compiler=false
    )
    EGL_OPT=(-Degl=disabled)
    ;;
  virpipe)
    DRIVER_OPTS=(
      -Dgallium-drivers=virgl
      -Dvulkan-drivers=
      -Dtools=
      -Dprecomp-compiler=system
      -Dinstall-precomp-compiler=false
    )
    EGL_OPT=(-Degl=enabled)
    ;;
esac

echo "==> meson setup ${BUILD_DIR} (backend=${BACKEND})"
# meson expects: setup <builddir> <sourcedir> [options]
# shellcheck disable=SC2086
meson setup "${BUILD_DIR}" "${MESA_ROOT}" \
  --cross-file "${CROSS}" \
  "-Dbuildtype=${MESON_BUILDTYPE:-release}" \
  -Dplatforms=android \
  "-Dplatform-sdk-version=${ANDROID_PLATFORM_SDK_VERSION:-${ANDROID_API_LEVEL:-34}}" \
  -Dandroid-stub=true \
  -Dandroid-libbacktrace=disabled \
  -Dallow-fallback-for=perfetto \
  -Dgallium-va=disabled \
  "${EGL_OPT[@]}" \
  "${DRIVER_OPTS[@]}" \
  "${PRECOMP_FLAG[@]}" \
  ${MESON_EXTRA_ARGS:-}

echo "==> meson compile -C ${BUILD_DIR}"
meson compile -C "${BUILD_DIR}"
