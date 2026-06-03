#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Build a Debian package for NotepadL++ (ARCHITECTURE §5, M5).
# Produces packaging/build/notepadlpp_<version>_<arch>.deb
#
# Usage:  packaging/build-deb.sh
#         VERSION=0.5.0 packaging/build-deb.sh
# Requires: lazbuild (project-local Lazarus), dpkg-deb, fakeroot, ImageMagick `convert`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="${VERSION:-0.5.0}"
ARCH="$(dpkg --print-architecture)"
LZ="${LAZARUS_DIR_LOCAL:-$ROOT/deps/lazarus-im}"
LB=(lazbuild --lazarusdir="$LZ" --ws=gtk2)

echo "== [1/4] build release binary =="
"${LB[@]}" NotepadLPP.lpi
[ -x ./notepadlpp ] || { echo "ERROR: ./notepadlpp not produced"; exit 1; }

echo "== [2/4] stage tree =="
STAGE="$ROOT/packaging/build/notepadlpp_${VERSION}_${ARCH}"
rm -rf "$STAGE"
install -d "$STAGE/DEBIAN" \
           "$STAGE/usr/bin" \
           "$STAGE/usr/share/notepadlpp/lexers" \
           "$STAGE/usr/share/applications" \
           "$STAGE/usr/share/icons/hicolor/scalable/apps" \
           "$STAGE/usr/share/icons/hicolor/256x256/apps" \
           "$STAGE/usr/share/doc/notepadlpp"

install -m 0755 ./notepadlpp                  "$STAGE/usr/bin/notepadlpp"
strip --strip-unneeded "$STAGE/usr/bin/notepadlpp" 2>/dev/null || true
install -m 0644 lexers/lib.lxl                "$STAGE/usr/share/notepadlpp/lexers/lib.lxl"
install -m 0644 packaging/notepadlpp.desktop  "$STAGE/usr/share/applications/notepadlpp.desktop"
install -m 0644 packaging/notepadlpp.svg      "$STAGE/usr/share/icons/hicolor/scalable/apps/notepadlpp.svg"
convert -background none packaging/notepadlpp.svg -resize 256x256 \
        "$STAGE/usr/share/icons/hicolor/256x256/apps/notepadlpp.png"
install -m 0644 LICENSE                        "$STAGE/usr/share/doc/notepadlpp/copyright"

echo "== [3/4] control + maintainer scripts =="
INSTALLED_KB="$(du -ks "$STAGE/usr" | cut -f1)"
cat > "$STAGE/DEBIAN/control" <<EOF
Package: notepadlpp
Version: ${VERSION}
Section: editors
Priority: optional
Architecture: ${ARCH}
Depends: libc6, libgtk2.0-0, libx11-6, libpango-1.0-0, libcairo2
Installed-Size: ${INSTALLED_KB}
Maintainer: NotepadL++ project <noreply@example.org>
Homepage: https://github.com/behcettolga/notepadlpp
Description: NotepadL++ native text and source code editor
 A fast native Linux text editor in the spirit of Notepad++, built on
 Free Pascal / Lazarus with the ATSynEdit editing core. Multi-tab editing,
 syntax highlighting, encoding/EOL detection, find-in-files, JSON/XML/CSV
 tools, light/dark themes, and session restore.
EOF

cat > "$STAGE/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q /usr/share/applications || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
fi
EOF
cp "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"
chmod 0755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

echo "== [4/4] build .deb =="
DEB="$ROOT/packaging/build/notepadlpp_${VERSION}_${ARCH}.deb"
fakeroot dpkg-deb --build --root-owner-group "$STAGE" "$DEB"
echo
echo "Built: $DEB"
dpkg-deb --info "$DEB" | sed -n '1,20p'
echo
echo "Install with:  sudo apt install \"$DEB\"   (or: sudo dpkg -i ...)"
