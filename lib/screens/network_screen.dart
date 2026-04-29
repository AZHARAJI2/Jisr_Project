import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../network/network.dart';
import 'dart:async';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final MeshManager _mesh = MeshManager.instance;
  int _peers = 0;
  List<String> _devices = [];
  List<String> _logs = [];
  StreamSubscription<int>? _peersSub;
  StreamSubscription<String>? _logSub;

  @override
  void initState() {
    super.initState();
    _peers = _mesh.connectedCount;
    _devices = _mesh.connectedDevices;
    _logs = _mesh.logs;

    _peersSub = _mesh.peersStream.listen((c) {
      if (mounted) setState(() {
        _peers = c;
        _devices = _mesh.connectedDevices;
      });
    });
    _logSub = _mesh.logStream.listen((_) {
      if (mounted) setState(() => _logs = _mesh.logs);
    });
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('خريطة الشبكة'),
        centerTitle: true,
        actions: [
          // زر إعادة تشغيل الشبكة
          IconButton(
            icon: const Icon(Icons.restart_alt),
            onPressed: () async {
              await _mesh.stop();
              await Future.delayed(const Duration(seconds: 1));
              await _mesh.start();
            },
          ),
        ],
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
                      Text(
                        'خريطة الشبكة الحية',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                      ),
                      const SizedBox(height: 30),
                      
                      _buildNodeGraph(),
                      
                      const SizedBox(height: 30),
                      _buildStatusLegend(),
                      
                      const Divider(color: Colors.white10, height: 40),
                      
                      _buildNetworkStats(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // الأجهزة المتصلة
              if (_devices.isNotEmpty)
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الأجهزة المتصلة:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                        const SizedBox(height: 10),
                        ..._devices.map((d) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            const Icon(Icons.phone_android, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d, style: const TextStyle(fontSize: 13))),
                          ]),
                        )),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // سجل الأحداث
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📋 سجل الأحداث', style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        height: 200,
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _logs.isEmpty
                            ? const Text('لا أحداث بعد...', style: TextStyle(color: Colors.grey, fontSize: 12))
                            : ListView.builder(
                                reverse: true,
                                itemCount: _logs.length,
                                itemBuilder: (_, i) {
                                  final log = _logs[_logs.length - 1 - i];
                                  Color color = Colors.white70;
                                  if (log.contains('✅')) color = Colors.greenAccent;
                                  if (log.contains('❌')) color = Colors.redAccent;
                                  if (log.contains('🔍')) color = Colors.cyanAccent;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 1),
                                    child: Text(log, style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
                                  );
                                },
                              ),
                      ),
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
    return SizedBox(
      height: 350,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(size: Size.infinite, painter: GraphPainter()),
          _buildNode(0, -130, 'أنت', AppTheme.primaryEmerald, isSelf: true),
          ..._devices.asMap().entries.map((e) {
            final angle = (e.key * 2.0 * 3.14159) / _devices.length;
            final x = 80.0 * (e.key % 2 == 0 ? -1 : 1);
            final y = -40.0 + (e.key * 50.0);
            return _buildNode(x, y, e.value.replaceAll('JISR_', ''), Colors.green, isActive: true);
          }),
          if (_devices.isEmpty)
            _buildNode(0, 0, 'يبحث عن أجهزة...', Colors.orange),
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
              boxShadow: isActive || isSelf ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10)] : null,
            ),
            child: Icon(
              isSelf ? Icons.my_location : (isActive ? Icons.phone_android : Icons.wifi_find),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(fontSize: 10, color: color, fontWeight: isSelf ? FontWeight.bold : FontWeight.normal),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('متصل', Colors.green),
        const SizedBox(width: 20),
        _buildLegendItem('أنت', AppTheme.primaryEmerald),
        const SizedBox(width: 20),
        _buildLegendItem('يبحث', Colors.orange),
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
        _buildStatItem('أجهزة متصلة:', '$_peers', color: AppTheme.primaryEmerald),
        const SizedBox(height: 10),
        _buildStatItem('حوالات معلّقة:', '${_mesh.pendingTransactions.length}'),
        const SizedBox(height: 10),
        _buildStatItem('حوالات مكتملة:', '${_mesh.completedTransactions.length}'),
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
    
    // خطوط الشبكة
    canvas.drawLine(center + const Offset(0, -110), center + const Offset(0, -60), paint);
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(-60, 30), paint);
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(60, 30), paint);
    canvas.drawLine(center + const Offset(-60, 60), center + const Offset(0, 100), paint);
    canvas.drawLine(center + const Offset(60, 60), center + const Offset(0, 100), paint);

    final bestPath = Paint()
      ..color = AppTheme.primaryEmerald.withOpacity(0.5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
      
    canvas.drawLine(center + const Offset(-60, 60), center + const Offset(0, 100), bestPath);
    canvas.drawLine(center + const Offset(0, -20), center + const Offset(-60, 30), bestPath);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
