# NotepadL++ — Human Review Checklist

_Batched items that need a human eye but did NOT halt the autonomous build._
_Audit these asynchronously. Each entry: what was done automatically + what to judge._

## UI / UX (form layout & "does it feel like NPP")
- **[M0] Main window skeleton** — `docs/screenshots/m0-mainform.png`.
  Done automatically: blank `TMainForm` hosts a client-aligned `TATSynEdit` showing placeholder
  text; line numbers, ruler, EOL/EOF markers render; launches under xvfb without crashing.
  To judge later: nothing actionable yet — real chrome (menu/toolbar/tabs/status bar) arrives in
  M1/M3. This is just confirmation the editor core renders.

## Packaging (M5, validate on a clean Mint/Ubuntu VM)
- _none yet._

## Decisions worth a sanity check
- **[M0] gtk2 IME / `WITH_GTK2_IM`** (see STATUS.md "KEY TOOLCHAIN DECISION"). Upstream ATSynEdit
  needs an LCL built with `WITH_GTK2_IM`; stock distro Lazarus 3.0 isn't. Rather than patch
  upstream or modify the system, the build uses a project-local Lazarus copy (`deps/lazarus-im`)
  recompiled with the define via a per-project matrix option. If you'd prefer a different strategy
  (e.g. fpcupdeluxe-built matched Lazarus, or qt5), flag it — current approach is green and modern.
- **[M0] Component versions** pinned to recent 2026 commits (DEPENDENCIES.lock), not the old distro
  era. Confirm you're happy tracking these specific commits.
