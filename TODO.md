# TODO

Issues and ideas collected while using DiffIt day to day. Keep entries short; move anything that becomes a plan into a commit.

## Known gaps

- Scroll position after a live reload is kept by row index, not by content, so lines inserted above the viewport shift what is visible.
- Watching stops for a file that stays deleted for more than 2 s; Reload (⌘R) or reselecting the file re-arms it.
- Beyond 1000 watched files only the selected file is watched (reloaded when selected).
- No "missing final newline" marker in the gutter.

## Ideas

- Match scroll position by content across reloads.
- Ignore-whitespace option (needs plumbing through `DiffOptions`).
- Soft wrap.
