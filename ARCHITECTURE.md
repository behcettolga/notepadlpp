# NotepadL++ — Phase 1 Architecture & Functional Scope

**Target:** A native Linux (Ubuntu / Linux Mint) Notepad++‑class editor.
**Stack:** Object Pascal (Free Pascal) + Lazarus LCL, editing core = ATSynEdit.
**Execution model:** Built primarily by Claude Code (Opus 4.8) autonomously, with human checkpoints at UI/UX and packaging.
**License:** Choose GPLv3 or MPL‑2.0. ATSynEdit/CudaText components are MPL‑2.0‑friendly; if you want to keep your own code permissive, MPL‑2.0 aligns best with the upstream components.

This document is the master spec. It is written so an autonomous agent can execute it milestone‑by‑milestone and self‑verify against acceptance criteria. A companion `CLAUDE.md` (Section 9) goes in the repo root.

---

## 1. Design principles (non‑negotiable constraints for the agent)

1. **Wrap, don't fork, the editing core.** ATSynEdit and EControl are used as upstream dependencies, unmodified. All NotepadL++ behavior lives in *our* units that consume their public APIs. This keeps us upgradable.
2. **Logic is separable from UI.** Every feature that *can* be tested without a window (encoding, search, converters, file I/O, document model) lives in a UI‑free unit with `fpcunit` tests. The agent verifies these without a display.
3. **Native and lightweight is the value proposition.** No bundled runtime, fast cold start. Reject any dependency that pulls in a heavy runtime or violates the native‑binary goal.
4. **Don't hallucinate niche APIs.** ATSynEdit/EControl/EncConv have sparse public training data. Before integrating any of them, the agent must read the upstream README/wiki and, where unsure, grep the actual cloned source. Inventing a method signature is the single most likely failure mode — guard against it explicitly.
5. **Tight build‑test loop.** After each unit, compile headless via `lazbuild` and run its tests. Never advance a milestone with a red build.

---

## 2. Technology stack & dependencies

| Concern | Choice | Notes |
|---|---|---|
| Language | Free Pascal (FPC) 3.2.2+ | `{$mode objfpc}{$H+}` |
| UI toolkit | Lazarus LCL | Target widgetset `gtk2` first (most stable on Mint/Ubuntu), validate `qt5` as secondary |
| Editing core | **ATSynEdit** | Buffer, multi‑caret, folding, minimap, rendering |
| Editing extras | **ATSynEdit_Cmp**, **ATSynEdit_Ex** | Autocomplete UI, search helpers |
| Syntax engine | **EControl** | Lexer parsing used by ATSynEdit/CudaText |
| Encoding | **EncConv** | UTF‑8/16, codepage conversion |
| Graphics | **BGRABitmap** | Transitive dependency of the AT* stack; install but don't use directly |
| Flat controls | **ATFlatControls** | Optional. Prefer plain LCL for menu/toolbar/statusbar in Phase 1; adopt only if LCL proves limiting |
| Regex | **TRegExpr** | Bundled with FPC / improved copy inside ATSynEdit |
| JSON | `fpjson`, `jsonparser` | Stdlib — tool feature + config files |
| XML | `laz2_DOM`, `laz2_XMLRead`, `laz2_XMLWrite` | Stdlib |
| Hashing | `md5`, `sha1`, `DCPcrypt` or FPC `sha256` | For hash tool |
| Build (CLI) | `lazbuild` | Headless, scriptable — essential for the agent |
| Test | `fpcunit` + `consoletestrunner` | Headless logic tests |

**Dependency acquisition:** clone each AT* / EncConv repo (all under `github.com/Alexey-T/…` and `bgrabitmap`), or install via Lazarus OPM (Online Package Manager). The exact transitive graph must be resolved empirically by the agent at M0 — the table above is the expected set, not a guarantee. Pin commit hashes once a working set is found.

> **Agent task at M0:** determine the minimal dependency closure that compiles a blank ATSynEdit‑hosting form, and record pinned versions in `DEPENDENCIES.lock`.

---

## 3. Phase 1 functional scope

### 3.1 In scope

**Document & files**
- Multi‑tab interface; open many files, reorder/close tabs, modified indicator.
- New / Open / Save / Save As / Reload from disk / Recent files.
- Encoding: detect & handle UTF‑8 (with/without BOM), UTF‑16 LE, UTF‑16 BE, and one 8‑bit fallback (CP‑1252 / Latin‑1). *(See §6 on why UTF‑16 stays in despite the "UTF‑8 + ANSI only" idea.)*
- Line endings: detect and convert LF / CRLF / CR independently of encoding.
- Session restore: reopen last open files + window geometry on launch.

