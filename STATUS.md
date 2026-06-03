# NotepadL++ — Build Status

_Authoritative async progress log. Updated at every milestone boundary._

## Current milestone: **M4 — Built-in tools** ✅ COMPLETE

### M4 acceptance (ARCHITECTURE §5)
- `uConverters` + `uSHA256`: Base64 (RFC 4648), URL, UUID, MD5/SHA-1, **SHA-256
  (from-scratch, 3 NIST vectors)**, numeric base 2..36. ✅
- `uJsonTool` (pretty/minify/validate w/ error position), `uXmlTool` (format/validate),
  `uCsvTool` (quote-aware parse + delimiter detect). ✅
- 24 tool tests (RFC 4648, RFC 1321 MD5, NIST SHA-256, malformed-JSON position, etc.). ✅
- UI: Tools menu (JSON/XML actions on active doc), `uCsvViewer` grid, `uConvertersDlg`. ✅
- ci.sh: app builds; **90/90 headless tests pass**.

---

## M3 — Editing operations & status bar ✅ COMPLETE

### M3 acceptance (ARCHITECTURE §5)
- `uEditorActions` (UI-free): duplicate/delete/move/sort/dedup/trim, UTF-8 case
  (UPPER/lower/Title), comment-toggle, indent/outdent. 14 string-fixture tests. ✅
- Edit menu wires those to the active editor (line range from selection). ✅
- Interactive status bar: Ln/Col, selection length, line count, encoding, EOL, language;
  live on caret move / edit / tab switch; encoding & EOL **click-to-change**. ✅
  (verified populated under xvfb — `docs/screenshots/m3-statusbar.png`)
- ci.sh: app builds; **66/66 headless tests pass**.

Interactive edit-action feel + popups → HUMAN-REVIEW (line ops currently re-set whole text).

---

## M2 — Search / Replace / Find-in-Files ✅ COMPLETE

### M2 acceptance (ARCHITECTURE §5)
- `uSearchEngine` (UI-free): plain / match-case / whole-word / regex (TRegExpr) / wrap /
  count / replace-all (+ `$1` group substitution). 13 fpcunit vectors. ✅
- `uFindInFiles` (UI-free): mask filters + recursion + encoding-aware per-line search;
  `uSearchResults` model. 5 fpcunit tests over a real fixture tree (hit set, masks,
  recursion, line/col, distinct files). ✅
- UI: Find/Replace dialog (`uFindDialog`, via ATSynEdit `TATEditorFinder`); Find-in-Files
  dialog + bottom results panel; double-click → open + jump to file:line (`GotoLineCol`);
  search runs on a worker thread (`TFindInFilesThread`). ✅ (interactive UX → HUMAN-REVIEW)
- ci.sh: app builds; **52/52 headless tests pass**.

Design note: interactive current-document find uses ATSynEdit's own finder (owns the
UTF-8/UnicodeString coordinate mapping); our `uSearchEngine` is the tested core and powers
Find-in-Files. Both are TRegExpr-based.

---

## M1 — Editor core, file I/O, tabs, encoding ✅ COMPLETE

### M1 acceptance (ARCHITECTURE §5)
- DocumentManager + tabs; New/Open/Save/Save As/Reload/Recent/Close. ✅
- Encoding detect/convert + EOL detect/convert — `uEncoding`, behind `IEncodingService`. ✅
- **Byte-exact round-trip** save for UTF-8, UTF-8+BOM, UTF-16LE, UTF-16BE, CP-1252 — fpcunit
  fixtures (`uTestEncoding`, `uTestFileIO`) write real files, reload, compare bytes. ✅
- EOL conversion verified by tests. ✅
- Line numbers + EControl syntax highlighting (+ code folding). ✅
  Verified under xvfb: `docs/screenshots/m1-python-highlight.png`, `m1-json-highlight.png`.
- ci.sh: app builds; **34/34 headless tests pass**.

