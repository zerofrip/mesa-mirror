# GameNative Mesa scripts (mesa-mirror)

Helpers to cross-build Mesa for Android (aarch64) and to package **Adrenotools-style** driver zips
that GameNative expects (top-level `meta.json` plus optional `lib/` / Vulkan ICD layout).

## Requirements

- Meson + Ninja, Python 3, a Mesa source tree (this repo)
- **ANDROID_NDK_ROOT** — absolute path to the Android NDK (used by `build-backend.sh` and by the
  generated cross file unless **MESON_CROSS_FILE** overrides it)

See `docs/android.rst` in Mesa for full background (PanVK precomp, KGSL freedreno, etc.).

## Backends (`build-backend.sh`)

| Backend    | Mesa mapping | Notes |
|-----------|--------------|-------|
| `panvk`   | `gallium-drivers=panfrost`, `vulkan-drivers=panfrost`, panfrost tools/precomp | Mali PanVK |
| `freedreno` | `vulkan-drivers=freedreno`, `freedreno-kmds=kgsl` | Turnip-style Qualcomm |
| `virpipe` | `gallium-drivers=virgl` | VirtGL stack; Mesa uses the `virgl` driver id (no separate `virpipe` target) |

Example:

```bash
export ANDROID_NDK_ROOT=/opt/android-ndk-r26b
./scripts/gamenative/build-backend.sh panvk
```

Optional: `PANVK_PRECOMP_COMPILER=system ./scripts/gamenative/build-backend.sh panvk` when you
provide a system precomp compiler per Mesa docs.

Build + package in one command (recommended):

```bash
export ANDROID_NDK_ROOT=/opt/android-ndk-r26d
./scripts/gamenative/build-and-package.sh freedreno 26.2.0-devel ./dist
```

## Packaging (`package-gamenative-zip.sh`)

Produces a zip suitable for tools/tests with required **`meta.json`** fields:

| Field           | Role |
|-----------------|------|
| `name`          | Display / folder id for the bundle |
| `libraryName`   | Primary `.so` name (hook / loader expectations) |
| `driverVersion` | Version string surfaced in UI / checks |
| `driverStack`   | `"panvk"` → GameNative installs via `PanVkDriverManager` (VK_ICD + LD_LIBRARY_PATH); omit / `"adrenotools"` → Qualcomm Adrenotools path |
| `icdRelativePath` | Optional; default `share/vulkan/icd.d/panfrost_icd.aarch64.json` |
| `libDirRelative` | Optional; default `lib` |

```bash
./scripts/gamenative/package-gamenative-zip.sh -p -o /tmp/mesa-placeholder.zip \\
  --name my-mesa \\
  --library-name libvulkan_panfrost.so \\
  --driver-version 25.0.0-test \\
  --driver-stack panvk
```

`-p` adds `lib/<libraryName>` and `share/vulkan/icd.d/placeholder_icd.json` as **non-ELF stubs**
for layout verification only.

Run `meta_json_fields_doc` after sourcing `common.sh` in a shell for a short field summary:

```bash
source scripts/gamenative/common.sh
meta_json_fields_doc
```

## GitHub Actions release

This repository includes `.github/workflows/gamenative-drivers-release.yml`:

- Trigger manually (`workflow_dispatch`) with `release_tag` + `driver_version`, or
- Push a tag like `gamenative-drivers-20260505`.

The workflow installs NDK + build dependencies, builds all backends, packages ZIPs,
and publishes a GitHub Release automatically.
