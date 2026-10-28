// swift-tools-version: 6.0
import PackageDescription

// Tree-sitter grammars are pinned by commit: most grammar repos tag releases without the
// SwiftPM manifest that was added later on their default branch. `Scripts/vendor-queries.py`
// copies each grammar's highlights.scm from these checkouts into SyntaxHighlight.
let grammars: [(name: String, url: String, revision: String)] = [
    ("tree-sitter-go", "https://github.com/tree-sitter/tree-sitter-go", "2346a3ab1bb3857b48b29d779a1ef9799a248cd7"),
    ("tree-sitter-python", "https://github.com/tree-sitter/tree-sitter-python", "26855eabccb19c6abf499fbc5b8dc7cc9ab8bc64"),
    ("tree-sitter-bash", "https://github.com/tree-sitter/tree-sitter-bash", "a06c2e4415e9bc0346c6b86d401879ffb44058f7"),
    ("tree-sitter-c", "https://github.com/tree-sitter/tree-sitter-c", "b780e47fc780ddc8da13afa35a3f4ed5c157823d"),
    ("tree-sitter-cpp", "https://github.com/tree-sitter/tree-sitter-cpp", "c009222808634c1014f82438d4883753516a2c24"),
    ("tree-sitter-rust", "https://github.com/tree-sitter/tree-sitter-rust", "77a3747266f4d621d0757825e6b11edcbf991ca5"),
    ("tree-sitter-swift", "https://github.com/alex-pinkus/tree-sitter-swift", "82bb3a533e0801fd2bbaa11dc49676e10bf41948"),   // tag 0.7.4-with-generated-files
    ("tree-sitter-markdown", "https://github.com/tree-sitter-grammars/tree-sitter-markdown", "41ff24a6c775492c543b09228aeb98d1cd2b3a0f"),
    ("tree-sitter-json", "https://github.com/tree-sitter/tree-sitter-json", "254c42a6476413b776221e03982ac8ae159eeb72"),
    ("tree-sitter-yaml", "https://github.com/tree-sitter-grammars/tree-sitter-yaml", "a1c4812a73ec5e089de8e441fdea3a921e8d5079"),
    ("tree-sitter-toml", "https://github.com/tree-sitter-grammars/tree-sitter-toml", "64b56832c2cffe41758f28e05c756a3a98d16f41"),
    ("tree-sitter-javascript", "https://github.com/tree-sitter/tree-sitter-javascript", "58404d8cf191d69f2674a8fd507bd5776f46cb11"),
    ("tree-sitter-typescript", "https://github.com/tree-sitter/tree-sitter-typescript", "75b3874edb2dc714fb1fd77a32013d0f8699989f"),
    ("tree-sitter-html", "https://github.com/tree-sitter/tree-sitter-html", "73a3947324f6efddf9e17c0ea58d454843590cc0"),
    ("tree-sitter-css", "https://github.com/tree-sitter/tree-sitter-css", "dda5cfc5722c429eaba1c910ca32c2c0c5bb1a3f"),
    ("tree-sitter-ruby", "https://github.com/tree-sitter/tree-sitter-ruby", "ad907a69da0c8a4f7a943a7fe012712208da6dee"),
    ("tree-sitter-java", "https://github.com/tree-sitter/tree-sitter-java", "e10607b45ff745f5f876bfa3e94fbcc6b44bdc11"),
    ("tree-sitter-kotlin", "https://github.com/fwcd/tree-sitter-kotlin", "1852ea17b7f60fb3f9d84e0b1555d56b46b39fb1"),
    ("tree-sitter-lua", "https://github.com/tree-sitter-grammars/tree-sitter-lua", "10fe0054734eec83049514ea2e718b2a56acd0c9"),
    ("tree-sitter-dockerfile", "https://github.com/camdencheek/tree-sitter-dockerfile", "971acdd908568b4531b0ba28a445bf0bb720aba5"),
    ("tree-sitter-objc", "https://github.com/tree-sitter-grammars/tree-sitter-objc", "181a81b8f23a2d593e7ab4259981f50122909fda"),
    ("tree-sitter-haskell", "https://github.com/tree-sitter/tree-sitter-haskell", "97288e585b0bd44199720280d067fa35bacd81ff"),
    ("tree-sitter-elixir", "https://github.com/elixir-lang/tree-sitter-elixir", "cb32ccbe17c67037b09e31bf9beb22cdae6ed8e9"),
    ("tree-sitter-sql", "https://github.com/DerekStride/tree-sitter-sql", "e038788e5d4daba82dea35676bf49a216629e141"),
    ("tree-sitter-php", "https://github.com/tree-sitter/tree-sitter-php", "58d5643086ae60e93a3746cca648363ee97c8761"),
    ("tree-sitter-scala", "https://github.com/tree-sitter/tree-sitter-scala", "c76bab0092b622e34df4916d80b117436683d16e"),
    ("tree-sitter-xml", "https://github.com/tree-sitter-grammars/tree-sitter-xml", "5000ae8f22d11fbe93939b05c1e37cf21117162d"),
]

