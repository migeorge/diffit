import AppKit
import DiffCore

/// Builds the per-side attributed string and line metadata from a `DiffResult`.
enum DiffTextBuilder {
    struct Style {
        var font: NSFont
        var tabWidth: Int
        var intraLineHighlights = true

        /// Every row is forced to this height so row index ↔ y position is plain arithmetic.
        var lineHeight: CGFloat { DiffTextBuilder.lineHeight(for: font) }
    }

    static func build(_ result: DiffResult, side: DiffSide, style: Style) -> DiffPaneContent {
        let lines = side == .old ? result.oldLines : result.newLines
        let rows = result.rows

        var joined = String()
        joined.reserveCapacity(lines.reduce(0) { $0 + $1.utf8.count } + rows.count)
        var lineStarts: [Int] = []
        var rowKinds: [RowKind] = []
        var isFiller: [Bool] = []
        var sourceLineNumbers: [Int?] = []
        var highlights: [(line: Int, ranges: [Range<Int>])] = []
        lineStarts.reserveCapacity(rows.count)
        rowKinds.reserveCapacity(rows.count)
        isFiller.reserveCapacity(rows.count)
        sourceLineNumbers.reserveCapacity(rows.count)

        var offset = 0
        for (rowIndex, row) in rows.enumerated() {
            let sourceIndex = side == .old ? row.oldLine : row.newLine
            lineStarts.append(offset)
            rowKinds.append(row.kind)
            isFiller.append(sourceIndex == nil)
            sourceLineNumbers.append(sourceIndex.map { $0 + 1 })
            if let sourceIndex {
                let line = lines[sourceIndex]
                joined.append(line)
                offset += line.utf16.count
                if style.intraLineHighlights, row.kind == .modified {
                    let ranges = side == .old ? row.oldHighlights : row.newHighlights
                    if !ranges.isEmpty { highlights.append((rowIndex, ranges)) }
                }
            }
            if rowIndex < rows.count - 1 {
                joined.append("\n")
                offset += 1
            }
        }

        let text = NSMutableAttributedString(string: joined, attributes: baseAttributes(style))
        let strong = Theme.strongHighlight(side: side)
        let length = text.length
        text.beginEditing()
        for (line, ranges) in highlights {
            let start = lineStarts[line]
            for range in ranges {
                let location = start + range.lowerBound
                let end = min(start + range.upperBound, length)
                guard location < end else { continue }
                text.addAttribute(.backgroundColor, value: strong, range: NSRange(location: location, length: end - location))
            }
        }
        text.endEditing()

        return DiffPaneContent(side: side, text: text, lineStarts: lineStarts, rowKinds: rowKinds,
                               isFiller: isFiller, sourceLineNumbers: sourceLineNumbers,
                               changeBlocks: result.changeBlocks, lineHeight: style.lineHeight,
                               textWidth: widestLine(lines, style: style))
    }

    // MARK: - Measuring

    /// Width of the widest line. Only the longest lines by length are measured, since measuring
    /// every line of a large file would cost more than the diff itself.
    static func widestLine(_ lines: [String], style: Style) -> CGFloat {
        let candidates = lines.enumerated()
            .map { ($0.offset, $0.element.utf16.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(32)
        let attributes = baseAttributes(style)
        var widest: CGFloat = 0
        for (index, _) in candidates {
            widest = max(widest, (lines[index] as NSString).size(withAttributes: attributes).width)
        }
        return ceil(widest)
    }

    // MARK: - Attributes

    static func baseAttributes(_ style: Style) -> [NSAttributedString.Key: Any] {
        [
            .font: style.font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(font: style.font, tabWidth: style.tabWidth),
            .ligature: 0,
        ]
    }

    static func paragraphStyle(font: NSFont, tabWidth: Int) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.tabStops = []
        style.defaultTabInterval = CGFloat(max(tabWidth, 1)) * zeroAdvance(font)
        style.lineBreakMode = .byClipping
        // Fixed row height: fallback glyphs (emoji, CJK) must not make a row taller than its
        // counterpart in the other pane, and it lets row positions be computed without layout.
        let height = lineHeight(for: font)
        style.minimumLineHeight = height
        style.maximumLineHeight = height
        return style
    }

    static func lineHeight(for font: NSFont) -> CGFloat {
        ceil(NSLayoutManager().defaultLineHeight(for: font))
    }

    /// Advance of "0" in the font — the unit for tab stops and gutter widths.
    static func zeroAdvance(_ font: NSFont) -> CGFloat {
        let width = ("0" as NSString).size(withAttributes: [.font: font]).width
        return width > 0 ? width : font.pointSize * 0.6
    }
}