**Editing (from ATSynEdit, surfaced via our actions)**
- Multi‑caret & column/block selection, word wrap toggle, code folding (lexer‑driven).
- Undo/redo, cut/copy/paste, select‑all.
- Line ops: duplicate, move up/down, delete, sort, remove duplicates, trim trailing whitespace.
- Case conversion: UPPER / lower / Title.
- Comment / uncomment (lexer‑aware) and indent / outdent.
- Go to line; bracket matching; current‑line highlight; line numbers.

**Search / Replace — target ≥90% NPP parity**
- Find & Replace in current document: plain / match‑case / whole‑word / **regex (TRegExpr)** / wrap‑around / count / mark‑all / replace‑all.
- Incremental find.
- **Find in Files:** directory root + file mask filters (e.g. `*.log;*.conf`) + recursive toggle + regex; results in a navigable panel (double‑click → jump to file+line). Runs on a worker thread; cancellable.

**Built‑in tools (replace the popular plugins, out of the box)**
- JSON: pretty‑print, minify, validate (report error position).
- XML: pretty‑print, validate/well‑formedness check.
- CSV: tabular grid viewer (delimiter auto‑detect + override).
- Converters: Base64 encode/decode, URL encode/decode, UUID/GUID generate, Hash calculator (MD5 / SHA‑1 / SHA‑256), numeric base conversion (bin/oct/dec/hex).

**Shell / UX**
- Main window: menu bar, toolbar, tabbed editor host, status bar.
- Status bar: caret line/col, selection length, total lines/chars, encoding, EOL type, current language — encoding and EOL clickable to change.
- Minimap (ATSynEdit built‑in) — toggleable.
- Find‑results dock/panel at bottom.
- One light + one dark theme.
- Settings persisted as JSON (CudaText‑style), incl. recent files and window state.

### 3.2 Explicitly OUT of Phase 1 (deferred to Phase 2+)

Plugin system / SDK · Python or any embedded scripting · macro record/playback · the full 300‑language lexer set (curate ~15, see §3.3) · FTP/remote editing · diff/compare · spell check · function list / code tree · auto‑update · multi‑window orchestration beyond single‑instance file routing.

### 3.3 Curated lexer set for Phase 1

Ship EControl lexers for: Plain text, Log, JSON, XML, HTML, CSS, JavaScript, INI/conf, Shell/Bash, Python, C/C++, SQL, YAML, Markdown, Diff. Wire the rest as a post‑Phase‑1 "enable more lexers" task.

---

## 4. Module / unit architecture

Clear boundaries so the agent can build, test, and reason about one unit at a time. UI‑free units carry tests; `.lfm` form files carry none (human smoke test or xvfb launch instead).

```
notepadlpp/
├── NotepadLPP.lpi               # Lazarus project
├── src/
│   ├── NotepadLPP.lpr           # program entry; single-instance file routing
│   ├── core/                    # UI-FREE, fully unit-tested
│   │   ├── uDocument.pas        # one open doc: path, encoding, EOL, dirty state
│   │   ├── uDocumentManager.pas # collection of docs ↔ tabs
│   │   ├── uEncoding.pas        # detect + convert (wraps EncConv); EOL detect/convert
│   │   ├── uFileIO.pas          # load/save bytes with encoding+EOL round-trip
│   │   ├── uSession.pas         # persist/restore open files + geometry
│   │   └── uConfig.pas          # JSON settings (fpjson)
│   ├── editor/
│   │   ├── uEditorFactory.pas   # build a configured TATSynEdit instance
│   │   ├── uLexers.pas          # register/curate EControl lexers; map ext→lexer
│   │   └── uEditorActions.pas   # line ops, case, sort, comment, trim (UI-free core)
│   ├── search/                  # UI-FREE core, tested
│   │   ├── uSearchEngine.pas    # single-doc find/replace incl. TRegExpr
│   │   ├── uFindInFiles.pas     # threaded dir walk + per-file search
│   │   └── uSearchResults.pas   # result item model
│   ├── tools/                   # UI-FREE core, tested
│   │   ├── uJsonTool.pas        # format/minify/validate (fpjson)
│   │   ├── uXmlTool.pas         # format/validate (laz2_XML*)
│   │   ├── uCsvTool.pas         # parse → rows/cols model
│   │   └── uConverters.pas      # base64, url, uuid, hash, base-convert
│   └── ui/                      # forms (.pas + .lfm); human/xvfb verified
│       ├── uMainForm.{pas,lfm}      # window, menu, toolbar, statusbar, tab host
│       ├── uTabManager.pas          # tab control ↔ DocumentManager wiring
│       ├── uFindDialog.{pas,lfm}
│       ├── uFindResultsPanel.{pas,lfm}
│       ├── uCsvViewer.{pas,lfm}     # grid view over uCsvTool
│       ├── uConvertersDlg.{pas,lfm}
│       ├── uPreferences.{pas,lfm}
│       └── uTheme.pas               # light/dark application
├── lexers/                      # curated EControl lexer definitions
├── themes/                      # light.json, dark.json
├── test/                        # fpcunit suites mirroring core/, search/, tools/, editor/
│   └── TestRunner.lpr
├── packaging/                   # AppImage / .deb scripts (M5)
├── DEPENDENCIES.lock            # pinned dep commits (created M0)
├── CLAUDE.md                    # agent operating manual (Section 9)
└── README.md
```