/// Library product → package, for the grammars whose product name is not derivable.
let grammarProducts: [(product: String, package: String)] = [
    ("TreeSitterGo", "tree-sitter-go"), ("TreeSitterPython", "tree-sitter-python"),
    ("TreeSitterBash", "tree-sitter-bash"), ("TreeSitterC", "tree-sitter-c"),
    ("TreeSitterCPP", "tree-sitter-cpp"), ("TreeSitterRust", "tree-sitter-rust"),
    ("TreeSitterSwift", "tree-sitter-swift"),
    ("TreeSitterMarkdown", "tree-sitter-markdown"),   // also exports TreeSitterMarkdownInline
    ("TreeSitterJSON", "tree-sitter-json"), ("TreeSitterYAML", "tree-sitter-yaml"),
    ("TreeSitterTOML", "tree-sitter-toml"), ("TreeSitterJavaScript", "tree-sitter-javascript"),
    ("TreeSitterTypeScript", "tree-sitter-typescript"),   // also exports TreeSitterTSX
    ("TreeSitterHTML", "tree-sitter-html"), ("TreeSitterCSS", "tree-sitter-css"),
    ("TreeSitterRuby", "tree-sitter-ruby"), ("TreeSitterJava", "tree-sitter-java"),
    ("TreeSitterKotlin", "tree-sitter-kotlin"), ("TreeSitterLua", "tree-sitter-lua"),
    ("TreeSitterDockerfile", "tree-sitter-dockerfile"), ("TreeSitterObjc", "tree-sitter-objc"),
    ("TreeSitterHaskell", "tree-sitter-haskell"), ("TreeSitterElixir", "tree-sitter-elixir"),
    ("TreeSitterSql", "tree-sitter-sql"), ("TreeSitterPHP", "tree-sitter-php"),
    ("TreeSitterScala", "tree-sitter-scala"), ("TreeSitterXML", "tree-sitter-xml"),
]

let package = Package(
    name: "DiffIt",
    platforms: [.macOS("26.0")],
    products: [
        .executable(name: "DiffItApp", targets: ["DiffItApp"]),
        .executable(name: "diffit", targets: ["diffit"]),
        .library(name: "DiffCore", targets: ["DiffCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.25.0"),
    ] + grammars.map { .package(url: $0.url, revision: $0.revision) },
    targets: [
        .target(name: "DiffCore"),
        .target(name: "DiffItProtocol"),
        // fish has no SwiftPM manifest upstream, so its generated parser is vendored.
        .target(
            name: "TreeSitterFish",
            path: "Sources/TreeSitterFish",
            exclude: ["LICENSE", "queries"],
            sources: ["src/parser.c", "src/scanner.c"],
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("src")]
        ),
        // External scanners that the upstream manifests fail to compile (see Scripts/vendor-queries.py).
        .target(
            name: "TreeSitterScanners",
            path: "Sources/TreeSitterScanners",
            exclude: ["css/REVISION", "javascript/REVISION", "lua/REVISION", "python/REVISION", "yaml/REVISION",
                      "yaml/schema.core.c", "yaml/schema.json.c", "yaml/schema.legacy.c"],   // included by yaml/scanner.c
            sources: ["css/scanner.c", "javascript/scanner.c", "lua/scanner.c", "python/scanner.c", "yaml/scanner.c"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "SyntaxHighlight",
            dependencies: [
                .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
                "TreeSitterFish",
                "TreeSitterScanners",
            ] + grammarProducts.map { .product(name: $0.product, package: $0.package) }
        ),
        .executableTarget(name: "diffit", dependencies: ["DiffItProtocol"]),
        .executableTarget(name: "DiffItApp", dependencies: ["DiffCore", "DiffItProtocol", "SyntaxHighlight"]),
        .testTarget(name: "DiffCoreTests", dependencies: ["DiffCore"]),
        .testTarget(name: "DiffItProtocolTests", dependencies: ["DiffItProtocol"]),
        .testTarget(name: "SyntaxHighlightTests", dependencies: ["SyntaxHighlight"]),
    ],
    swiftLanguageModes: [.v5]
)
