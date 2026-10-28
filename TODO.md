# TODO

Issues and ideas collected while using DiffIt day to day. Keep entries short; move anything that becomes a plan into a commit.

## Known gaps

- The line diff does not slide hunks to indentation boundaries (git's indent heuristic), so a moved function can leave its closing brace and the blank line after it as a separate removed/added pair.
- Beyond 1000 watched files only the selected file is watched (reloaded when selected).
- No "missing final newline" marker in the gutter.

- Syntax highlighting is lexical: function and type names come from heuristics (word after `func`/`def`, capitalised word, word before `(`), so an exported Go variable or a capitalised C function can get the wrong colour. SQL or HTML inside string literals is one colour.
- Shell highlighting guesses the command word by position; words after unusual separators (`||` at a line start after a continuation, `time -p`) can miss.
- The language is chosen per file, so a `.h` header is always coloured as C (never C++ or Objective-C).

## Ideas

- Ignore-whitespace option (needs plumbing through `DiffOptions`).
- Soft wrap.
- Language picker per file (override the extension-based choice).
