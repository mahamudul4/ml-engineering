import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';

import '../features/lessons/horizontal_reading_view.dart';
import 'theme.dart';

class CodeBlock extends StatelessWidget {
  final String code, title;
  const CodeBlock({super.key, required this.code, this.title = 'Python'});

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF222B28),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.code, size: 16, color: lime),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamilyFallback: ['NotoSansBengali'],
                    color: Color(0xFFC3D2C8),
                    fontSize: 11,
                    height: 1.7,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy Python code',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Python code copied')),
                    );
                  }
                },
                icon: const Icon(
                  Icons.copy_outlined,
                  color: Color(0xFFC3D2C8),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
        HorizontalReadingView(
          hint: 'Code-এর বাকি অংশ দেখতে ডানে-বাঁয়ে সরান।',
          hintColor: const Color(0xFFC3D2C8),
          child: HighlightView(
            code,
            language: 'python',
            theme: {
              ...atomOneDarkTheme,
              'root': const TextStyle(
                color: Color(0xFFD9E4DA),
                backgroundColor: Color(0xFF222B28),
              ),
            },
            padding: const EdgeInsets.fromLTRB(18, 8, 24, 24),
            textStyle: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.9,
            ),
          ),
        ),
      ],
    ),
  );
}

