# DiffIt — guidance for Claude Code

Native macOS git difftool for reviewing code changes, especially ones made by AI agents. The authoritative plan is `.plan/PLAN.md`; this file is the short version.

## Non-negotiables

- **View-only.** No code path may write to a user file. Text views are `isEditable = false`. The app writes only under `~/Library/Caches/DiffIt` and `~/Library/Application Support/DiffIt`.
- **Native.** Swift + SwiftUI shell + AppKit `NSTextView` panes. No Electron, no web views, no third-party UI frameworks.
- **CLI returns immediately.** `diffit` must snapshot git's temp files and hand off to the app in < 30 ms when the app is running. git deletes `$LOCAL`/`$REMOTE` temp files the moment the CLI exits.
- **Original on the left, changed on the right.**
- **macOS 26 only**, SwiftPM only (no `.xcodeproj` committed), Swift language mode 5.

## Layout

- `Sources/DiffCore` — pure Swift diff engine (patience + Myers, side-by-side rows, intra-line). No AppKit. Fully unit-tested.
- `Sources/DiffItProtocol` — JSON-over-Unix-socket messages shared by CLI and app. Foundation only.
- `Sources/diffit` — the CLI git invokes once per file.
- `Sources/DiffItApp` — the app. `Model/` (`@Observable`, `@MainActor`), `Views/` (SwiftUI), `AppKit/` (text panes, ruler, theme).
- `Tests/` — Swift Testing (`import Testing`). Run `make test` before every commit touching `DiffCore` or `DiffItProtocol`.

## Workflow

1. Follow the phases in `PLAN.md §10` in order. Finish each phase's **Accept** checks on this machine before starting the next.
2. Where the plan says *verify*, check the API against the SDK before using it; the plan was written without a compiler.
3. Deviations from the plan go in `.plan/DECISIONS.md` (append-only, one paragraph each with the reason).
4. Build: `swift build` · Tests: `make test` (not bare `swift test` — see `DECISIONS.md`) · Bundle: `make app` · Install: `make install && make git-config`.
5. Visual checks: run `open build/DiffIt.app`, feed it files with `.build/release/diffit A B`, take a screenshot (`screencapture -x …`) and look at it in both light and dark mode.
6. The text panes are TextKit 1 (`usingTextLayoutManager: false`) and lay out the whole document once in `DiffTextView.install` (~0.3 s for 50k lines); see `DECISIONS.md` for the measurements. Do not switch a pane to TextKit 2 or to lazy layout casually. Row positions are arithmetic (fixed row height), never derived from layout, and the text view's frame is set by `DiffColumnView` from the row count, never by NSTextView itself.

## Style

- Small files, one type per file where sensible. `// MARK:` sections.
- Prefer root-cause fixes over workarounds; if a workaround is unavoidable, comment why and link the decision.
- No force-unwraps outside tests. Errors surface in the UI (`FileEntry.error`) rather than crashing.
- Commit per meaningful step with descriptive messages.
