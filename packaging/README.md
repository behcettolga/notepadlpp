# Packaging — NotepadL++ (M5)

Scripts that bundle the built editor with its lexer library, a desktop entry, and
an icon into a distributable artifact. Both expect the project-local Lazarus
(`deps/lazarus-im`, see `DEPENDENCIES.lock`) and build the gtk2 binary first.

## Contents
- `notepadlpp.desktop` — freedesktop entry (`Icon=notepadlpp`, MIME types, categories).
- `notepadlpp.svg` — scalable app icon; rasterized to PNG at build time via ImageMagick.
- `build-deb.sh` — produces `build/notepadlpp_<version>_<arch>.deb`.
- `build-appimage.sh` — produces `build/NotepadLpp-<version>-<arch>.AppImage`
  (or a runnable `build/NotepadLpp.AppDir` if `appimagetool` is absent).

## Build a .deb
```sh
packaging/build-deb.sh                 # version defaults to 0.5.0
VERSION=0.5.0 packaging/build-deb.sh   # or pin explicitly
sudo apt install ./packaging/build/notepadlpp_0.5.0_amd64.deb
```
Installs `/usr/bin/notepadlpp`, `/usr/share/notepadlpp/lexers/lib.lxl`, the desktop
entry, and hicolor icons. `Depends:` covers the gtk2/X11 runtime; FPC/Lazarus are
**not** runtime dependencies (the binary is native and self-contained apart from
those shared libraries).

## Build an AppImage
```sh
packaging/build-appimage.sh
```
If `appimagetool` is on `PATH` (or `APPIMAGETOOL=…`), this emits a single-file
`.AppImage`. Otherwise it assembles `build/NotepadLpp.AppDir` whose `AppRun` is
runnable in place, and prints how to fetch `appimagetool`.

## Lexer resolution
`DefaultLexerLibFile` (`src/editor/uLexers.pas`) searches, in order: beside the
binary (`lexers/lib.lxl`, build tree), `../lexers` (repo root), then the install
locations `../share/notepadlpp/lexers` and `/usr/share/notepadlpp/lexers`. The
same binary therefore finds its lexers whether run from the build tree, an
AppImage AppDir, or a `.deb` install.

## Clean-VM validation (human checkpoint)
Per the kickoff, the final packaging step is validated by a human on a clean
Mint/Ubuntu VM: install the artifact, launch from the application menu (icon +
name appear), open a few files, confirm syntax highlighting and the tools work,
then remove the package. Tracked in `HUMAN-REVIEW.md`.