**Known gap (documented, spec §3.3 deferral):** bundled `lexers/lib.lxl` covers 11/15 curated
languages (JSON, XML, HTML, CSS, JS, INI, Bash, Python, C, C++, Markdown). **SQL, YAML, Diff, Log**
lexers are a tracked follow-up (need extra EControl `.lcf` from CudaText); such files open as plain
text meanwhile. See HUMAN-REVIEW.md.

Core layering held: `core/` (encoding, fileio, document) is UI-free and fully unit-tested; editor
integration (`editor/`, `ui/`) validated by build + xvfb. Main form is resourceless (code-built).

---

## M0 — Toolchain & skeleton ✅ COMPLETE

### M0 acceptance (ARCHITECTURE §5) — met
- `lazbuild NotepadLPP.lpi` exits 0 (gtk2). ✅
- App launches under `xvfb-run` without crashing. ✅
- ATSynEdit visible with typed text — see `docs/screenshots/m0-mainform.png`. ✅
- `DEPENDENCIES.lock` written with pinned commits. ✅
- `test/TestRunner.lpi` (consoletestrunner + fpcunit) + `ci.sh` stood up; `./ci.sh` green. ✅

### Environment (verified)
- FPC 3.2.2, Lazarus 3.0 / lazbuild, gtk2 LCL, xvfb-run; git 2.54.0 + gh 2.93.0 (auth `behcettolga`).

### Dependency closure (pinned — see DEPENDENCIES.lock)
- ATSynEdit, ATSynEdit_Cmp, ATSynEdit_Ex, EControl, EncConv, ATFlatControls, BGRABitmap — all at recent (2026) commits, building clean on gtk2.

### KEY TOOLCHAIN DECISION (M0) — gtk2 IME / WITH_GTK2_IM
Upstream ATSynEdit calls `IM_Context_Set_Cursor_Pos` unconditionally (since 2021). That LCL routine
is only exported when the LCL is compiled with the `WITH_GTK2_IM` define, which the **stock distro
Lazarus 3.0 is NOT**. We must not patch upstream (prime directive) nor modify the system Lazarus
(out-of-project boundary). Resolution, fully inside the repo:
1. `scripts/setup-deps.sh` makes a user-owned copy of the Lazarus tree at `deps/lazarus-im`.
2. Each project `.lpi` carries a `SharedMatrixOptions` custom option `-dWITH_GTK2_IM` on
   Targets `#project,LCL`, so lazbuild recompiles the gtk2 LCL **with** the define.
3. All builds pass `--lazarusdir=deps/lazarus-im` (writable, so that recompile can happen).
This keeps modern components + gtk2 (per kickoff) with zero changes to upstream or the system.

### Build / verify
- Reproduce env: `scripts/setup-deps.sh`  (deps/ and deps/lazarus-im are gitignored).
- Gate: `./ci.sh` (build app + tests + run tests) or `./ci.sh --app-run` (also xvfb GUI smoke).
- Latest `./ci.sh --app-run`: **CI PASSED** — app links; tests 1 run / 0 failures; app launched under xvfb, no crash.

### Next: **M5 — Persistence, theming, packaging**
- `src/core/`: uConfig (JSON settings via fpjson), uSession (reopen last files + window
  geometry on launch), recent-files persistence.
- `src/ui/uTheme`: light + dark theme applied to editor colors.
- `packaging/`: AppImage and/or .deb that installs + launches on a clean Mint/Ubuntu VM.
- Accept: settings + open files survive restart; theme toggles live; packaging artifact runs.

### Follow-ups carried forward
- Complete curated lexer set: add SQL, YAML, Diff, Log (spec §3.3) — see HUMAN-REVIEW.md.

### Decisions taken
- Pinned modern (2026) component set; gtk2 IME handled via project-local LCL rebuild (above).
- Git: `develop`; M0–M4 tagged `M0-complete`…`M4-complete` (merged to `main`).
  Pushing `develop` after each unit for live visibility; milestone tags land on `main`.
