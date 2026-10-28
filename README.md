# DiffIt

A native macOS `git difftool` for reading code changes, especially the ones an AI agent just made.

- `git difftool` hands every changed file to a tiny CLI that returns in a few milliseconds; the app collects them all into one window with a file tree.
- Original on the left, changed on the right, aligned row by row, with full-width red/green tints and word-level highlights.
- The working-tree side is watched: save in your editor (or let an agent keep editing) and the diff updates in place, keeping its scroll position.
- View only. Nothing in the app can write to your files.
- Swift, SwiftUI and AppKit. No Electron, no web views. macOS 26 or later.

![DiffIt in dark mode](docs/screenshot-dark.png)

![DiffIt in light mode](docs/screenshot-light.png)

## Install

Requires macOS 26. Put `DiffIt.app` in /Applications, open it, and click **Install Command Line Tool** on the empty window (also in the DiffIt menu). That does two things:

- links `~/.local/bin/diffit` to the tool inside the app bundle, for `diffit OLD NEW` from a terminal (add `~/.local/bin` to your `PATH` for that; git does not need it);
- sets `diff.tool`, `difftool.diffit.cmd` and `difftool.prompt` in `~/.gitconfig`, with the tool's absolute path so it works from any shell or GUI git client.

The setup card disappears once both are in place and comes back if either goes missing (the app moved, the config was edited). **DiffIt ▸ Remove Command Line Tool…** undoes both. The same steps are available from a terminal as `diffit --git-config`, `diffit --git-unconfig` and `diffit --git-check`.

To build from source you need Xcode 26 or the matching Command Line Tools:

```sh
git clone <this repository> diffit
cd diffit
make install      # builds, assembles DiffIt.app in /Applications, symlinks ~/.local/bin/diffit
make git-config   # same as the in-app Install button's git step
```

## Use

```sh
git difftool                 # working tree vs index, every file in one window
git difftool --cached        # index vs HEAD
git difftool main...HEAD     # a branch's changes
git difftool -d              # directory mode also works
diffit OLD NEW               # compare two files without git
diffit /dev/null NEW         # an added file
```

Files opened by one `git difftool` run are grouped as a changeset in the sidebar. Close a changeset with the ⓧ in its header or ⇧⌘W. The app stays running after you close the window so the next `git difftool` opens instantly.

### Keyboard

| Action | Keys |
|---|---|
| Next / previous change | ⌘↓ / ⌘↑ |
| Next / previous file | ⌥⌘↓ / ⌥⌘↑ |
| Bigger / smaller text | ⌘+ / ⌘− |
| Toggle sidebar | ⌃⌘S |
| Reload the selected file | ⌘R |
| Reveal the working-tree file in Finder | ⇧⌘R |
| Open the working-tree file in its default editor | ⇧⌘O |
| Other end of the current moved block | ⇧⌘M |
| Close changeset | ⇧⌘W |
| Settings (font, size, tab width, highlights, moves, syntax colours) | ⌘, |

Lines that moved unchanged to another place in the file are tinted violet at both ends instead of red and green; with such a block current, "Other End of Move" (⇧⌘M) jumps between the two. The detector can be switched off in Settings.

### Syntax highlighting

Code is coloured by a small built-in lexer per language; no grammars to download, no plug-ins, and the binary stays around a megabyte. The language comes from the file extension or file name (or a `#!` line for extensionless scripts). Colours follow Xcode's default theme and can be switched off in Settings.

