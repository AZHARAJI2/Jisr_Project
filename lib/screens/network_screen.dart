import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../network/network.dart';
import '../ai/ai_routing_layer.dart';
import 'dart:async';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({Key? key}) : super(key: key);

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final MeshManager _mesh = MeshManager.instance;
  final AIRoutingLayer _ai = AIRoutingLayer();

  int _peers = 0;
  List<String> _devices = [];
  List<String> _logs = [];

  NetworkNode? _bestRelay;

  StreamSubscription<int>? _peersSub;
  StreamSubscription<String>? _logSub;

  @override
  void initState() {
    super.initState();

    _refreshData();

    _peersSub = _mesh.peersStream.listen((_) {
      if (mounted) {
        setState(_refreshData);
      }
    });

    _logSub = _mesh.logStream.listen((_) {
      if (mounted) {
        setState(() {
          _logs = List.from(_mesh.logs);
        });
      }
    });
  }

  void _refreshData() {
    _peers = _mesh.connectedCount;
    _devices = List.from(_mesh.connectedDevices);
    _logs = List.from(_mesh.logs);
    _bestRelay = _ai.getBestRelay();
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
        title: const Text('خريطة الشبكة الذكية'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
                      const Text(
                        'خريطة الشبكة المدعومة بالذكاء الاصطناعي',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryEmerald,
                        ),
                      ),
                      const SizedBox(height: 25),

                      if (_bestRelay != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'أفضل وسيط: ${_bestRelay!.name}',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],

                      _buildNodeGraph(),

                      const SizedBox(height: 25),

                      _buildStatusLegend(),

                      const Divider(
                        color: Colors.white10,
                        height: 40,
                      ),

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
    return SizedBox(
      height: 380,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: IntelligentGraphPainter(
              deviceCount: _devices.length,
            ),
          ),

          _buildNode(
            0,
            0,
            'أنت',
            AppTheme.primaryEmerald,
            isSelf: true,
          ),

          ..._devices.asMap().entries.map((entry) {
            final index = entry.key;
            final device = entry.value.replaceAll('JISR_', '');

            final positions = [
              const Offset(-140, -100),
              const Offset(140, -100),
              const Offset(-150, 90),
              const Offset(150, 90),
              const Offset(0, -170),
              const Offset(0, 170),
            ];

            final pos = positions[index % positions.length];
            final isBest = _bestRelay?.name == device;

            return _buildNode(
              pos.dx,
              pos.dy,
              device,
              isBest ? Colors.amber : Colors.green,
              isActive: true,
              isBestRelay: isBest,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNode(
    double x,
    double y,
    String name,
    Color color, {
    bool isActive = false,
    bool isSelf = false,
    bool isBestRelay = false,
  }) {
    return Transform.translate(
      offset: Offset(x, y),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.45),
                  blurRadius: isBestRelay ? 25 : 12,
                  spreadRadius: isBestRelay ? 4 : 1,
                ),
              ],
            ),
            child: Icon(
              isSelf
                  ? Icons.my_location
                  : isBestRelay
                      ? Icons.star
                      : Icons.phone_android,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight:
                  isSelf || isBestRelay ? FontWeight.bold : FontWeight.normal,
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
        _legend('أنت', AppTheme.primaryEmerald),
        const SizedBox(width: 20),
        _legend('جهاز متصل', Colors.green),
        const SizedBox(width: 20),
        _legend('أفضل وسيط', Colors.amber),
      ],
    );
  }

  Widget _legend(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkStats() {
    return Column(
      children: [
        _stat('الأجهزة المتصلة', '$_peers',
            color: AppTheme.primaryEmerald),
        const SizedBox(height: 12),
        _stat(
          'الحوالات المعلقة',
          '${_mesh.pendingTransactions.length}',
        ),
        const SizedBox(height: 12),
        _stat(
          'الحوالات المكتملة',
          '${_mesh.completedTransactions.length}',
        ),
      ],
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class IntelligentGraphPainter extends CustomPainter {
  final int deviceCount;

  IntelligentGraphPainter({
    required this.deviceCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (deviceCount == 0) return;

    final center = Offset(size.width / 2, size.height / 2);

    final linePaint = Paint()
      ..color = AppTheme.primaryEmerald.withOpacity(0.25)
      ..strokeWidth = 2;

    final aiPaint = Paint()
      ..color = Colors.amber.withOpacity(0.75)
      ..strokeWidth = 3.5;

    final positions = [
      const Offset(-140, -100),
      const Offset(140, -100),
      const Offset(-150, 90),
      const Offset(150, 90),
      const Offset(0, -170),
      const Offset(0, 170),
    ];

    for (int i = 0; i < deviceCount; i++) {
      final point = center + positions[i % positions.length];
      canvas.drawLine(center, point, linePaint);

      if (i == 0) {
        canvas.drawLine(center, point, aiPaint);
      }
    }
  }
  @override
  bool shouldRepaint(covariant IntelligentGraphPainter oldDelegate) {
    return oldDelegate.deviceCount != deviceCount;
  }
}