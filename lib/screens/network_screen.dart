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
  Map<String, List<String>> _topology = {};
  int _animationStep = 0;
  bool _isTraceAnimating = false;
  String? _animatedTxnId;
  List<String> _activeTransferPath = const [];
  StreamSubscription<int>? _peersSub;
  StreamSubscription<TransferTracePoint>? _traceSub;
  Timer? _animationTimer;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _peers = _mesh.connectedCount;
    _devices = _mesh.connectedDevices;
    _telemetry = _mesh.peerTelemetry;
    _trackedTxnId = _latestTxnId();
    _topology = _mesh.getKnownTopology();
    if (_trackedTxnId != null) {
      _tracePoints = _mesh.getTrace(_trackedTxnId!);
    }

    _peersSub = _mesh.peersStream.listen((c) {
      if (mounted) setState(() {
        _peers = c;
        _devices = _mesh.connectedDevices;
        _telemetry = _mesh.peerTelemetry;
        _topology = _mesh.getKnownTopology();
      });
    });
    _traceSub = _mesh.traceStream.listen((trace) {
      if (!mounted) return;
      setState(() {
        // تتبع أحدث حوالة وصلت كحدث trace مباشرة.
        _trackedTxnId = trace.txnId;
        if (_trackedTxnId != null) {
          _tracePoints = _mesh.getTrace(_trackedTxnId!);
          if (_animatedTxnId != _trackedTxnId) {
            // شغّل الأنيميشن مرة واحدة لكل حوالة جديدة.
            _animatedTxnId = _trackedTxnId;
            _animationStep = 0;
            _isTraceAnimating = _tracePoints.length > 1;
          }
        }
        if (trace.state == 'delivered') {
          _activeTransferPath = const [];
          _isTraceAnimating = false;
        } else {
          _activeTransferPath = List<String>.from(trace.path);
          _isTraceAnimating = _activeTransferPath.length > 1;
          if (_isTraceAnimating && _animationStep == 0) {
            _animationStep = 1;
          }
        }
        _topology = _mesh.getKnownTopology();
      });
    });
    _animationTimer = Timer.periodic(const Duration(milliseconds: 700), (_) {
      if (!mounted) return;
      if (!_isTraceAnimating) return;
      final maxStep = _maxAnimationStep();
      setState(() {
        if (_animationStep < maxStep) {
          _animationStep++;
        } else {
          // انتهى التتبع: ثبّت آخر نقطة بدون إعادة.
          _isTraceAnimating = false;
        }
      });
    });
    // تحديث دوري خفيف لبيانات الجودة حتى لا يعلق اللون بعد إعادة الاتصال.
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        _telemetry = _mesh.peerTelemetry;
        _devices = _mesh.connectedDevices;
        _topology = _mesh.getKnownTopology();
      });
    });
  }

  @override
  void dispose() {
    _peersSub?.cancel();
    _traceSub?.cancel();
    _animationTimer?.cancel();
    _refreshTimer?.cancel();
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
              me: _mesh.userId,
              topology: _cleanTopologyForView(),
              tracePath: _latestTracePath(),
              activePath: _activeTransferPath,
              nodeQuality: _buildNodeQualityMap(),
              animationStep: _animationStep,
            ),
          ),
          if (_devices.isEmpty && _topology.isEmpty)
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
        _buildLegendItem('جيد/قريب', Colors.green),
        const SizedBox(width: 14),
        _buildLegendItem('متوسط', Colors.orange),
        const SizedBox(width: 14),
        _buildLegendItem('ضعيف/بعيد', Colors.red),
        const SizedBox(width: 14),
        _buildLegendItem('معه الحوالة', const Color(0xFF9C27B0)),
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

  int _maxAnimationStep() {
    final path = _latestTracePath();
    if (path.length <= 1) return 0;
    return (path.length - 1) * 10;
  }

  List<String> _latestTracePath() {
    if (_tracePoints.isEmpty) return const [];
    return _tracePoints.last.path;
  }

  String _traceSummary() {
    if (_tracePoints.isEmpty) return 'لا يوجد تتبع بعد';
    final latest = _tracePoints.last;
    return '${latest.state} عند ${latest.nodeId}';
  }

  Map<String, List<String>> _cleanTopologyForView() {
    // Keep map stable and readable: only show me + currently connected peers.
    final peers = _devices
        .map((d) => d.replaceFirst('JISR_', ''))
        .where((d) => d.isNotEmpty)
        .toList();
    return <String, List<String>>{
      _mesh.userId: peers,
    };
  }

  Map<String, Color> _buildNodeQualityMap() {
    final map = <String, Color>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in _telemetry) {
      final id = p.displayName.replaceFirst('JISR_', '');
      final ageSec = ((now - p.lastSeenMs).clamp(0, 120000)) / 1000.0;
      final helloAgeSec = p.lastHelloMs <= 0
          ? 9999.0
          : ((now - p.lastHelloMs).clamp(0, 120000)) / 1000.0;
      final success = p.successRate;
      // اتصال قريب/جديد يجب أن يظهر أخضر حتى قبل وجود تاريخ تحويلات كبير.
      if (ageSec <= 15 && helloAgeSec <= 25 && success >= 0.45) {
        map[id] = Colors.green; // قريب/جودة ممتازة
      } else if (ageSec <= 45 && helloAgeSec <= 75 && success >= 0.30) {
        map[id] = Colors.orange; // متوسط
      } else {
        map[id] = Colors.red; // بعيد أو جودة ضعيفة
      }
    }
    return map;
  }
}

