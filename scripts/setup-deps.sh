#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# setup-deps.sh — recreate the local build environment for NotepadL++.
# Idempotent. Run from the repo root. Requires: git, lazbuild (Lazarus 3.0), an existing
# system Lazarus install to copy from. Nothing here touches files outside the repo.
#
#   1. Clones the pinned dependency components into deps/<name> (see DEPENDENCIES.lock).
#   2. Registers their .lpk package links with lazbuild.
#   3. Makes a user-owned copy of the system Lazarus tree at deps/lazarus-im, so that
#      lazbuild can recompile the gtk2 LCL with -dWITH_GTK2_IM (see DEPENDENCIES.lock for why).
#
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEPS="$ROOT/deps"
mkdir -p "$DEPS"

# name|url|commit  (keep in sync with DEPENDENCIES.lock)
PINS=(
  "EncConv|https://github.com/Alexey-T/EncConv.git|8caaa6b9838b2587d1d0a007dbc4a728a1306a72"
  "ATFlatControls|https://github.com/Alexey-T/ATFlatControls.git|11594c79aa79f8d4d532dc53dde5b2f558301420"
  "BGRABitmap|https://github.com/bgrabitmap/bgrabitmap.git|44a65262e214feb89605d4bb555771f1a3f2df29"
  "ATSynEdit|https://github.com/Alexey-T/ATSynEdit.git|0d75ed45ac563a8571e164e2e782190b85d6b7aa"
  "EControl|https://github.com/Alexey-T/EControl.git|847ce66a1261cdd5b00ae1d348deba21b5e8aeeb"
  "ATSynEdit_Cmp|https://github.com/Alexey-T/ATSynEdit_Cmp.git|e5d23b9841bbb6ad9487778ba5ff5f4f966d5c1b"
  "ATSynEdit_Ex|https://github.com/Alexey-T/ATSynEdit_Ex.git|808020b45879b12817dbfe1d153832a438df7353"
)

echo ">> Cloning / pinning dependency components"
for p in "${PINS[@]}"; do
  IFS='|' read -r name url commit <<< "$p"
  dir="$DEPS/$name"
  if [ ! -d "$dir/.git" ]; then
    git clone "$url" "$dir"
  fi
  git -C "$dir" fetch --tags origin >/dev/null 2>&1 || true
  git -C "$dir" checkout -q "$commit"
  echo "   $name @ $(git -C "$dir" rev-parse --short HEAD)"
done

echo ">> Registering package links with lazbuild"
LPKS=(
  "EncConv/encconv/encconv_package.lpk"
  "ATFlatControls/atflatcontrols/atflatcontrols_package.lpk"
  "BGRABitmap/bgrabitmap/bgrabitmappack.lpk"
  "ATSynEdit/atsynedit/atsynedit_package.lpk"
  "EControl/econtrol/econtrol_package.lpk"
  "ATSynEdit_Cmp/atsynedit_cmp/atsynedit_cmp_package.lpk"
  "ATSynEdit_Ex/atsynedit_ex/atsynedit_ex_package.lpk"
)
for lpk in "${LPKS[@]}"; do
  lazbuild --add-package-link "$DEPS/$lpk" >/dev/null 2>&1 && echo "   linked $(basename "$lpk")"
done

echo ">> Preparing project-local Lazarus copy (for WITH_GTK2_IM gtk2 LCL rebuild)"
LZ="$DEPS/lazarus-im"
if [ ! -d "$LZ/lcl" ]; then
  SYS_LAZ="${LAZARUS_DIR:-/usr/lib/lazarus/3.0}"
  [ -d "$SYS_LAZ/lcl" ] || { echo "ERROR: system Lazarus not found at $SYS_LAZ (set LAZARUS_DIR)"; exit 1; }
  cp -a "$SYS_LAZ" "$LZ"
  echo "   copied $SYS_LAZ -> $LZ"
else
  echo "   already present at $LZ"
fi

echo ">> Done. Build with ./ci.sh"
