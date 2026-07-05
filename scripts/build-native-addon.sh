#!/bin/bash
# Compiles the src/driver native addon (build/Release/addon.node) against the
# Electron version this project depends on, using a modern node-gyp.
#
# This is split out from `electron-builder`'s own nodeGypRebuild because:
#  - node-gyp bundled with old Electron tooling (v8.x) can't parse the
#    'openssl_fips' conditional in newer/Electron-cached common.gypi files
#    (see patch below), so we pin a modern node-gyp via npx instead.
#  - binding.gyp already forces `-arch x86_64 -arch arm64` via xcode_settings,
#    so a single rebuild produces a universal (fat) addon.node - no need to
#    build per-architecture.
set -euo pipefail

cd "$(dirname "$0")/.."

NODE_GYP_VERSION="node-gyp@10.3.1"
ELECTRON_VERSION="$(node -p "require('./node_modules/electron/package.json').version")"
ARCH="x64"
DIST_URL="https://electronjs.org/headers"
DEVDIR="$(pwd)/.cache/electron-gyp"

echo "==> Building native addon for Electron ${ELECTRON_VERSION}"

npx --yes "$NODE_GYP_VERSION" install \
  --target="$ELECTRON_VERSION" --arch="$ARCH" \
  --dist-url="$DIST_URL" --devdir="$DEVDIR"

# Work around https://github.com/nodejs/node-gyp/issues/2220: this Electron
# version's common.gypi defines 'openssl_fips%' (a deferred default) but
# self-references it in a 'conditions' block in the same file. Deferred
# defaults are applied after conditions are evaluated, so the reference
# fails with "name 'openssl_fips' is not defined" unless we make the
# assignment eager.
COMMON_GYPI="${DEVDIR}/${ELECTRON_VERSION}/include/node/common.gypi"
if [ -f "$COMMON_GYPI" ] && grep -q "'openssl_fips%':" "$COMMON_GYPI"; then
  echo "==> Patching common.gypi (openssl_fips deferred-default gyp bug)"
  sed -i '' "s/'openssl_fips%':/'openssl_fips':/" "$COMMON_GYPI"
fi

npx --yes "$NODE_GYP_VERSION" rebuild \
  --target="$ELECTRON_VERSION" --arch="$ARCH" \
  --dist-url="$DIST_URL" --devdir="$DEVDIR"

echo "==> Native addon built: build/Release/addon.node"
