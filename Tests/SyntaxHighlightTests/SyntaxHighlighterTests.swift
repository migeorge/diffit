import Foundation
import Testing
@testable import SyntaxHighlight

@Suite struct EveryLanguageTests {
    @Test(arguments: SyntaxLanguage.allCases)
    func highlightsSomething(language: SyntaxLanguage) {
        // Every scanner should colour at least one token of a tiny generic sample.
        let sample = ["# comment", "// comment", "x = \"string\" 42", "<a href=\"x\">t</a>", "SELECT 1;", "func f() {}",
                      "<?php echo 1; ?>", "key: value", "FROM alpine"]
        let spans = SyntaxHighlighter.highlight(lines: sample, language: language)
        #expect(!spans.isEmpty, "\(language) produced no spans")
    }

    @Test(arguments: SyntaxLanguage.allCases)
    func survivesGarbage(language: SyntaxLanguage) {
        let junk = ["\"'`\\", "/* {- <!-- <?php <<EOF", "${", "''' \"\"\" ```", "", "\t\t", "é漢字 🎉 \u{0}"]
        _ = SyntaxHighlighter.highlight(lines: junk, language: language)
        _ = SyntaxHighlighter.highlight(lines: junk.reversed(), language: language)
    }
}

@Suite struct GoTests {
    @Test func declarationsAndCalls() {
        let text = Render.text("""
        package main

        // greet says hi
        func (s *Server) Run(name string) error {
        \treturn fmt.Sprintf("hi %s", name) + "!"
        }
        type Server struct { addr string; items []Item; next *Node }
        """, .go)
        #expect(text.contains("[k:package] main"))
        #expect(text.contains("[c:// greet says hi]"))
        #expect(text.contains("[k:func] (s *[t:Server]) [f:Run](name [t:string]) [t:error]"))
        #expect(text.contains("fmt.[f:Sprintf]([s:\"hi ][e:%s][s:\"], name)"))
        #expect(text.contains("[k:type] [t:Server] [k:struct] { addr [t:string]; items [][t:Item]; next *[t:Node] }"))
    }

    @Test func literalsAndBuiltins() {
        let text = Render.text("x := make([]byte, 0x1F, 1_000)\ns := `raw\n\"still raw\"` // done\nif err != nil { panic(err) }", .go)
        #expect(text.contains("[f:make]([][t:byte], [n:0x1F], [n:1_000])"))
        #expect(text.contains("[s:`raw]\n[s:\"still raw\"`] [c:// done]"))
        #expect(text.contains("[k:if] err != [C:nil] { [f:panic](err) }"))
    }
}

@Suite struct PythonTests {
    @Test func definitionsAndStrings() {
        let text = Render.text("""
        @dataclass
        class Point(Base):
            def area(self, scale: float = 1.5) -> int:
                '''Doc
                string'''
                return len(f"{self.x} and {{literal}}")  # tail
        """, .python)
        #expect(text.contains("[a:@dataclass]"))
        #expect(text.contains("[k:class] [t:Point]([t:Base]):"))
        #expect(text.contains("[k:def] [f:area]([k:self], scale: [t:float] = [n:1.5]) -> [t:int]:"))
        #expect(text.contains("[s:'''Doc]\n[s:        string''']"))
        #expect(text.contains("[k:return] [f:len]([s:f\"][e:{self.x}][s: and {{literal}}\"])  [c:# tail]"))
    }

    @Test func softKeywordsAndConstants() {
        let text = Render.text("match command:\n    case [x]: pass\nresult = re.match(p, s) or None\nMAX = 3", .python)
        #expect(text.contains("[k:match] command:"))
        #expect(text.contains("[k:case] [x]: [k:pass]"))
        #expect(text.contains("re.[f:match](p, s) [k:or] [C:None]"))
        #expect(text.contains("[C:MAX] = [n:3]"))
        #expect(Render.text("b'\\x00\\xff' + rb\"\\d\"", .python) == "[s:b'][e:\\x00\\xff][s:'] + [s:rb\"\\d\"]")
    }
}

