# TreeSitterFish

Generated parser for fish from [ram02z/tree-sitter-fish](https://github.com/ram02z/tree-sitter-fish)
(commit `b7f1d68`, public domain — see `LICENSE`). Vendored because the upstream repository has no
SwiftPM manifest. To update: copy `src/parser.c`, `src/scanner.c`, `src/tree_sitter/*.h` and
`queries/highlights.scm` from the upstream checkout, then run `Scripts/vendor-queries.py`.
