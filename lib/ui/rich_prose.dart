import 'package:flutter/material.dart';

import '../features/lessons/horizontal_reading_view.dart';
import 'code_block.dart';
import 'theme.dart';

/// Lightweight, offline rich prose renderer supporting:
/// - **bold** key phrases
/// - `inline code` monospace pills
/// - Bullet (- / •) and numbered (1. / ১.) indented points
/// - > Blockquote example / key takeaway cards
/// - Fenced ```python ... ``` short code snippets
/// - Markdown comparison tables (| A | B |)
class RichProse extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double paragraphSpacing;

  const RichProse(
    this.text, {
    super.key,
    this.style,
    this.paragraphSpacing = 12,
  });

  static final _inlinePattern = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
  static final _bulletPattern = RegExp(r'^\s*(?:[-•*])\s+(.*)$');
  static final _numberedPattern = RegExp(r'^\s*([0-9০-৯]+[.)])\s+(.*)$');
  static final _tableSepPattern = RegExp(r'^\|?(?:\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$');

  bool _hasRichStructure(String raw) =>
      raw.contains('**') ||
      raw.contains('`') ||
      raw.contains('```') ||
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

    if (!_hasRichStructure(text)) {
      return SelectableText(text, style: baseStyle);
    }

    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) SizedBox(height: blocks[i].topSpacing(paragraphSpacing)),
          _buildBlock(context, blocks[i], baseStyle),
        ],
      ],
    );
  }

  List<_ProseBlock> _parseBlocks(String raw) {
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

      // 2. Markdown pipe table
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

      // 3. Blockquote callout (> ...)
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

      // 4. Bullet point (- / •)
      final bulletMatch = _bulletPattern.firstMatch(line);
      if (bulletMatch != null) {
        out.add(_ListItemBlock(marker: '•', body: bulletMatch.group(1)!.trim()));
        i++;
        continue;
      }

      // 5. Numbered point (1. / ১.)
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

      // 6. Regular paragraph lines until next blank or special block
      final para = <String>[trimmed];
      i++;
      while (i < lines.length) {
        final next = lines[i];
        final nextTrim = next.trim();
        if (nextTrim.isEmpty ||
            nextTrim.startsWith('```') ||
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

  List<String> _splitTableRow(String line) {
    var clean = line.trim();
    if (clean.startsWith('|')) clean = clean.substring(1);
    if (clean.endsWith('|')) clean = clean.substring(0, clean.length - 1);
    return clean.split('|').map((cell) => cell.trim()).toList();
  }

  Widget _buildBlock(
    BuildContext context,
    _ProseBlock block,
    TextStyle baseStyle,
  ) {
    if (block is _CodeSnippetBlock) {
      return CodeBlock(code: block.code, title: block.label);
    }
    if (block is _CalloutQuoteBlock) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: forest.withValues(alpha: isDark ? .14 : .06),
          borderRadius: BorderRadius.circular(10),
          border: const Border(left: BorderSide(color: forest, width: 3.5)),
        ),
        child: SelectableText.rich(
          _buildInlineSpan(context, block.body, baseStyle),
        ),
      );
    }
    if (block is _ListItemBlock) {
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
              child: SelectableText.rich(
                _buildInlineSpan(context, block.body, baseStyle),
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
    return SelectableText.rich(_buildInlineSpan(context, p.body, baseStyle));
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

    return HorizontalReadingView(
      hint: 'টেবিলের বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.symmetric(
            inside: BorderSide(color: borderColor.withValues(alpha: .7)),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: headerBg),
              children: [
                for (final h in table.headers)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text.rich(
                      _buildInlineSpan(
                        context,
                        h,
                        cellStyle.copyWith(fontWeight: FontWeight.w800),
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
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text.rich(
                          _buildInlineSpan(
                            context,
                            c < table.rows[r].length ? table.rows[r][c] : '',
                            cellStyle,
                          ),
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
    TextStyle baseStyle,
  ) {
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
          TextSpan(text: source.substring(cursor, match.start), style: baseStyle),
        );
      }
      final boldText = match.group(1);
      final codeText = match.group(2);
      if (boldText != null) {
        // Support inline `code` nested inside **bold**
        if (boldText.contains('`')) {
          children.add(
            _buildInlineSpan(
              context,
              boldText,
              baseStyle.copyWith(fontWeight: FontWeight.w800, color: boldColor),
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

class _TableBlock extends _ProseBlock {
  final List<String> headers;
  final List<List<String>> rows;
  _TableBlock({required this.headers, required this.rows});
}