@Suite struct ShellTests {
    @Test func bashCommandsAndVariables() {
        let text = Render.text("""
        #!/bin/bash
        set -euo pipefail
        if [ -f "$HOME/.cfg" ]; then
          export PATH="$PATH:/opt/bin" # path
          sudo apt-get install -y curl 2>&1 | tee log.txt
        fi
        greet() { echo "hi ${1:-world}" $#; }
        for f in *.go; do ./build.sh "$f"; done
        """, .bash)
        #expect(text.contains("[c:#!/bin/bash]"))
        #expect(text.contains("[f:set] -euo pipefail"))
        #expect(text.contains("[k:if] [ -f [s:\"][e:$HOME][s:/.cfg\"] ]; [k:then]"))
        #expect(text.contains("[f:export] [p:PATH]=[s:\"][e:$PATH][s::/opt/bin\"] [c:# path]"))
        #expect(text.contains("[f:sudo] [f:apt-get] install -y curl [n:2]>&[n:1] | [f:tee] log.txt"))
        #expect(text.contains("[f:greet]() { [f:echo] [s:\"hi ][e:${1:-world}][s:\"] [p:$#]; }"))
        #expect(text.contains("[k:for] f [k:in] *.go; [k:do] [f:./build.sh] [s:\"][e:$f][s:\"]; [k:done]"))
    }

    @Test func bashCasePatterns() {
        let text = Render.text("case \"$1\" in\n  start|stop) svc $1 ;;\n  darwin*) OS=mac ;;\n  *) echo no ;;\nesac\nx=$(uname)", .bash)
        #expect(text.contains("[k:case] [s:\"][e:$1][s:\"] [k:in]\n  start|stop) [f:svc] [p:$1] ;;\n  darwin*) [p:OS]=mac ;;\n  *) [f:echo] no ;;\n[k:esac]\n[p:x]=$([f:uname])"))
    }

    @Test func bashHeredocAndContinuation() {
        let text = Render.text("cat <<-EOF > out\n\thello $USER\n\tEOF\necho done \\\n  --flag more\nnext", .bash)
        #expect(text.contains("[f:cat] <<-[s:EOF] > out\n[s:\thello ][e:$USER]\n[s:\tEOF]\n[f:echo] done \\\n  --flag more\n[f:next]"))
    }

    @Test func fishFunctionsAndCommands() {
        let text = Render.text("""
        function deploy --argument-names target
            set -l host (hostname)
            if not test -d $target; and echo 'no'
                return 1
            end
            ssh $host "cd $target && make" # go
        end
        """, .fish)
        #expect(text.contains("[k:function] [f:deploy] --argument-names target"))
        #expect(text.contains("[f:set] -l host ([f:hostname])"))
        #expect(text.contains("[k:if] [k:not] [f:test] -d [p:$target]; [k:and] [f:echo] [s:'no']"))
        #expect(text.contains("[k:return] [n:1]"))
        #expect(text.contains("[f:ssh] [p:$host] [s:\"cd ][e:$target][s: && make\"] [c:# go]"))
    }
}

@Suite struct MarkdownTests {
    @Test func blocksAndInline() {
        let text = Render.text("""
        # Title with `code`

        Some **bold**, *em* and _under_ text with a [link](https://x.y) and <b>tag</b>.
        - [ ] item one
        1. item **two**
        > quoted https://example.com/a.
        ---
        Setext
        ===
        """, .markdown)
        #expect(text.contains("[h:# Title with ][`:`code`]"))
        #expect(text.contains("Some [b:**bold**], [i:*em*] and [i:_under_] text with a [L:[link](https://x.y)] and [g:<b>]tag[g:</b>]."))
        #expect(text.contains("[k:-] [k:[ ]] item one"))
        #expect(text.contains("[k:1.] item [b:**two**]"))
        #expect(text.contains("[c:>] quoted [L:https://example.com/a]."))
        #expect(text.contains("[k:---]\nSetext\n[h:===]"))
    }

    @Test func fencedCodeUsesTheLanguage() {
        let text = Render.text("Intro\n```go\nfunc main() {}\n```\n```\nplain\n```\n    indented", .markdown)
        #expect(text.contains("[`:```go]\n[k:func] [f:main]() {}\n[`:```]\n[`:```]\n[`:plain]\n[`:```]\n[`:    indented]"))
    }

    @Test func emphasisDoesNotCrossCodeOrWords() {
        let text = Render.text("snake_case_name and `a * b` then 2 * 3 * 4", .markdown)
        #expect(text == "snake_case_name and [`:`a * b`] then 2 * 3 * 4")
    }
}

