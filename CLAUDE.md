# NotepadL++ — Claude Code operating manual

This is the repo-root agent manual (ARCHITECTURE.md §9). `ARCHITECTURE.md` is the
authoritative spec for scope (§3), module layout (§4), and milestone acceptance
criteria (§5). Read it before any work.

## Build
- Compile app:    `lazbuild NotepadLPP.lpi`
- Run (headless): `xvfb-run -a ./notepadlpp`
- Compile tests:  `lazbuild test/TestRunner.lpi`
- Run tests:      `./test/TestRunner --all --format=plain`
- Full CI gate:   `./ci.sh`  (builds app + tests, runs tests headless; non-zero exit on any failure)

## Toolchain (installed on this VM)
- FPC 3.2.2, Lazarus 3.0 (`lazbuild` at /usr/bin/lazbuild), gtk2 LCL, xvfb-run.
- Target widgetset: **gtk2** first (`--ws=gtk2`). Validate qt5 only if gtk2 is fully green.
- Dependencies are cloned under `deps/` (gitignored) and pinned in `DEPENDENCIES.lock`.
  Add their package dirs to lazbuild via the project's required packages / `--add-package-link`.

## Language conventions
- `{$mode objfpc}{$H+}` in every unit. No Delphi-only constructs.
- Unit prefix: `u<Name>.pas`. One responsibility per unit.
- MPL-2.0 SPDX header at the top of every source file we author:
  `// SPDX-License-Identifier: MPL-2.0`
- Layer rule: `src/core`, `src/search`, `src/tools`, `src/editor` MUST NOT use `src/ui`.

## Dependencies (read-only upstream)
- Use ONLY the components in `DEPENDENCIES.lock` at their pinned commits.
- ATSynEdit / ATSynEdit_Cmp / ATSynEdit_Ex / EControl / EncConv: **READ THE SOURCE before
  calling.** Never guess a method signature — grep the cloned repo and confirm. When unsure,
  write a throwaway spike that compiles against the real API, confirm, then delete it.
- Treat ATSynEdit/EControl as read-only upstream. Wrap, never patch.

## Workflow
- Compile + run the relevant test suite after every unit edit.
- Do not advance milestones (ARCHITECTURE §5) on a red build.
- Never claim a build/test passed without running it and recording the real output.
- New logic feature => new fpcunit test with explicit input→output vectors.
- Forms (.lfm): build + xvfb launch to confirm no crash; log to `HUMAN-REVIEW.md` for human UX review.
- Git: work on `develop`; commit per unit. At each milestone gate merge to `main`, tag
  `MX-complete`, push. Repo is public.
- Reporting: keep `STATUS.md` current at every milestone boundary; batch UI/packaging
  judgment calls into `HUMAN-REVIEW.md` and continue (don't halt).

## Definition of done
- Per unit: compiles clean (no warnings in our code), tests green, no `ui/` leak into core layers.
- Per milestone: the §5 acceptance criterion is demonstrably met and recorded in `STATUS.md`.
