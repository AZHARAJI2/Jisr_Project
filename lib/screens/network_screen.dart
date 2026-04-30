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
  List<PeerTelemetry> _telemetry = [];
  String? _trackedTxnId;
  List<TransferTracePoint> _tracePoints = [];
  int _animationStep = 0;
  StreamSubscription<int>? _peersSub;
  StreamSubscription<TransferTracePoint>? _traceSub;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _peers = _mesh.connectedCount;
    _devices = _mesh.connectedDevices;
    _telemetry = _mesh.peerTelemetry;
    _trackedTxnId = _latestTxnId();
    if (_trackedTxnId != null) {
      _tracePoints = _mesh.getTrace(_trackedTxnId!);
    }

    _peersSub = _mesh.peersStream.listen((c) {
      if (mounted) setState(() {
        _peers = c;
        _devices = _mesh.connectedDevices;
        _telemetry = _mesh.peerTelemetry;
      });
    });
    _traceSub = _mesh.traceStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _trackedTxnId ??= _latestTxnId();
        if (_trackedTxnId != null) {
          _tracePoints = _mesh.getTrace(_trackedTxnId!);
        }
      });
    });
    _animationTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      setState(() => _animationStep++);
    });
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _traceSub?.cancel();
    _animationTimer?.cancel();
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
                      
                      const Divider(color: Colors.white10, height: 30),
                      _buildBestRouteOnlyCard(),
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
          CustomPaint(
            size: Size.infinite,
            painter: GraphPainter(
              peerCount: _devices.length,
              traceHopCount: _traceHopCount(),
              animationStep: _animationStep,
            ),
          ),
          _buildNode(0, -130, 'أنت', AppTheme.primaryEmerald, isSelf: true),
          ..._devices.asMap().entries.map((e) {
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

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: TextStyle(color: color ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildBestRouteOnlyCard() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final best = _telemetry.isEmpty ? null : _telemetry.first.displayName;
    final bestRoute = _telemetry.take(3).map((e) => e.displayName).join(' ← ');
    final traceText = _traceSummary();
    return Column(
      children: [
        _buildStatItem('الأجهزة المتصلة:', '$_peers', color: AppTheme.primaryEmerald),
        const SizedBox(height: 10),
        _buildStatItem('أقرب/أفضل هاتف:', best ?? 'غير متاح', color: Colors.amber),
        const SizedBox(height: 10),
        _buildStatItem(
          'أفضل مسار:',
          bestRoute.isEmpty ? 'غير متاح' : bestRoute,
          color: Colors.amber,
        ),
        const SizedBox(height: 10),
        _buildStatItem(
          'درجة المسار:',
          _telemetry.isEmpty ? '-' : _telemetry.first.score(now).toStringAsFixed(1),
          color: Colors.amber,
        ),
        const SizedBox(height: 10),
        _buildStatItem('تتبع آخر حوالة:', traceText, color: AppTheme.primaryBlue),
      ],
    );
  }

  String? _latestTxnId() {
    final txns = [..._mesh.pendingTransactions, ..._mesh.completedTransactions];
    if (txns.isEmpty) return null;
    txns.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txns.first.id;
  }

  int _traceHopCount() {
    if (_tracePoints.isEmpty) return 0;
    final maxHops = _tracePoints
        .map((p) => p.path.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return maxHops.clamp(1, 6);
  }

  String _traceSummary() {
    if (_tracePoints.isEmpty) return 'لا يوجد تتبع بعد';
    final latest = _tracePoints.last;
    return '${latest.state} عند ${latest.nodeId}';
  }
}

class GraphPainter extends CustomPainter {
  final int peerCount;
  final int traceHopCount;
  final int animationStep;

  GraphPainter({
    required this.peerCount,
    required this.traceHopCount,
    required this.animationStep,
  });

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

    final route = <Offset>[
      center + const Offset(0, -20),
      center + const Offset(-60, 30),
      center + const Offset(0, 100),
      center + const Offset(60, 60),
      center + const Offset(0, -60),
      center + const Offset(-60, 30),
    ];
    final hopsToDraw = traceHopCount <= 1 ? 2 : traceHopCount;
    for (var i = 0; i < hopsToDraw - 1 && i < route.length - 1; i++) {
      canvas.drawLine(route[i], route[i + 1], bestPath);
    }

    if (traceHopCount > 1) {
      final hopIndex = animationStep % (hopsToDraw - 1);
      final start = route[hopIndex];
      final end = route[hopIndex + 1];
      final t = ((animationStep % 10) / 10.0);
      final dot = Offset(
        start.dx + (end.dx - start.dx) * t,
        start.dy + (end.dy - start.dy) * t,
      );
      canvas.drawCircle(
        dot,
        6,
        Paint()
          ..color = Colors.amber
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(dot, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.peerCount != peerCount ||
      oldDelegate.traceHopCount != traceHopCount ||
      oldDelegate.animationStep != animationStep;
}