@Suite struct SwiftTests {
    @Test func declarationsAndInterpolation() {
        let text = Render.text("""
        /// Doc
        @MainActor struct Point: Equatable { var x: Double = 1.5 }
        let p = Point(x: 2); print("x=\\(p.x) \\n", #"raw \\n"#)
        #if DEBUG
        /* a /* nested */ still */ label: for i in 0..<3 { continue label }
        """, .swift)
        #expect(text.contains("[c:/// Doc]"))
        #expect(text.contains("[a:@MainActor] [k:struct] [t:Point]: [t:Equatable] { [k:var] x: [t:Double] = [n:1.5] }"))
        #expect(text.contains("[k:let] p = [t:Point](x: [n:2]); [f:print]([s:\"x=][e:\\(p.x)][s: ][e:\\n][s:\"], [s:#\"raw \\n\"#])"))
        #expect(text.contains("[a:#if] [C:DEBUG]"))
        #expect(text.contains("[c:/* a /* nested */ still */] label: [k:for] i [k:in] [n:0]..<[n:3] { [k:continue] label }"))
    }
}

@Suite struct CFamilyTests {
    @Test func cAndCpp() {
        let c = Render.text("#include <stdio.h>\nint main(void) { size_t n = MAX_N; return printf(\"x\\n\"); } // ok", .c)
        #expect(c.contains("[a:#include] [s:<stdio.h>]"))
        #expect(c.contains("[t:int] [f:main]([t:void]) { [t:size_t] n = [C:MAX_N]; [k:return] [f:printf]([s:\"x][e:\\n][s:\"]); } [c:// ok]"))
        let cpp = Render.text("class Foo { public: void run() const; };\nauto x = std::make_unique<Foo>(); std::string s;", .cpp)
        #expect(cpp.contains("[k:class] [t:Foo] { [k:public]: [t:void] [f:run]() [k:const]; };"))
        #expect(cpp.contains("[k:auto] x = std::[f:make_unique]<[t:Foo]>(); std::[t:string] s;"))
    }

    @Test func objc() {
        let text = Render.text("@interface Foo : NSObject\n- (void)run:(NSString *)name { NSLog(@\"hi %@\", name); }\n@end", .objc)
        #expect(text.contains("[k:@interface] [t:Foo] : [t:NSObject]"))
        #expect(text.contains("- ([t:void])run:([t:NSString] *)name { [f:NSLog]([s:@\"hi %@\"], name); }"))
        #expect(text.contains("[k:@end]"))
    }
}

@Suite struct RustTests {
    @Test func attributesMacrosLifetimes() {
        let text = Render.text("#[derive(Debug)]\npub fn main<'a>(x: &'a str) -> Result<(), String> { let v: Vec<u8> = vec![1]; println!(\"{x}\"); Ok(()) }", .rust)
        #expect(text.contains("[a:#[derive(Debug)]]"))
        #expect(text.contains("[k:pub] [k:fn] [f:main]<[l:'a]>(x: &[l:'a] [t:str]) -> [t:Result]<(), [t:String]> { [k:let] v: [t:Vec]<[t:u8]> = [a:vec]![[n:1]]; [a:println]!([s:\"][e:{x}][s:\"]); [t:Ok](()) }"))
    }

    @Test func rawStringsAndChars() {
        let text = Render.text("let s = r#\"a \"q\" b\"#; let c = 'x'; let d = b'\\n';", .rust)
        #expect(text.contains("[k:let] s = [s:r#\"a \"q\" b\"#]; [k:let] c = [s:'x']; [k:let] d = [s:b'][e:\\n][s:']"))
    }
}