| Language | Extensions and names |
|---|---|
| Go | `.go` |
| Python | `.py`, `.pyi`, `.pyw`, `#!…python` |
| Shell (bash, zsh, sh) | `.sh`, `.bash`, `.zsh`, `.ksh`, `.bashrc`, `.zshrc`, `.profile`…, `#!…sh` |
| fish | `.fish`, `#!…fish` |
| Markdown | `.md`, `.markdown`, `.mdown`, `.mkd` |
| Swift | `.swift` |
| C | `.c`, `.h` |
| C++ | `.cpp`, `.cc`, `.cxx`, `.hpp`, `.hh`, `.hxx`, `.ino`, `.ipp` |
| Objective-C | `.m`, `.mm` |
| Rust | `.rs` |
| JSON | `.json`, `.jsonc`, `.webmanifest`, `.geojson`, `Package.resolved` |
| YAML | `.yml`, `.yaml` |
| TOML | `.toml`, `Cargo.lock` |
| JavaScript | `.js`, `.mjs`, `.cjs`, `.jsx`, `#!…node` |
| TypeScript / TSX | `.ts`, `.mts`, `.cts` / `.tsx` |
| HTML | `.html`, `.htm`, `.xhtml` |
| CSS | `.css` |
| Ruby | `.rb`, `.rake`, `.gemspec`, `.ru`, `Gemfile`, `Rakefile`, `Podfile`, `Fastfile`, `Brewfile` |
| Java | `.java` |
| Kotlin | `.kt`, `.kts` |
| Scala | `.scala`, `.sc`, `.sbt` |
| Lua | `.lua` |
| Dockerfile | `Dockerfile`, `Containerfile`, `*.dockerfile` |
| Haskell | `.hs` |
| Elixir | `.ex`, `.exs` |
| SQL | `.sql` |
| PHP | `.php`, `.phtml` |
| XML | `.xml`, `.plist`, `.xib`, `.storyboard`, `.entitlements`, `.xcscheme`, `.svg`, `.xsd`, `.xsl` |

Markdown fenced code blocks are coloured as the language named after the fence, HTML `<script>` and `<style>` blocks as JavaScript and CSS, and Dockerfile `RUN` lines as shell. Go, Python, shell, fish and Markdown get the most attention (command words in shells, decorators and f-strings in Python, qualified types in Go, inline marks and nested lists in Markdown); the other languages cover keywords, strings, comments, numbers, attributes and a few heuristics for function and type names.

Vertical scrolling is synchronised between the panes; horizontal scrolling is independent. Text in both panes is selectable and searchable with the standard Find bar.

## How it works

- `diffit` (the CLI) copies git's temporary `$LOCAL`/`$REMOTE` files into `~/Library/Caches/DiffIt` (git deletes them as soon as the CLI exits), references the working-tree file in place, and sends one JSON message over a Unix socket in `~/Library/Application Support/DiffIt`. If the app is not running it launches it.
- The app diffs with a patience algorithm (Myers fallback) in `DiffCore`, builds side-by-side rows, and refines modified lines at the word level.
- Each pane is an `NSTextView` with every row pinned to the same height, so row alignment and scroll sync are plain arithmetic. 50 000-line files open in well under a second.
- A kqueue watcher per working-tree file reloads the diff on write, atomic save, or rename.
- Syntax colours are computed with the diff, off the main thread: a line-by-line lexer per language (`SyntaxHighlight`) carries a small state across lines (open comment, string, fenced block) and emits coloured runs, which `DiffTextBuilder` applies as plain attributed-string colours. The panes stay the same fixed-height `NSTextView`s. Highlighting 25 000 lines of Go takes about 0.3 s.

## Build from source

```sh
swift build          # debug build of the app and the CLI
make test            # unit tests (Swift Testing)
make app             # assemble build/DiffIt.app
make run             # launch it
```

Layout: `Sources/DiffCore` (diff engine, no AppKit), `Sources/DiffItProtocol` (socket messages), `Sources/diffit` (CLI), `Sources/SyntaxHighlight` (per-language lexers → coloured spans), `Sources/DiffItApp` (app), `Tests/`.

There are no package dependencies. Adding a language means a `LanguageSpec` table in `Sources/SyntaxHighlight/Specs` (keywords, comment and string forms, a few heuristic flags), an entry in `SyntaxLanguage`, and a test in `Tests/SyntaxHighlightTests`. `SYNTAX_DUMP=a.go:b.md swift test --filter DumpTests` prints a file with its coloured runs marked, which is the quickest way to tune a table.

## Not in v1

Editing or merging, three-way diffs, soft wrap, image diffs.