**Dependency rule:** `ui/` may depend on everything; `core/`, `search/`, `tools/`, `editor/` must **not** depend on `ui/`. The agent enforces this — it's what makes ~70% of the codebase headless‑testable.

---

## 5. Milestones with self‑verifiable acceptance criteria

Each milestone ends in a green build + passing tests + a one‑line capability the agent can demonstrate. Do not advance on a red build.

**M0 — Toolchain & skeleton**
- Install FPC + Lazarus; clone/resolve deps; produce `DEPENDENCIES.lock`.
- Blank `TMainForm` hosts a `TATSynEdit` and shows text.
- ✅ *Accept:* `lazbuild NotepadLPP.lpi` exits 0; app launches under `xvfb-run` without error; ATSynEdit visible with typed text.

**M1 — Editor core, file I/O, tabs, encoding**
- DocumentManager + tabs; New/Open/Save/Save As/Reload/Recent; encoding detect/convert; EOL detect/convert; line numbers; highlighting for curated lexers.
- ✅ *Accept:* open JSON/XML/log/Python files with correct highlighting; **byte‑exact round‑trip** save for UTF‑8, UTF‑8+BOM, UTF‑16LE, UTF‑16BE, CP‑1252 (fpcunit fixtures); EOL conversion verified by tests.

**M2 — Search / Replace / Find‑in‑Files**
- Find/Replace dialog with all options; regex via TRegExpr; threaded Find‑in‑Files with masks + recursion; results panel navigation.
- ✅ *Accept:* unit tests for `uSearchEngine` (plain, case, word, regex, replace‑all, count) and `uFindInFiles` (correct hit set over a fixture tree) pass; manual: double‑click result jumps to file+line.

**M3 — Editing operations & status bar**
- All line ops, case, sort, dedup, trim, comment toggle, indent; full interactive status bar (encoding/EOL switch).
- ✅ *Accept:* `uEditorActions` tests pass on string fixtures; status bar reflects + mutates caret/encoding/EOL/lang live.

**M4 — Built‑in tools**
- JSON/XML format+validate; CSV grid viewer; converters (base64/url/uuid/hash/base).
- ✅ *Accept:* `tools/` test suites pass against known input→output vectors (e.g. RFC 4648 Base64 vectors, NIST SHA‑256 vectors, malformed‑JSON error position).

**M5 — Persistence, theming, packaging**
- JSON config + session restore + recent files; light/dark theme; AppImage and/or `.deb`.
- ✅ *Accept:* settings + open files survive restart; theme toggles live; `packaging/` produces an artifact that installs and launches on a clean Mint/Ubuntu VM.

---

## 6. Open decisions flagged for the human (don't let the agent silently pick)

1. **Encoding scope.** Your "UTF‑8 + ANSI only" instinct undercounts reality: Windows‑origin files (PowerShell output, registry/Event Log exports, some configs) are frequently **UTF‑16LE with BOM**. Recommendation kept in §3.1: UTF‑8 (±BOM), UTF‑16 LE/BE, CP‑1252. Keep `uEncoding` behind an interface so adding encodings later is a one‑file change. **Confirm or override.**
2. **Regex parity ceiling.** TRegExpr is Perl‑family but not Boost. ~90% of NPP patterns will behave identically; exotic constructs (`\K`, possessive quantifiers, some lookaround, full Unicode property classes) may differ. Acceptable for Phase 1? **Confirm.**
3. **License:** GPLv3 vs MPL‑2.0 (see header). **Pick before M0** — it affects file headers the agent will generate.
4. **Widgetset:** gtk2 (recommended first) vs qt5. Affects native look and a few quirks. Default gtk2 unless you say otherwise.