class GraphPainter extends CustomPainter {
  final String me;
  final Map<String, List<String>> topology;
  final List<String> tracePath;
  final List<String> activePath;
  final Map<String, Color> nodeQuality;
  final int animationStep;

  GraphPainter({
    required this.me,
    required this.topology,
    required this.tracePath,
    required this.activePath,
    required this.nodeQuality,
    required this.animationStep,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = <String>{me};
    for (final e in topology.entries) {
      nodes.add(e.key);
      nodes.addAll(e.value);
    }
    if (nodes.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide * 0.34).clamp(80.0, 130.0);
    final ordered = nodes.toList()..sort();
    if (ordered.remove(me)) {
      ordered.insert(0, me);
    }
    final pos = <String, Offset>{};
    pos[ordered.first] = center;
    final ring = ordered.skip(1).toList();
    for (var i = 0; i < ring.length; i++) {
      final a = (2 * 3.141592653589793 * i) / ring.length;
      pos[ring[i]] = Offset(
        center.dx + radius * _c(a),
        center.dy + radius * _s(a),
      );
    }

    final baseEdge = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1.4;
    final seen = <String>{};
    for (final e in topology.entries) {
      for (final n in e.value) {
        final key = e.key.compareTo(n) < 0 ? '${e.key}|$n' : '$n|${e.key}';
        if (!seen.add(key)) continue;
        final p1 = pos[e.key];
        final p2 = pos[n];
        if (p1 == null || p2 == null) continue;
        canvas.drawLine(p1, p2, baseEdge);
      }
    }

    // Draw nodes and labels clearly.
    for (final id in ordered) {
      final p = pos[id];
      if (p == null) continue;
      final isMe = id == me;
      final isActiveTransferNode = activePath.contains(id);
      final color = isMe
          ? AppTheme.primaryBlue
          : (isActiveTransferNode
              ? const Color(0xFF9C27B0)
              : (nodeQuality[id] ?? Colors.orange));

      canvas.drawCircle(
        p,
        9,
        Paint()
          ..color = color.withOpacity(0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(p, 5, Paint()..color = color);

      final label = _prettyNodeName(id, isMe);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isMe ? AppTheme.primaryBlue : Colors.white,
            fontSize: 10,
            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.rtl,
      )..layout(maxWidth: 120);
      textPainter.paint(canvas, Offset(p.dx - (textPainter.width / 2), p.dy + 10));
    }

    if (activePath.length > 1) {
      final tracePaint = Paint()
        ..color = const Color(0xFF9C27B0).withOpacity(0.85)
        ..strokeWidth = 3.0;
      for (var i = 0; i < activePath.length - 1; i++) {
        final p1 = pos[activePath[i]];
        final p2 = pos[activePath[i + 1]];
        if (p1 == null || p2 == null) continue;
        canvas.drawLine(p1, p2, tracePaint);
      }
      final segments = activePath.length - 1;
      final maxStep = segments * 10;
      final clampedStep = animationStep.clamp(0, maxStep);
      int hop = clampedStep ~/ 10;
      double t = (clampedStep % 10) / 10.0;
      if (clampedStep >= maxStep) {
        hop = segments - 1;
        t = 1.0;
      }
      final p1 = pos[activePath[hop]];
      final p2 = pos[activePath[hop + 1]];
      if (p1 != null && p2 != null) {
        final dot = Offset(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t,
        );
        canvas.drawCircle(dot, 6, Paint()..color = Colors.amber);
      }
    }
  }

  String _prettyNodeName(String id, bool isMe) {
    if (isMe) return 'أنت';
    final clean = id.replaceFirst('JISR_', '');
    if (clean.length <= 12) return clean;
    return '${clean.substring(0, 10)}…';
  }

  double _s(double x) {
    final x2 = x * x;
    return x * (1 - x2 / 6 + (x2 * x2) / 120);
  }

  double _c(double x) => _s(x + 1.5707963267948966);

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) =>
      oldDelegate.me != me ||
      oldDelegate.topology != topology ||
      oldDelegate.tracePath != tracePath ||
      oldDelegate.activePath != activePath ||
      oldDelegate.nodeQuality != nodeQuality ||
      oldDelegate.animationStep != animationStep;
}
