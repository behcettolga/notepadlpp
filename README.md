# NotepadL++

A fast, native Linux text editor in the spirit of Notepad++ — built in Free Pascal / Lazarus on the [ATSynEdit](https://github.com/Alexey-T/ATSynEdit) engine. Multi-tab editing, multi-caret, syntax highlighting, powerful find / replace and find-in-files, and built-in JSON/XML/CSV and developer tools. No plugins required.

> **Status: pre-alpha / under active construction.** Not yet ready for daily use.
> This project is also an experiment: it is being built largely autonomously by an AI coding agent (Claude Code) against a fixed architecture and a test-first acceptance gate. Expect rough edges and incomplete features while Phase 1 lands.

## Why this exists

There is no native Notepad++ for Linux, and while [NotepadNext](https://github.com/dail8859/NotepadNext) is a strong cross-platform reimplementation, it doesn't yet cover the full Notepad++ feature set. NotepadL++ aims at the Notepad++ *native* experience on Linux (Ubuntu / Linux Mint) — lightweight, instant to launch, keyboard-driven — with the most useful "plugin" functionality baked in out of the box.

## Features (Phase 1 scope)

**Editing**
- Multi-tab interface with session restore (reopens your last files and window state)
- Multi-caret and column / block selection
- Syntax highlighting for a curated set of languages (JSON, XML, HTML, CSS, JavaScript, INI/conf, Shell, Python, C/C++, SQL, YAML, Markdown, Diff, Log, plain text)
- Code folding, bracket matching, line numbers, current-line highlight, word wrap, minimap
- Line operations: duplicate, move, sort, remove duplicates, trim trailing whitespace, case conversion, comment/uncomment, indent/outdent

**Files & encoding**
- New / Open / Save / Save As / Reload / Recent files
- Encodings: UTF-8 (with and without BOM), UTF-16 LE, UTF-16 BE, Windows-1252 — with byte-exact round-trip saving
- Line endings: detects and converts LF / CRLF / CR independently of encoding

**Search**
- Find & Replace with match-case, whole-word, regex, wrap-around, count, and mark-all
- Incremental find and go-to-line
- **Find in Files**: across a directory, with file-mask filters and recursion, regex support, and a navigable results panel (targeting ~90% Notepad++ parity)

**Built-in tools (no plugins needed)**
- JSON: pretty-print, minify, validate
- XML: pretty-print, validate
- CSV: tabular grid viewer
- Converters: Base64, URL encode/decode, UUID/GUID generation, hash calculator (MD5 / SHA-1 / SHA-256), numeric base conversion

**UX**
- Light and dark themes
- Status bar with live caret position, selection length, encoding, EOL type, and language — click to change encoding/EOL
- Settings persisted as JSON

## Tech stack

| | |
|---|---|
| Language | Free Pascal (FPC 3.2.2+) |
| UI toolkit | Lazarus LCL (GTK2 target on Linux) |
| Editing core | ATSynEdit (+ ATSynEdit_Cmp, ATSynEdit_Ex) |
| Syntax engine | EControl |
| Encoding | EncConv |

## Building from source

> ⚠️ Build instructions are provisional and will be finalized once the toolchain and dependency set are pinned (see `DEPENDENCIES.lock`).

**Prerequisites**
- Free Pascal 3.2.2 or newer and Lazarus (the distro packages on Mint/Ubuntu work; [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe) is recommended if you need matched FPC/Lazarus versions)
- Dependency packages: ATSynEdit, ATSynEdit_Cmp, ATSynEdit_Ex, EControl, EncConv, BGRABitmap (and ATFlatControls if used)

**Build (headless)**
```bash
git clone https://github.com/<your-user>/notepadlpp.git
cd notepadlpp
# install the dependency packages (via Lazarus OPM or cloned repos), then:
lazbuild NotepadLPP.lpi
```

**Run tests**
```bash
lazbuild test/TestRunner.lpi && ./test/TestRunner --all --format=plain
```

## Roadmap

**Phase 1 (current):** the feature set above — a usable, native single-file/multi-tab editor with built-in tools, no plugin system.

**Phase 2 and beyond (not yet implemented):** a native plugin system / SDK, embedded scripting, macro record & playback, the full lexer set, diff / compare, spell check, function list / code tree, and remote (FTP/SFTP) editing.

## Project documentation

The full functional scope, module architecture, and milestone plan live in [`ARCHITECTURE.md`](ARCHITECTURE.md). That document is the authoritative spec; this README is the short version.

## Licensing

- **NotepadL++ original source:** MPL-2.0
- **ATSynEdit, ATSynEdit_Cmp, ATSynEdit_Ex, ATFlatControls:** MPL-2.0 / LGPL (© Alexey Torgashin)
- **EControl syntax engine:** open-source-use-only license (see its `readme.txt`); closed-source use prohibited
- **BGRABitmap:** modified LGPL (LGPL + static linking exception)

This project is free and open source. Because it bundles EControl, the combined work may be used and redistributed in open-source form only.

## Acknowledgements

Built on the excellent ATSynEdit editing engine and EControl syntax parser by [Alexey Torgashin](https://github.com/Alexey-T), the same foundation that powers [CudaText](https://github.com/Alexey-T/CudaText).
