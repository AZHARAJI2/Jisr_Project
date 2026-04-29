import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class JisrLogo extends StatelessWidget {
  final double size;
  const JisrLogo({Key? key, this.size = 80}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..shader = AppTheme.primaryGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = size.width * 0.08
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGlow = Paint()
      ..color = AppTheme.primaryEmerald.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeWidth = size.width * 0.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    // A stylized bridge arc
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.5, 
      size.height * 0.1, 
      size.width * 0.9, 
      size.height * 0.7
    );

    // Support lines
    path.moveTo(size.width * 0.3, size.height * 0.45);
    path.lineTo(size.width * 0.3, size.height * 0.7);
    
    path.moveTo(size.width * 0.5, size.height * 0.35);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    
    path.moveTo(size.width * 0.7, size.height * 0.45);
    path.lineTo(size.width * 0.7, size.height * 0.7);

    canvas.drawPath(path, paintGlow);
    canvas.drawPath(path, paintLine);
    
    // Bottom horizontal line
    final linePath = Path();
    linePath.moveTo(size.width * 0.05, size.height * 0.75);
    linePath.lineTo(size.width * 0.95, size.height * 0.75);
    canvas.drawPath(linePath, paintLine);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
