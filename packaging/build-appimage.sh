#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Build an AppImage (or at least a runnable AppDir) for NotepadL++ (M5).
# Produces packaging/build/NotepadLpp-<version>-<arch>.AppImage when appimagetool
# is available; otherwise leaves a self-contained AppDir you can run in place.
#
# Usage:  packaging/build-appimage.sh
# Requires: lazbuild (project-local Lazarus), ImageMagick `convert`.
# Optional: appimagetool on PATH (or APPIMAGETOOL=/path/to/appimagetool).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.5.0}"
ARCH="$(uname -m)"
LZ="${LAZARUS_DIR_LOCAL:-$ROOT/deps/lazarus-im}"
LB=(lazbuild --lazarusdir="$LZ" --ws=gtk2)

echo "== [1/3] build release binary =="
"${LB[@]}" NotepadLPP.lpi
[ -x ./notepadlpp ] || { echo "ERROR: ./notepadlpp not produced"; exit 1; }

echo "== [2/3] assemble AppDir =="
APPDIR="$ROOT/packaging/build/NotepadLpp.AppDir"
rm -rf "$APPDIR"
install -d "$APPDIR/usr/bin" \
           "$APPDIR/usr/share/notepadlpp/lexers" \
           "$APPDIR/usr/share/applications" \
           "$APPDIR/usr/share/icons/hicolor/256x256/apps"

install -m 0755 ./notepadlpp                  "$APPDIR/usr/bin/notepadlpp"
strip --strip-unneeded "$APPDIR/usr/bin/notepadlpp" 2>/dev/null || true
install -m 0644 lexers/lib.lxl                "$APPDIR/usr/share/notepadlpp/lexers/lib.lxl"
install -m 0644 packaging/notepadlpp.desktop  "$APPDIR/usr/share/applications/notepadlpp.desktop"
# AppImage wants the .desktop + icon at the AppDir root too.
install -m 0644 packaging/notepadlpp.desktop  "$APPDIR/notepadlpp.desktop"
convert -background none packaging/notepadlpp.svg -resize 256x256 \
        "$APPDIR/usr/share/icons/hicolor/256x256/apps/notepadlpp.png"
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/notepadlpp.png" "$APPDIR/notepadlpp.png"
ln -sf notepadlpp.png "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export PATH="$HERE/usr/bin:$PATH"
# DefaultLexerLibFile resolves <exe>/../share/notepadlpp/lexers/lib.lxl
exec "$HERE/usr/bin/notepadlpp" "$@"
EOF
chmod 0755 "$APPDIR/AppRun"

echo "== [3/3] package =="
TOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
OUT="$ROOT/packaging/build/NotepadLpp-${VERSION}-${ARCH}.AppImage"
if [ -n "$TOOL" ]; then
  ARCH="$ARCH" "$TOOL" "$APPDIR" "$OUT"
  echo "Built: $OUT"
else
  echo "appimagetool not found — AppDir is ready and runnable in place:"
  echo "  $APPDIR/AppRun"
  echo "To produce the single-file .AppImage, install appimagetool and re-run, e.g.:"
  echo "  wget -O appimagetool https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  echo "  chmod +x appimagetool && APPIMAGETOOL=./appimagetool packaging/build-appimage.sh"
fi
