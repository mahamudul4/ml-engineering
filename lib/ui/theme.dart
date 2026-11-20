import 'package:flutter/material.dart';

const forest = Color(0xFF176B4B);
const lime = Color(0xFFD9EDAA);
const ink = Color(0xFF202B27);

ThemeData appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: forest,
    brightness: brightness,
    surface: dark ? const Color(0xFF18221D) : Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101914)
        : const Color(0xFFF7F8F4),
    fontFamily: 'Manrope',
    fontFamilyFallback: const ['NotoSansBengali', 'NotoSansMath', 'NotoSans'],
    textTheme: Typography.material2021(platform: TargetPlatform.android).black
        .apply(
          fontFamily: 'Manrope',
          fontFamilyFallback: const [
            'NotoSansBengali',
            'NotoSansMath',
            'NotoSans',
          ],
          bodyColor: dark ? const Color(0xFFE4EBE5) : ink,
          displayColor: dark ? const Color(0xFFE4EBE5) : ink,
        ),
    dividerColor: dark ? const Color(0xFF2C3B31) : const Color(0xFFE6EAE3),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: dark ? const Color(0xFF2C3B31) : const Color(0xFFE4E8DF),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? lime : forest,
        foregroundColor: dark ? ink : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 19),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF202D24) : const Color(0xFFF3F5EF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  final Color? color;
  const Eyebrow(this.text, {super.key, this.color});
  static final _bangla = RegExp(r'[\u0980-\u09ff]');
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 10,
      letterSpacing: _bangla.hasMatch(text) ? 0 : 1.8,
      fontWeight: FontWeight.w800,
      color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class Tag extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const Tag(this.text, {super.key, this.icon, this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

void showFailure(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Could not save. Please try again.')),
  );
}