---

## 7. Autonomy assessment — where Opus will sail vs. stall

Since the explicit goal is to probe how far autonomous Opus gets, here's the honest forecast so you can place your human checkpoints where they matter.

**High autonomy (expect near‑hands‑off):** everything in `core/`, `search/`, `tools/`, `editor/uEditorActions`. These are pure Object Pascal logic with deterministic test vectors. Strong training data for FPC stdlib (`fpjson`, `laz2_XML*`, hashing, TRegExpr). This is ~60–70% of the line count.

**Medium autonomy (expect iteration, needs the doc‑reading discipline of §1.4):** ATSynEdit / EControl / EncConv integration in `editor/` and `uEncoding`. These components are niche; the agent *will* be tempted to invent method names. Mitigations: have it read upstream sources first, build a tiny throwaway spike per component before real integration, and keep the compiler in the loop every few edits. This is the **primary risk surface** for the whole project.

**Low autonomy (plan for human involvement):**
- **`.lfm` form layout & visual UX.** The agent can generate forms, but spacing, tab‑order, toolbar feel, and "does this look like NPP" need a human eye. Budget human time here.
- **Interactive smoke testing.** Headless logic tests are automatable; clicking through dialogs is not. Use `xvfb-run` for "does it launch / not crash," but real UX validation is manual.
- **Dependency build quirks & packaging.** Widgetset mismatches, AppImage glibc/runtime bundling, desktop‑file/icon wiring — historically fiddly; expect to co‑drive.

**Recommended operating posture:** let the agent run M0–M4 logic with a hard rule of "compile + test green before proceeding," review form files and do UX smoke tests at the end of M1 and M3, and pair with it through M5 packaging. Set up the `fpcunit` runner and a CI compile step at M0 so the agent's self‑verification is real rather than asserted.

---

## 8. First actions for the agent (paste‑ready kickoff)

```
1. Read this spec end to end. Confirm the four §6 decisions are resolved
   (license, encoding scope, regex ceiling, widgetset). If unresolved, stop and ask.
2. M0: install FPC 3.2.2+ and Lazarus; clone deps (ATSynEdit, ATSynEdit_Cmp,
   ATSynEdit_Ex, EControl, EncConv, BGRABitmap; ATFlatControls only if needed).
   Resolve the minimal closure that compiles a blank ATSynEdit form.
   Write DEPENDENCIES.lock with pinned commits.
3. Before writing ANY ATSynEdit/EControl/EncConv call, read that component's
   README/source. Do not invent APIs. Build a throwaway spike to confirm the
   API, then delete it.
4. Scaffold the tree in §4. Set up TestRunner.lpr + a CI compile step.
5. Implement milestone by milestone (§5). Compile via `lazbuild` and run tests
   after each unit. Never advance on a red build.
6. At the end of M1 and M3, pause for human UX smoke test.
```

---

## 9. CLAUDE.md (repo‑root agent manual — create this file)

```markdown
# NotepadL++ — Claude Code operating manual

## Build
- Compile:        lazbuild NotepadLPP.lpi
- Run (headless): xvfb-run -a ./notepadlpp
- Tests:          lazbuild test/TestRunner.lpi && ./test/TestRunner --all --format=plain

## Language conventions
- {$mode objfpc}{$H+} in every unit. No Delphi-only constructs.
- Unit prefix: u<Name>.pas. One responsibility per unit.
- Layer rule: core/ search/ tools/ editor/ MUST NOT use ui/.

## Dependencies
- Use ONLY the components in DEPENDENCIES.lock at their pinned commits.
- ATSynEdit / EControl / EncConv: READ THE SOURCE before calling. Never guess a
  method signature — grep the cloned repo and confirm.
- Treat ATSynEdit/EControl as read-only upstream. Wrap, never patch.

## Workflow
- Compile + run the relevant test suite after every unit edit.
- Do not advance milestones (see ARCHITECTURE §5) on a red build.
- New logic feature => new fpcunit test with explicit input→output vectors.
- Forms (.lfm): build + xvfb launch to confirm no crash; flag for human UX review.

## Definition of done (per unit)
1. Compiles clean (no warnings on our code).
2. Tests pass (logic units).
3. No ui/ dependency leak into core layers.
```
