# NotepadL++ — Human Review Checklist

_Batched items that need a human eye but did NOT halt the autonomous build._
_Audit these asynchronously. Each entry: what was done automatically + what to judge._

## UI / UX (form layout & "does it feel like NPP")
- **[M0] Main window skeleton** — `docs/screenshots/m0-mainform.png`.
  Blank `TMainForm` hosts a client-aligned `TATSynEdit`; line numbers/ruler/EOL markers render.
- **[M1] Tabs + menu + highlighting** — `docs/screenshots/m1-python-highlight.png`,
  `m1-json-highlight.png`. File menu (New/Open/Save/Save As/Reload/Recent/Close/Exit), one tab
  per document, EControl syntax highlighting + code folding + line numbers + current-line.
  To judge later (not blocking): this is plain LCL `TPageControl` chrome — no toolbar, no close
  buttons on tabs, no status bar yet (status bar is M3). Whether the look "feels like NPP" is a
  human call; the functional editing core is in place. The form is built entirely in code
  (resourceless `CreateNew`) — intentional, no .lfm.

- **[M2] Find/Replace dialog** (`uFindDialog`). Code-built dialog using ATSynEdit's
  `TATEditorFinder` against the active editor: Find Next / Replace / Replace All / Count, with
  match-case / whole-word / regex / wrap options. Builds + app launches clean under xvfb. To judge
  later (not blocking): interactive behaviour (does Find Next/Replace feel right, focus handling,
  non-modal placement) needs a manual click-through — headless can't drive the dialog.

- **[M3] Edit menu + status bar** (`docs/screenshots/m3-statusbar.png`). Edit menu wires
  uEditorActions (duplicate/delete/move/sort/dedup/trim/case/comment/indent). Status bar shows
  `Ln/Col`, selection length, line count, encoding, EOL, language — encoding & EOL panels are
  click-to-change (popup). Builds + launches clean; status bar verified populated under xvfb.
  To judge later (not blocking): interactive feel of the edit actions + click-to-change popups
  needs a manual click-through. Note: line-based edit actions currently re-set the whole editor
  text (caret resets, single undo step) — acceptable for M3, candidate for finer-grained editing
  later.

- **[M4] Tools menu + dialogs** (`docs/screenshots/m4-tools-menu.png`). Tools menu: JSON
  pretty/minify/validate + XML format/validate (operate on the active doc), View as CSV Grid
  (`uCsvViewer` TStringGrid), and Converters dialog (`uConvertersDlg`: base64/url/uuid/hash/base).
  All driven by the unit-tested tool cores. Builds + launches clean. To judge later (not blocking):
  interactive click-through of the converters dialog + CSV grid layout/usability.

- **[M5] Persistence + theming** (`uConfig`, `uSession`, `uTheme`, wired into `uMainForm`).
  Settings/session JSON round-trip is unit-tested (11 vectors in `uTestConfig`); the UI wiring
  built clean and the **read path is verified automatically**: a seeded `config.json` (theme=dark,
  saved geometry) + `session.json` (one real file) launches with no crash under xvfb. To confirm
  interactively (not blocking, can't be driven headlessly):
  - **Save-on-exit:** `FormDestroy → PersistState` writes `~/.config/notepadlpp/{config,session}.json`
    only on a *clean* shutdown (window close / Ctrl+Q). Verify the files appear and reflect the
    last theme, recent-files list, window box, and open tabs + caret positions.
  - **Restore-on-launch:** reopen the app → previous files come back on the right tabs, active tab
    and carets restored, window returns to its last size/position.
  - **Live theme toggle:** View ▸ Theme ▸ Light/Dark recolors all open editors immediately and the
    choice survives a restart. Eyeball the dark palette (BGR values in `uTheme`) for contrast/taste —
    these are first-pass colors, easy to tune.
  - Edge: a `session.json` listing a file that was deleted/moved is silently skipped on restore
    (by design); confirm that feels right vs. showing a "missing file" notice.

## Packaging (M5, validate on a clean Mint/Ubuntu VM)
- **`.deb` package** — `packaging/build-deb.sh` → `notepadlpp_0.5.0_<arch>.deb` (~2.8 MB).
  Installs `/usr/bin/notepadlpp`, `/usr/share/notepadlpp/lexers/lib.lxl`, desktop entry, and
  hicolor icons (svg + 256px png). `Depends:` = gtk2/X11/pango/cairo runtime only (no FPC/Lazarus).
  **Verified here:** builds clean; `dpkg-deb -x` + launching the installed `/usr/bin` binary under
  xvfb starts with no crash and resolves lexers from `../share/notepadlpp/lexers`.
  desktop-file-validate passes (one non-fatal hint: Utility+Development are both main categories —
  intentional so it shows under both menus).
- **AppImage** — `packaging/build-appimage.sh` assembles a runnable `NotepadLpp.AppDir` (AppRun
  verified under xvfb). `appimagetool` is **not installed on this VM**, so the single-file
  `.AppImage` was not produced here; the script prints the exact fetch command and accepts
  `APPIMAGETOOL=…`. **Needs a human to run with appimagetool present** to emit + smoke the final
  `.AppImage`.
- **Human checkpoint (per kickoff):** on a *clean* Mint/Ubuntu VM — `sudo apt install ./…deb`,
  confirm the app appears in the menu with icon + name, opens files with highlighting, the Tools
  menu and theme toggle work, settings/session persist across a restart, then `sudo apt remove
  notepadlpp` cleans up. Bump `VERSION=` for tagged releases.

## Known gaps / follow-ups
- **[M1] Curated lexer set incomplete.** The bundled `lexers/lib.lxl` (from ATSynEdit's lexlib)
  covers JSON, XML, HTML, CSS, JavaScript, INI, Bash, Python, C, C++, Markdown — 11 of the 15
  curated Phase-1 languages (spec §3.3). **Missing: SQL, YAML, Diff, Log.** These need additional
  EControl `.lcf` lexers from the CudaText collection; tracked as a focused follow-up (spec §3.3
  explicitly allows "wire the rest" later). Files of those types currently open as plain text.

## Decisions worth a sanity check
- **[M0] gtk2 IME / `WITH_GTK2_IM`** (see STATUS.md "KEY TOOLCHAIN DECISION"). Upstream ATSynEdit
  needs an LCL built with `WITH_GTK2_IM`; stock distro Lazarus 3.0 isn't. Rather than patch
  upstream or modify the system, the build uses a project-local Lazarus copy (`deps/lazarus-im`)
  recompiled with the define via a per-project matrix option. If you'd prefer a different strategy
  (e.g. fpcupdeluxe-built matched Lazarus, or qt5), flag it — current approach is green and modern.
- **[M0] Component versions** pinned to recent 2026 commits (DEPENDENCIES.lock), not the old distro
  era. Confirm you're happy tracking these specific commits.
