#!/usr/bin/env bash
# Build and install native (build machine) mesa_clc + vtn_bindgen2 for Android cross builds.
# See docs/android.rst: "Preparing offline compilers" / PanVK precomp notes.
#
# Output prefix defaults to /tmp/mesa-host-tools (bin/ contains mesa_clc).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

PREFIX="${MESA_HOST_TOOLS_PREFIX:-/tmp/mesa-host-tools}"
BUILD_DIR="${MESA_ROOT}/build-gamenative-host-mesa-clc"

echo "==> meson setup (native host mesa_clc) -> prefix=${PREFIX}"
# shellcheck disable=SC2086
meson setup "${BUILD_DIR}" "${MESA_ROOT}" \
  --prefix="${PREFIX}" \
  "-Dbuildtype=${MESON_BUILDTYPE:-release}" \
  -Dstrip=true \
  -D'platforms=[]' \
  -Dgallium-drivers= \
  -Dvulkan-drivers= \
  -Degl=disabled \
  -Dgallium-va=disabled \
  -Dgallium-rusticl=false \
  -Dzstd=disabled \
  -Dmesa-clc=enabled \
  -Dinstall-mesa-clc=true \
  -Dtools=panfrost \
  -Dinstall-precomp-compiler=true \
  ${MESA_HOST_TOOLS_EXTRA_ARGS:-}

echo "==> meson compile -C ${BUILD_DIR}"
meson compile -C "${BUILD_DIR}"

echo "==> meson install -C ${BUILD_DIR}"
meson install -C "${BUILD_DIR}"

echo "Host tools installed under ${PREFIX}/bin"
