extension LanguageSpec {
    static let json: LanguageSpec = {
        var spec = LanguageSpec()
        spec.constants = ["true", "false", "null"]
        spec.lineComments = [pattern("//")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("\"")]
        spec.keyMarker = pattern(":")
        return spec
    }()

    static let toml: LanguageSpec = {
        var spec = LanguageSpec()
        spec.constants = ["true", "false", "inf", "nan"]
        spec.lineComments = [pattern("#")]
        spec.strings = [StringStyle("\"\"\"", multiline: true), StringStyle("'''", escapes: false, multiline: true),
                        StringStyle("\""), StringStyle("'", escapes: false)]
        spec.identifierExtra = [ch("-"), ch(".")]
        spec.numberExtra = [ch("-"), ch(":"), ch("+")]
        spec.keyMarker = pattern("=")
        spec.sectionHeaders = true
        return spec
    }()

    static let sql: LanguageSpec = {
        var spec = LanguageSpec()
        spec.keywords = ["select", "from", "where", "insert", "into", "values", "update", "set", "delete", "create", "table", "drop",
                         "alter", "add", "column", "index", "view", "as", "on", "join", "inner", "left", "right", "full", "outer",
                         "cross", "natural", "and", "or", "not", "is", "in", "exists", "between", "like", "ilike", "limit", "offset",
                         "order", "by", "group", "having", "distinct", "union", "all", "except", "intersect", "case", "when", "then",
                         "else", "end", "primary", "key", "foreign", "references", "default", "unique", "check", "constraint", "if",
                         "begin", "commit", "rollback", "transaction", "with", "recursive", "returning", "asc", "desc", "cascade",
                         "truncate", "grant", "revoke", "explain", "analyze", "using", "temporary", "temp", "replace", "database",
                         "schema", "trigger", "procedure", "function", "returns", "language", "declare", "cursor", "fetch", "for",
                         "each", "row", "before", "after", "instead", "of", "execute", "exec", "to", "over", "partition", "window",
                         "rows", "range", "preceding", "following", "current", "unbounded", "nulls", "first", "last", "materialized",
                         "collate", "type", "domain", "sequence", "comment", "lock", "share", "mode", "vacuum", "rename", "cast",
                         "any", "some", "top", "merge", "matched", "do", "nothing", "conflict", "auto_increment", "autoincrement",
                         "engine", "charset", "if", "loop", "while", "return", "elseif", "end"]
        spec.caseInsensitive = true
        spec.types = ["int", "integer", "bigint", "smallint", "tinyint", "serial", "bigserial", "varchar", "char", "character", "text",
                      "boolean", "bool", "date", "time", "timestamp", "timestamptz", "interval", "numeric", "decimal", "real",
                      "float", "double", "precision", "json", "jsonb", "uuid", "bytea", "blob", "clob", "binary", "varbinary",
                      "money", "bit", "enum", "array", "datetime", "nvarchar", "nchar", "number", "varchar2", "identity"]
        spec.constants = ["true", "false", "null", "current_date", "current_time", "current_timestamp"]
        spec.functionDefiners = ["function", "procedure"]
        spec.lineComments = [pattern("--")]
        spec.blockComment = (pattern("/*"), pattern("*/"))
        spec.strings = [StringStyle("'", escapes: false, multiline: true)]
        spec.variablePrefixes = [pattern("@"), pattern("$"), pattern(":")]
        return spec
    }()
}
