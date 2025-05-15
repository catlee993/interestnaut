import 'package:flutter/material.dart';

class MediaItemWrapper extends StatelessWidget {
  final Widget child;
  final String view; // 'default', 'watchlist', 'saved'
  final VoidCallback? onRemoveFromWatchlist;

  const MediaItemWrapper({
    Key? key,
    required this.child,
    required this.view,
    this.onRemoveFromWatchlist,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final showRemove = (view == 'watchlist' || view == 'saved') && onRemoveFromWatchlist != null;
    return Stack(
      children: [
        if (showRemove)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () {
                onRemoveFromWatchlist?.call();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: _RemoveXIconPainter(),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _RemoveXIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final purplePaint = Paint()
      ..color = const Color(0xFF6a1b9a)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final whitePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Purple outline X
    canvas.drawLine(const Offset(6.4, 6.4), const Offset(17.6, 17.6), purplePaint);
    canvas.drawLine(const Offset(6.4, 17.6), const Offset(17.6, 6.4), purplePaint);
    // White inner X
    canvas.drawLine(const Offset(6.4, 6.4), const Offset(17.6, 17.6), whitePaint);
    canvas.drawLine(const Offset(6.4, 17.6), const Offset(17.6, 6.4), whitePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 