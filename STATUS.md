# NotepadL++ — Build Status

_Authoritative async progress log. Updated at every milestone boundary._

## Current milestone: **M0 — Toolchain & skeleton** ✅ COMPLETE

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

### Next: **M1 — Editor core, file I/O, tabs, encoding**
- `src/core/`: uDocument, uDocumentManager, uEncoding (interface + EncConv impl; UTF-8 ±BOM, UTF-16 LE/BE, CP-1252), uFileIO (byte-exact round-trip), uSession, uConfig.
- `src/editor/`: uEditorFactory, uLexers (EControl curated set), uEditorActions.
- Tabs + New/Open/Save/Save As/Reload/Recent; line numbers; highlighting.
- fpcunit fixtures for byte-exact encoding round-trips + EOL conversion.

### Decisions taken
- Pinned modern (2026) component set; gtk2 IME handled via project-local LCL rebuild (above).
- Git: `develop` branch; M0 merged to `main` + tagged `M0-complete`.
