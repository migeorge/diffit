# TODO

Issues and ideas collected while using DiffIt day to day. Keep entries short; move anything that becomes a plan into a commit.

## Known gaps

- The line diff does not slide hunks to indentation boundaries (git's indent heuristic), so a moved function can leave its closing brace and the blank line after it as a separate removed/added pair.
- Beyond 1000 watched files only the selected file is watched (reloaded when selected).
- No "missing final newline" marker in the gutter.

- Syntax highlighting has no language injection beyond Markdown inline: fenced code in Markdown, JS inside HTML and SQL in strings are one colour.
- The language is chosen per file, so a `.h` header is always coloured as C (never C++ or Objective-C).

## Ideas

- Ignore-whitespace option (needs plumbing through `DiffOptions`).
- Soft wrap.
- Language picker per file (override the extension-based choice).
