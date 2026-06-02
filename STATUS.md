# NotepadL++ — Build Status

_Authoritative async progress log. Updated at every milestone boundary._

## Current milestone: **M0 — Toolchain & skeleton** (in progress)

### Environment (verified)
- FPC 3.2.2, Lazarus 3.0 / lazbuild, gtk2 LCL, xvfb-run — all installed and smoke-tested.
- git 2.54.0 + gh 2.93.0 authenticated as `behcettolga`.
- Repo on branch `develop`; will merge to `main` + tag `M0-complete` at the M0 gate.

### Pre-resolved decisions (from kickoff)
- License: **MPL-2.0** (SPDX header in every source file).
- Encoding: UTF-8 (±BOM), UTF-16 LE/BE, CP-1252 — behind an interface in `uEncoding`.
- Regex: **TRegExpr**, ~90% Notepad++ parity acceptable.
- Widgetset: **gtk2** first; qt5 only if gtk2 fully green.
- Git: long-lived `develop` branch; merge to `main` + tag at milestone gates; push at milestone boundaries.

### Done
- Repo skeleton per ARCHITECTURE §4 (`src/{core,editor,search,tools,ui}`, `lexers/`, `themes/`, `test/`, `packaging/`).
- `CLAUDE.md` (agent manual, §9), `.gitignore`, `STATUS.md`, `HUMAN-REVIEW.md`.

### Next (M0 remaining)
- Clone dependency closure (ATSynEdit, ATSynEdit_Cmp, ATSynEdit_Ex, EControl, EncConv, BGRABitmap) under `deps/`; pin commits in `DEPENDENCIES.lock`.
- Stand up `test/TestRunner.lpi` (consoletestrunner) + `ci.sh`.
- Build a blank `TMainForm` hosting a `TATSynEdit`; green `lazbuild`; launches under `xvfb-run`.

### Latest ci.sh output
- _not yet run_

### Open decisions taken
- _none beyond the pre-resolved set._
