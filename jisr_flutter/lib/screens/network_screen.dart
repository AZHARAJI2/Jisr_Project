import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class NetworkScreen extends StatelessWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('خارطة الشبكة الحية', style: TextStyle(fontFamily: 'Tajawal')),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      const Text(
                        '🗺️ خارطة الشبكة الحية',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                      ),
                      const SizedBox(height: 30),
                      
                      // Node Graph Section
                      _buildNodeGraph(),
                      
                      const SizedBox(height: 30),
                      _buildStatusLegend(),
                      
                      const Divider(color: Colors.white10, height: 40),
                      
                      _buildNetworkStats(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNodeGraph() {
    return Container(
      height: 350,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Connections lines
          CustomPaint(size: Size.infinite, painter: GraphPainter()),
          
          // Nodes
          _buildNode(0, -130, 'علي (إنترنت✅)', Colors.blue, isActive: true),
          _buildNode(0, -40, 'محمد (87نقطة)', Colors.green, isActive: true),
          _buildNode(-80, 40, 'خالد', Colors.green, isActive: true),
          _buildNode(80, 40, 'فاطمة', Colors.yellow),
          _buildNode(0, 120, 'أنت', AppTheme.primaryBlue, isSelf: true),
          _buildNode(60, 180, 'أحمد (ضعيف)', Colors.red),
        ],
      ),
    );
  }

  Widget _buildNode(double x, double y, String name, Color color, {bool isActive = false, bool isSelf = false}) {
    return Transform.translate(
      offset: Offset(x, y),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: isActive ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)] : null,
            ),
            child: Icon(
              isSelf ? Icons.my_location : (isActive ? Icons.wifi : Icons.person),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isSelf ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('ممتاز', Colors.green),
        const SizedBox(width: 20),
        _buildLegendItem('جيد', Colors.yellow),
        const SizedBox(width: 20),
        _buildLegendItem('ضعيف', Colors.red),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildNetworkStats() {
    return Column(
      children: [
        _buildStatItem('✅ أفضل مسار:', 'خالد ← محمد', color: AppTheme.primaryEmerald),
        const SizedBox(height: 10),
        _buildStatItem('📏 تغطية الشبكة:', '280م'),
        const SizedBox(height: 10),
        _buildStatItem('👥 هواتف نشطة:', '8'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}

class GraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    
    // Ali to Mohammed
    canvas.drawLine(center + const Offset(0, -110), center + const Offset(0, -60), paint);
    
    // Mohammed to Khaled and Fatima
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(-60, 30), paint);
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(60, 30), paint);
    
    // Khaled and Fatima to You
    canvas.drawLine(center + const Offset(-60, 60), center + const Offset(0, 100), paint);
    canvas.drawLine(center + const Offset(60, 60), center + const Offset(0, 100), paint);
    
    // You to Ahmed
    canvas.drawLine(center + const Offset(0, 140), center + const Offset(50, 170), paint);
    
    // Highlight Best Path (Khaled to Mohammed)
    final bestPathPaint = Paint()
      ..color = AppTheme.primaryEmerald.withOpacity(0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(center + const Offset(-60, 60), center + const Offset(0, 100), bestPathPaint);
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(-60, 30), bestPathPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