@Suite struct OtherLanguageTests {
    @Test func json() {
        #expect(Render.text("{\"name\": \"x\", \"n\": [1, true, null]}", .json)
                == "{[p:\"name\"]: [s:\"x\"], [p:\"n\"]: [[n:1], [C:true], [C:null]]}")
    }

    @Test func yaml() {
        let text = Render.text("---\n# c\nname: diffit  # trailing\nlist:\n  - 1.5\n  - \"two\"\n  - key: true\nscript: |\n  echo hi\n  more\nnext: &a !!str x", .yaml)
        #expect(text.contains("[k:---]\n[c:# c]\n[p:name]: diffit  [c:# trailing]\n[p:list]:\n  [k:-] [n:1.5]\n  [k:-] [s:\"two\"]\n  [k:-] [p:key]: [C:true]\n[p:script]: [k:|]\n[s:  echo hi]\n[s:  more]\n[p:next]: [l:&a] [t:!!str] x"))
    }

    @Test func toml() {
        let text = Render.text("[package]\nname = \"x\" # c\nversion = 1.2\n[[bin]]\ndate = 1979-05-27T07:32:00Z\nkeep-alive = true", .toml)
        #expect(text.contains("[t:[package]]\n[p:name] = [s:\"x\"] [c:# c]\n[p:version] = [n:1.2]\n[t:[[bin]]]\n[p:date] = [n:1979-05-27T07:32:00Z]\n[p:keep-alive] = [C:true]"))
    }

    @Test func javascriptAndTypescript() {
        let js = Render.text("const re = /a[/]b/gi; const x = a / b / c;\nreturn <Foo.Bar className=\"x\">{`t ${y}`}</Foo.Bar>;", .javascript)
        #expect(js.contains("[k:const] re = [s:/a[/]b/gi]; [k:const] x = a / b / c;"))
        #expect(js.contains("[k:return] [g:<Foo.Bar] className=[s:\"x\"]>{[s:`t ][e:${y}][s:`]}[g:</Foo.Bar]>;"))
        let ts = Render.text("interface Props { name: string }\nconst f = <T,>(x: T): Promise<T> => fetch(x)", .typescript)
        #expect(ts.contains("[k:interface] [t:Props] { name: [t:string] }"))
        #expect(ts.contains("[k:const] f = <[t:T],>(x: [t:T]): [t:Promise]<[t:T]> => [f:fetch](x)"))
    }

    @Test func html() {
        let text = Render.text("<!DOCTYPE html>\n<div class=\"a\" data-x='1'>&amp; text <!-- c\nmore --> <br/>\n<script>let x = 1;</script>", .html)
        #expect(text.contains("[a:<!DOCTYPE html>]"))
        #expect(text.contains("[g:<div] [a:class]=[s:\"a\"] [a:data-x]=[s:'1'][g:>][e:&amp;] text [c:<!-- c]\n[c:more -->] [g:<br/>]"))
        #expect(text.contains("[g:<script>][k:let] x = [n:1];[g:</script>]"))
    }

    @Test func css() {
        let text = Render.text("@media (max-width: 600px) {\n  .card > a:hover, #id { color: #fff; margin: 1.5em !important; background: url(x.png); }\n}", .css)
        #expect(text.contains("[k:@media] ([p:max-width]: [n:600px]) {"))
        #expect(text.contains("  [p:.card] > [g:a][k::hover], [C:#id] { [p:color]: [n:#fff]; [p:margin]: [n:1.5em] [k:!important]; [p:background]: [f:url](x.png); }"))
    }

    @Test func ruby() {
        let text = Render.text("class Foo < Bar\n  def run?(x = :sym, key: 1)\n    @count += 1 # c\n    puts \"v=#{x}\"\n    text = <<~EOS\n      body\n    EOS\n  end\nend", .ruby)
        #expect(text.contains("[k:class] [t:Foo] < [t:Bar]"))
        #expect(text.contains("[k:def] [f:run?](x = [C::sym], [p:key]: [n:1])"))
        #expect(text.contains("[p:@count] += [n:1] [c:# c]"))
        #expect(text.contains("[f:puts] [s:\"v=][e:#{x}][s:\"]"))
        #expect(text.contains("text = <<~[s:EOS]\n[s:      body]\n[s:    EOS]"))
    }

    @Test func javaKotlinScala() {
        #expect(Render.text("@Override public static void main(String[] args) { int n = MAX; }", .java)
                .contains("[a:@Override] [k:public] [k:static] [t:void] [f:main]([t:String][] args) { [t:int] n = [C:MAX]; }"))
        #expect(Render.text("fun greet(name: String) = println(\"hi $name ${1 + 1}\")", .kotlin)
                .contains("[k:fun] [f:greet](name: [t:String]) = [f:println]([s:\"hi ][e:$name][s: ][e:${1 + 1}][s:\"])"))
        #expect(Render.text("object Main { def run(x: Int): Unit = println(s\"v=$x\") }", .scala)
                .contains("[k:object] [t:Main] { [k:def] [f:run](x: [t:Int]): [t:Unit] = [f:println]([s:s\"v=][e:$x][s:\"]) }"))
    }

    @Test func luaElixirHaskell() {
        #expect(Render.text("local function f(t) return t.x --[[ c ]] end -- tail", .lua)
                .contains("[k:local] [k:function] [f:f](t) [k:return] t.[p:x] [c:--[[ c ]]] [k:end] [c:-- tail]"))
        #expect(Render.text("defmodule Foo do\n  @doc \"x\"\n  def run(a, opts \\\\ []), do: {:ok, ~r/a+/i, \"#{a}\"}\nend", .elixir)
                .contains("[k:defmodule] [t:Foo] [k:do]\n  [a:@doc] [s:\"x\"]\n  [k:def] [f:run](a, opts \\\\ []), [p:do]: {[C::ok], [s:~r/a+/i], [s:\"][e:#{a}][s:\"]}\n[k:end]"))
        #expect(Render.text("{-# LANGUAGE GADTs #-}\nmain :: IO ()\nmain = putStrLn \"hi\" -- c\n  where x' = Just 1", .haskell)
                .contains("[a:{-# LANGUAGE GADTs #-}]\n[f:main] :: [t:IO] ()\n[f:main] = putStrLn [s:\"hi\"] [c:-- c]\n  [k:where] x' = [t:Just] [n:1]"))
    }

    @Test func sqlPhpDockerfile() {
        #expect(Render.text("SELECT COUNT(*) AS n FROM users u WHERE u.age > 18 AND name LIKE 'a%'; -- c", .sql)
                .contains("[k:SELECT] [f:COUNT](*) [k:AS] n [k:FROM] users u [k:WHERE] u.age > [n:18] [k:AND] name [k:LIKE] [s:'a%']; [c:-- c]"))
        #expect(Render.text("<p><?php echo $x->name . \"v=$y\"; // c\n?></p>", .php)
                .contains("[g:<p>][a:<?php] [k:echo] [p:$x]->[p:name] . [s:\"v=][e:$y][s:\"]; [c:// c]\n[a:?>][g:</p>]"))
        #expect(Render.text("FROM golang:1.22 AS build\n# c\nRUN apt-get update && \\\n    make all\nENV PORT=8080 \\\n    HOST=$HOST", .dockerfile)
                .contains("[k:FROM] golang:[n:1.22] [k:AS] build\n[c:# c]\n[k:RUN] [f:apt-get] update && \\\n    [f:make] all\n[k:ENV] PORT=[n:8080] \\\n    HOST=[p:$HOST]"))
    }
}

