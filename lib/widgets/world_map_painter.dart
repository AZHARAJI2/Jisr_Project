import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorldMapPainter extends CustomPainter {
  final List<String> peers;
  final String? bestPeer;

  WorldMapPainter({
    required this.peers,
    required this.bestPeer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawContinent(canvas, size, 0.2, 0.3, 0.15, 0.1); // NA
    _drawContinent(canvas, size, 0.25, 0.6, 0.1, 0.15); // SA
    _drawContinent(canvas, size, 0.5, 0.25, 0.1, 0.08); // EU
    _drawContinent(canvas, size, 0.52, 0.5, 0.12, 0.15); // AF
    _drawContinent(canvas, size, 0.75, 0.3, 0.18, 0.15); // AS
    _drawContinent(canvas, size, 0.8, 0.7, 0.08, 0.08); // AU

    final center = Offset(size.width * 0.5, size.height * 0.55);
    final pointTemplates = <Offset>[
      Offset(size.width * 0.22, size.height * 0.34),
      Offset(size.width * 0.78, size.height * 0.32),
      Offset(size.width * 0.30, size.height * 0.62),
      Offset(size.width * 0.72, size.height * 0.64),
      Offset(size.width * 0.52, size.height * 0.25),
      Offset(size.width * 0.52, size.height * 0.78),
    ];

    final shownPeers = peers.take(6).toList();
    for (var i = 0; i < shownPeers.length; i++) {
      final name = shownPeers[i].replaceAll('JISR_', '');
      final point = pointTemplates[i];
      final isBest = bestPeer != null && bestPeer == shownPeers[i];
      _drawConnection(
        canvas,
        center,
        point,
        isBest ? Colors.amber : AppTheme.primaryEmerald,
      );
      _drawNode(
        canvas,
        name: name,
        pos: point,
        color: isBest ? Colors.amber : AppTheme.primaryEmerald,
      );
    }
    _drawNode(canvas, name: 'أنت', pos: center, color: AppTheme.primaryBlue);
  }

  void _drawContinent(Canvas canvas, Size size, double x, double y, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * x, size.height * y), width: size.width * w, height: size.height * h),
      Paint()..color = Colors.white.withOpacity(0.03),
    );
  }

  void _drawConnection(Canvas canvas, Offset p1, Offset p2, Color color) {
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final path = Path();
    path.moveTo(p1.dx, p1.dy);
    // Draw arc
    final midX = (p1.dx + p2.dx) / 2;
    final midY = (p1.dy + p2.dy) / 2 - 20;
    path.quadraticBezierTo(midX, midY, p2.dx, p2.dy);
    
    canvas.drawPath(path, paint);
    
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.1)..strokeWidth = 3.0..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _drawNode(Canvas canvas, {required String name, required Offset pos, required Color color}) {
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..color = color.withOpacity(0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      pos,
      5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(pos, 2, Paint()..color = color);
    final span = TextSpan(
      style: const TextStyle(color: Colors.white70, fontSize: 8),
      text: name,
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.rtl);
    tp.layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 10));
  }

  @override
  bool shouldRepaint(covariant WorldMapPainter oldDelegate) =>
      oldDelegate.peers != peers || oldDelegate.bestPeer != bestPeer;
}
