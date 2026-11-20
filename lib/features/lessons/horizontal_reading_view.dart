import 'package:flutter/material.dart';

/// Makes a wide equation/code block discoverable without shrinking its text.
class HorizontalReadingView extends StatefulWidget {
  final Widget child;
  final String hint;
  final Color? hintColor;
  const HorizontalReadingView({
    super.key,
    required this.child,
    required this.hint,
    this.hintColor,
  });

  @override
  State<HorizontalReadingView> createState() => _HorizontalReadingViewState();
}

class _HorizontalReadingViewState extends State<HorizontalReadingView> {
  final scroll = ScrollController();
  bool overflows = false;
  bool measurementScheduled = false;

  void measureAfterLayout() {
    if (measurementScheduled) return;
    measurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      measurementScheduled = false;
      if (!mounted || !scroll.hasClients) return;
      final next = scroll.position.maxScrollExtent > .5;
      if (next != overflows) setState(() => overflows = next);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    measureAfterLayout();
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        measureAfterLayout();
        return false;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Scrollbar(
            controller: scroll,
            thumbVisibility: overflows,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            // Keep the track outside the reading viewport, including fractions
            // whose denominator extends below the equation's baseline.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  controller: scroll,
                  scrollDirection: Axis.horizontal,
                  child: widget.child,
                ),
                if (overflows) const SizedBox(height: 24),
              ],
            ),
          ),
          if (overflows) ...[
            const SizedBox(height: 8),
            Text(
              widget.hint,
              style: TextStyle(
                fontSize: 11,
                height: 1.8,
                color:
                    widget.hintColor ??
                    Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