@Suite struct StateTests {
    @Test func multiLineCommentIsSplitPerLine() {
        let spans = SyntaxHighlighter.highlight(lines: ["/* a", "b", "c */ x"], language: .c)
        let comment = spans.filter { $0.kind == .comment }
        #expect(comment.map(\.line) == [0, 1, 2])
        #expect(comment.last?.range == 0..<4)
    }

    @Test func emptyAndHugeInputs() {
        #expect(SyntaxHighlighter.highlight(lines: [], language: .go).isEmpty)
        #expect(SyntaxHighlighter.highlight(lines: [""], language: .go).isEmpty)
        let huge = [String](repeating: String(repeating: "x", count: 1000), count: SyntaxHighlighter.characterLimit / 1000 + 1)
        #expect(SyntaxHighlighter.highlight(lines: huge, language: .go).isEmpty)
    }

    @Test func spansStayWithinLines() {
        let lines = ["\"unterminated", "é\"", "x"]
        for span in SyntaxHighlighter.highlight(lines: lines, language: .python) {
            #expect(span.range.upperBound <= lines[span.line].utf16.count)
        }
    }
}

@Suite struct DetectionTests {
    @Test func byExtensionAndName() {
        #expect(SyntaxLanguage.detect(path: "/a/b/main.go") == .go)
        #expect(SyntaxLanguage.detect(path: "Sources/App/File.swift") == .swift)
        #expect(SyntaxLanguage.detect(path: "x/Dockerfile") == .dockerfile)
        #expect(SyntaxLanguage.detect(path: "web.dockerfile") == .dockerfile)
        #expect(SyntaxLanguage.detect(path: "Gemfile") == .ruby)
        #expect(SyntaxLanguage.detect(path: "README.MD") == .markdown)
        #expect(SyntaxLanguage.detect(path: "view.tsx") == .tsx)
        #expect(SyntaxLanguage.detect(path: "Info.plist") == .xml)
        #expect(SyntaxLanguage.detect(path: "notes.txt") == nil)
        #expect(SyntaxLanguage.detect(path: "Makefile") == nil)
    }

    @Test func byShebang() {
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/bin/bash") == .bash)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/bin/env python3") == .python)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/local/bin/fish") == .fish)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "#!/usr/bin/env -S node --harmony") == nil)
        #expect(SyntaxLanguage.detect(path: "bin/run", firstLine: "plain text") == nil)
        // The extension wins over a shebang.
        #expect(SyntaxLanguage.detect(path: "tool.py", firstLine: "#!/bin/sh") == .python)
    }

    @Test func fenceNames() {
        #expect(SyntaxLanguage(fenceInfo: "go") == .go)
        #expect(SyntaxLanguage(fenceInfo: "py title=\"x\"") == .python)
        #expect(SyntaxLanguage(fenceInfo: "shell") == .bash)
        #expect(SyntaxLanguage(fenceInfo: "c++") == .cpp)
        #expect(SyntaxLanguage(fenceInfo: "") == nil)
        #expect(SyntaxLanguage(fenceInfo: "mermaid") == nil)
    }
}
