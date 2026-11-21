import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import '../features/lessons/horizontal_reading_view.dart';
import 'theme.dart';

class CodeBlock extends StatefulWidget {
  final String code, title;
  const CodeBlock({super.key, required this.code, this.title = 'Python'});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  bool _copied = false;

  static const _bg = Color(0xFF1A221F);
  static const _headerBg = Color(0xFF222D29);
  static const _border = Color(0xFF2F3E38);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Python code copied'),
        duration: Duration(milliseconds: 1400),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1600));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final codeTheme = <String, TextStyle>{
      ...atomOneDarkTheme,
      'root': const TextStyle(
        color: Color(0xFFE4EFE7),
        backgroundColor: _bg,
      ),
      'keyword': const TextStyle(
        color: Color(0xFFD89BF5),
        fontWeight: FontWeight.w700,
      ),
      'built_in': const TextStyle(color: Color(0xFF79D4B5)),
      'title': const TextStyle(
        color: Color(0xFF7DC4FF),
        fontWeight: FontWeight.w700,
      ),
      'number': const TextStyle(color: Color(0xFFF3B878)),
      'string': const TextStyle(color: Color(0xFFA6E39A)),
      'comment': const TextStyle(
        color: Color(0xFF839B8F),
        fontStyle: FontStyle.italic,
      ),
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            decoration: const BoxDecoration(
              color: _headerBg,
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: lime.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PYTHON',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          color: lime,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    if (widget.title.trim().isNotEmpty &&
                        widget.title.trim().toUpperCase() != 'PYTHON')
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontFamilyFallback: ['NotoSansBengali', 'NotoSans'],
                          color: Color(0xFFD1E0D6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _copy,
                  style: TextButton.styleFrom(
                    foregroundColor: _copied ? lime : const Color(0xFFC3D2C8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_outlined,
                    size: 15,
                  ),
                  label: Text(
                    _copied ? 'Copied' : 'Copy',
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          HorizontalReadingView(
            hint: 'Code-এর বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
            hintColor: const Color(0xFFC3D2C8),
            child: HighlightView(
              widget.code,
              language: 'python',
              theme: codeTheme,
              padding: const EdgeInsets.fromLTRB(18, 14, 24, 20),
              textStyle: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: [
                  'NotoSansBengali',
                  'NotoSansMath',
                  'NotoSans',
                ],
                fontSize: 13,
                height: 1.65,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
