import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorldMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintBase = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final paintLine = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintGlow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Draw simplified continents (rectangles/ovals for concept)
    _drawContinent(canvas, size, 0.2, 0.3, 0.15, 0.1); // NA
    _drawContinent(canvas, size, 0.25, 0.6, 0.1, 0.15); // SA
    _drawContinent(canvas, size, 0.5, 0.25, 0.1, 0.08); // EU
    _drawContinent(canvas, size, 0.52, 0.5, 0.12, 0.15); // AF
    _drawContinent(canvas, size, 0.75, 0.3, 0.18, 0.15); // AS
    _drawContinent(canvas, size, 0.8, 0.7, 0.08, 0.08); // AU

    // Define City Nodes
    final nodes = {
      'London': Offset(size.width * 0.5, size.height * 0.25),
      'Tokyo': Offset(size.width * 0.85, size.height * 0.3),
      'NY': Offset(size.width * 0.25, size.height * 0.35),
      'Lagos': Offset(size.width * 0.52, size.height * 0.55),
      'Seoul': Offset(size.width * 0.8, size.height * 0.35),
    };

    // Draw connections with gradients and glows
    _drawConnection(canvas, nodes['London']!, nodes['NY']!, AppTheme.primaryBlue);
    _drawConnection(canvas, nodes['London']!, nodes['Tokyo']!, AppTheme.primaryEmerald);
    _drawConnection(canvas, nodes['NY']!, nodes['Lagos']!, AppTheme.accentPurple);
    _drawConnection(canvas, nodes['Lagos']!, nodes['Seoul']!, AppTheme.primaryEmerald);
    _drawConnection(canvas, nodes['Tokyo']!, nodes['Seoul']!, AppTheme.primaryBlue);

    // Draw Nodes
    nodes.forEach((name, pos) {
      final color = (name == 'London' || name == 'Seoul') ? AppTheme.primaryBlue : AppTheme.primaryEmerald;
      
      // Outer Glow
      canvas.drawCircle(pos, 8, Paint()..color = color.withOpacity(0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      // Ring
      canvas.drawCircle(pos, 5, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5);
      // Inner Dot
      canvas.drawCircle(pos, 2, Paint()..color = color);

      // Label
      final span = TextSpan(style: TextStyle(color: Colors.white70, fontSize: 8, fontFamily: 'Tajawal'), text: name);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + 10));
    });
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
    
    // Pulse animation logic would go here if we used AnimationController, 
    // for now we draw static but glowing.
    canvas.drawPath(path, Paint()..color = color.withOpacity(0.1)..strokeWidth = 3.0..style = PaintingStyle.stroke..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
