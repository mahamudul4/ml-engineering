import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../features/lessons/horizontal_reading_view.dart';
import 'code_block.dart';
import 'theme.dart';

/// Lightweight, offline rich prose renderer supporting:
/// - **bold** key phrases
/// - `inline code` monospace pills
/// - $inline LaTeX$ equations (rendered via flutter_math_fork)
/// - $$display LaTeX$$ equation cards (horizontally scrollable)
/// - Bullet (- / •) and numbered (1. / ১.) indented points
/// - > Blockquote example / key takeaway cards
/// - Fenced ```python ... ``` short code snippets
/// - Markdown comparison tables (| A | B |)
class RichProse extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double paragraphSpacing;
  final bool selectable;

  const RichProse(
    this.text, {
    super.key,
    this.style,
    this.paragraphSpacing = 12,
    this.selectable = true,
  });

  static final _inlinePattern = RegExp(
    r'\*\*(.+?)\*\*|`([^`]+)`|\$(?!\s)([^\$\n\u0980-\u09FF]+?)(?<!\s)\$',
  );
  static final _bulletPattern = RegExp(r'^\s*(?:[-•*])\s+(.*)$');
  static final _numberedPattern = RegExp(r'^\s*([0-9০-৯]+[.)])\s+(.*)$');
  static final _tableSepPattern = RegExp(
    r'^\|?(?:\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$',
  );
  static final _currencyLikePattern = RegExp(
    r'^[0-9][0-9,\.]*(?:\s*[KMBkmbx×%/-]|\s+(?:per|to|or|and|month|day|year|query|M|K|B))',
  );

  static bool _isLikelyInlineLatex(String expr) {
    final trimmed = expr.trim();
    if (trimmed.isEmpty) return false;
    // Guard against currency ranges like "$100 to $200" if ever unbackticked.
    if (_currencyLikePattern.hasMatch(trimmed) && !trimmed.contains(r'\')) {
      return false;
    }
    return true;
  }

  /// Extracts every display (`$$...$$`) and inline (`$...$`) LaTeX expression
  /// that [RichProse] will render from [raw]. Used by editorial math QA tests.
  static List<String> extractLatexExpressions(String raw) {
    final found = <String>[];
    if (!_hasRichStructureStatic(raw)) return found;
    final blocks = _parseBlocksStatic(raw);
    void collectInline(String src) {
      for (final m in _inlinePattern.allMatches(src)) {
        final bold = m.group(1);
        final math = m.group(3);
        if (bold != null) {
          if (bold.contains('`') || bold.contains(r'$')) {
            collectInline(bold);
          }
        } else if (math != null && _isLikelyInlineLatex(math)) {
          found.add(math.trim());
        }
      }
    }

    for (final b in blocks) {
      if (b is _MathBlock) {
        found.add(b.tex);
      } else if (b is _ParagraphBlock) {
        collectInline(b.body);
      } else if (b is _ListItemBlock) {
        collectInline(b.body);
      } else if (b is _CalloutQuoteBlock) {
        collectInline(b.body);
      } else if (b is _TableBlock) {
        for (final h in b.headers) {
          collectInline(h);
        }
        for (final row in b.rows) {
          for (final cell in row) {
            collectInline(cell);
          }
        }
      }
    }
    return found;
  }

  static bool _hasRichStructureStatic(String raw) =>
      raw.contains('**') ||
      raw.contains('`') ||
      raw.contains('```') ||
      raw.contains(r'$$') ||
      _inlinePattern.hasMatch(raw) ||
      raw.contains('\n- ') ||
      raw.contains('\n• ') ||
      raw.contains('\n> ') ||
      raw.startsWith('- ') ||
      raw.startsWith('• ') ||
      raw.startsWith('> ') ||
      raw.contains('\n|') ||
      raw.startsWith('|') ||
      RegExp(r'(^|\n)\s*[0-9০-৯]+[.)]\s+').hasMatch(raw);

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ??
        TextStyle(
          fontFamily: 'NotoSansBengali',
          fontFamilyFallback: const ['Manrope', 'NotoSansMath', 'NotoSans'],
          fontSize: 14,
          height: 2.0,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .90),
        );

    if (!_hasRichStructureStatic(text)) {
      return selectable
          ? SelectableText(text, style: baseStyle)
          : Text(text, style: baseStyle);
    }

    final blocks = _parseBlocksStatic(text);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final column = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < blocks.length; i++) ...[
              if (i > 0)
                SizedBox(height: blocks[i].topSpacing(paragraphSpacing)),
              _buildBlock(context, blocks[i], baseStyle, availWidth),
            ],
          ],
        );
        return selectable ? SelectionArea(child: column) : column;
      },
    );
  }

  static List<_ProseBlock> _parseBlocksStatic(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').split('\n');
    final out = <_ProseBlock>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 1. Fenced code block: ```python ... ```
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        final buf = <String>[];
        i++;
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          buf.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // consume closing ```
        out.add(
          _CodeSnippetBlock(
            code: buf.join('\n').trimRight(),
            label: lang.isEmpty ? 'Python Snippet' : lang.toUpperCase(),
          ),
        );
        continue;
      }

      // 2. Display LaTeX math block: $$ ... $$ (single-line or multi-line)
      if (trimmed.startsWith(r'$$')) {
        if (trimmed.length >= 4 && trimmed.endsWith(r'$$')) {
          final inner = trimmed.substring(2, trimmed.length - 2).trim();
          if (inner.isNotEmpty) {
            out.add(_MathBlock(inner));
          }
          i++;
          continue;
        }
        final buf = <String>[];
        final firstRest = trimmed.substring(2).trim();
        if (firstRest.isNotEmpty) buf.add(firstRest);
        i++;
        while (i < lines.length) {
          final cur = lines[i].trim();
          if (cur.endsWith(r'$$')) {
            final before = cur.substring(0, cur.length - 2).trim();
            if (before.isNotEmpty) buf.add(before);
            i++;
            break;
          }
          buf.add(lines[i]);
          i++;
        }
        final tex = buf.join('\n').trim();
        if (tex.isNotEmpty) out.add(_MathBlock(tex));
        continue;
      }

      // 3. Markdown pipe table
      if (trimmed.startsWith('|') &&
          i + 1 < lines.length &&
          _tableSepPattern.hasMatch(lines[i + 1].trim())) {
        final header = _splitTableRow(trimmed);
        i += 2; // skip header & separator
        final rows = <List<String>>[];
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          rows.add(_splitTableRow(lines[i].trim()));
          i++;
        }
        out.add(_TableBlock(headers: header, rows: rows));
        continue;
      }

      // 4. Blockquote callout (> ...)
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          final stripped = lines[i].trim().replaceFirst(RegExp(r'^>\s?'), '');
          quoteLines.add(stripped);
          i++;
        }
        out.add(_CalloutQuoteBlock(quoteLines.join('\n').trim()));
        continue;
      }

      // 5. Bullet point (- / •)
      final bulletMatch = _bulletPattern.firstMatch(line);
      if (bulletMatch != null) {
        out.add(_ListItemBlock(marker: '•', body: bulletMatch.group(1)!.trim()));
        i++;
        continue;
      }

      // 6. Numbered point (1. / ১.)
      final numMatch = _numberedPattern.firstMatch(line);
      if (numMatch != null) {
        out.add(
          _ListItemBlock(
            marker: numMatch.group(1)!,
            body: numMatch.group(2)!.trim(),
            isNumbered: true,
          ),
        );
        i++;
        continue;
      }

      // 7. Regular paragraph lines until next blank or special block
      final para = <String>[trimmed];
      i++;
      while (i < lines.length) {
        final next = lines[i];
        final nextTrim = next.trim();
        if (nextTrim.isEmpty ||
            nextTrim.startsWith('```') ||
            nextTrim.startsWith(r'$$') ||
            nextTrim.startsWith('>') ||
            nextTrim.startsWith('|') ||
            _bulletPattern.hasMatch(next) ||
            _numberedPattern.hasMatch(next)) {
          break;
        }
        para.add(nextTrim);
        i++;
      }
      out.add(_ParagraphBlock(para.join(' ')));
    }
    return out;
  }

  static List<String> _splitTableRow(String line) {
    var clean = line.trim();
    if (clean.startsWith('|')) clean = clean.substring(1);
    if (clean.endsWith('|')) clean = clean.substring(0, clean.length - 1);
    return clean.split('|').map((cell) => cell.trim()).toList();
  }

  Widget _buildBlock(
    BuildContext context,
    _ProseBlock block,
    TextStyle baseStyle,
    double availWidth,
  ) {
    if (block is _CodeSnippetBlock) {
      return CodeBlock(code: block.code, title: block.label);
    }
    if (block is _MathBlock) {
      final mathWidget = Math.tex(
        block.tex,
        mathStyle: MathStyle.display,
        textStyle: TextStyle(
          fontSize: 17,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: HorizontalReadingView(
          hint: 'পুরো সমীকরণ দেখতে ডানে-বাঁয়ে সরান।',
          child: mathWidget.parseError == null
              ? mathWidget
              : SelectableText(
                  block.tex,
                  style: baseStyle.copyWith(fontFamily: 'monospace'),
                ),
        ),
      );
    }
    if (block is _CalloutQuoteBlock) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final innerWidth = (availWidth - 36).clamp(60.0, 2000.0);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: forest.withValues(alpha: isDark ? .14 : .06),
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: forest, width: 3.5)),
        ),
        child: _richText(
          context,
          block.body,
          baseStyle,
          maxInlineWidth: innerWidth,
        ),
      );
    }
    if (block is _ListItemBlock) {
      final innerWidth = (availWidth - 32).clamp(60.0, 2000.0);
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                block.marker,
                style: baseStyle.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _richText(
                context,
                block.body,
                baseStyle,
                maxInlineWidth: innerWidth,
              ),
            ),
          ],
        ),
      );
    }
    if (block is _TableBlock) {
      return _buildTable(context, block, baseStyle);
    }
    final p = block as _ParagraphBlock;
    return _richText(
      context,
      p.body,
      baseStyle,
      maxInlineWidth: (availWidth - 4).clamp(60.0, 2000.0),
    );
  }

  Widget _richText(
    BuildContext context,
    String source,
    TextStyle baseStyle, {
    required double maxInlineWidth,
  }) {
    final span = _buildInlineSpan(
      context,
      source,
      baseStyle,
      maxInlineWidth: maxInlineWidth,
    );
    return Text.rich(span);
  }

  Widget _buildTable(
    BuildContext context,
    _TableBlock table,
    TextStyle baseStyle,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = Theme.of(context).dividerColor;
    final headerBg = forest.withValues(alpha: isDark ? .22 : .10);
    final stripeBg = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: isDark ? .04 : .025);
    final colCount = table.headers.length;
    final cellStyle = baseStyle.copyWith(fontSize: 12, height: 1.7);
    final colWidths = <int, TableColumnWidth>{};
    for (var c = 0; c < colCount; c++) {
      var maxLen = table.headers[c].length;
      for (final row in table.rows) {
        if (c < row.length && row[c].length > maxLen) {
          maxLen = row[c].length;
        }
      }
      final w = (maxLen * 7.5 + 36).clamp(112.0, 250.0);
      colWidths[c] = FixedColumnWidth(w);
    }

    return HorizontalReadingView(
      hint: 'টেবিলের বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          columnWidths: colWidths,
          border: TableBorder.symmetric(
            inside: BorderSide(color: borderColor.withValues(alpha: .7)),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: headerBg),
              children: [
                for (var c = 0; c < colCount; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text.rich(
                      _buildInlineSpan(
                        context,
                        table.headers[c],
                        cellStyle.copyWith(fontWeight: FontWeight.w800),
                        maxInlineWidth:
                            (colWidths[c]! as FixedColumnWidth).value - 26,
                      ),
                    ),
                  ),
              ],
            ),
            for (var r = 0; r < table.rows.length; r++)
              TableRow(
                decoration: BoxDecoration(
                  color: r.isOdd ? stripeBg : Colors.transparent,
                ),
                children: [
                  for (var c = 0; c < colCount; c++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      child: Text.rich(
                        _buildInlineSpan(
                          context,
                          c < table.rows[r].length ? table.rows[r][c] : '',
                          cellStyle,
                          maxInlineWidth:
                              (colWidths[c]! as FixedColumnWidth).value - 26,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  TextSpan _buildInlineSpan(
    BuildContext context,
    String source,
    TextStyle baseStyle, {
    required double maxInlineWidth,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final codeBg = isDark
        ? const Color(0xFF26352C)
        : const Color(0xFFEAF0E8);
    final codeFg = isDark ? lime : const Color(0xFF125239);
    final boldColor = Theme.of(context).colorScheme.onSurface;

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlinePattern.allMatches(source)) {
      if (match.start > cursor) {
        children.add(
          TextSpan(
            text: source.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }
      final boldText = match.group(1);
      final codeText = match.group(2);
      final mathText = match.group(3);
      if (boldText != null) {
        if (boldText.contains('`') || boldText.contains(r'$')) {
          children.add(
            _buildInlineSpan(
              context,
              boldText,
              baseStyle.copyWith(fontWeight: FontWeight.w800, color: boldColor),
              maxInlineWidth: maxInlineWidth,
            ),
          );
        } else {
          children.add(
            TextSpan(
              text: boldText,
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w800,
                color: boldColor,
              ),
            ),
          );
        }
      } else if (codeText != null) {
        children.add(
          TextSpan(
            text: ' $codeText ',
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const ['Manrope', 'NotoSansBengali'],
              fontSize: (baseStyle.fontSize ?? 14) - 1.5,
              fontWeight: FontWeight.w700,
              color: codeFg,
              backgroundColor: codeBg,
            ),
          ),
        );
      } else if (mathText != null && _isLikelyInlineLatex(mathText)) {
        final tex = mathText.trim();
        final mathFontSize = ((baseStyle.fontSize ?? 14) + 0.5).clamp(13.5, 28.0);
        // flutter_math_fork 0.7.4 throws RenderShiftBaseline constraint errors
        // when \binom / \choose renders inside \frac under MathStyle.text.
        final useDisplayStyle =
            tex.contains(r'\binom') || tex.contains(r'\choose');
        final mathWidget = Math.tex(
          tex,
          mathStyle: useDisplayStyle ? MathStyle.display : MathStyle.text,
          textStyle: TextStyle(
            fontSize: mathFontSize,
            color: boldColor,
          ),
        );
        if (mathWidget.parseError == null) {
          children.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxInlineWidth > 40 ? maxInlineWidth : 40,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: mathWidget,
                  ),
                ),
              ),
            ),
          );
        } else {
          children.add(
            TextSpan(text: source.substring(match.start, match.end), style: baseStyle),
          );
        }
      } else {
        children.add(
          TextSpan(
            text: source.substring(match.start, match.end),
            style: baseStyle,
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < source.length) {
      children.add(TextSpan(text: source.substring(cursor), style: baseStyle));
    }
    return TextSpan(style: baseStyle, children: children);
  }
}

sealed class _ProseBlock {
  double topSpacing(double base) => base;
}

class _ParagraphBlock extends _ProseBlock {
  final String body;
  _ParagraphBlock(this.body);
}

class _ListItemBlock extends _ProseBlock {
  final String marker;
  final String body;
  final bool isNumbered;
  _ListItemBlock({
    required this.marker,
    required this.body,
    this.isNumbered = false,
  });

  @override
  double topSpacing(double base) => base * 0.55;
}

class _CalloutQuoteBlock extends _ProseBlock {
  final String body;
  _CalloutQuoteBlock(this.body);
}

class _CodeSnippetBlock extends _ProseBlock {
  final String code;
  final String label;
  _CodeSnippetBlock({required this.code, required this.label});
}

class _MathBlock extends _ProseBlock {
  final String tex;
  _MathBlock(this.tex);
}

class _TableBlock extends _ProseBlock {
  final List<String> headers;
  final List<List<String>> rows;
  _TableBlock({required this.headers, required this.rows});
}
