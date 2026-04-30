import '../network/mesh_manager.dart';

class NetworkNode {
  final String id;
  final String name;
  final int battery;
  final int signal;
  final int activeTransfers;
  final bool hasInternet;
  final double distance;

  const NetworkNode({
    required this.id,
    required this.name,
    required this.battery,
    required this.signal,
    required this.activeTransfers,
    required this.hasInternet,
    required this.distance,
  });
}

class AIRoutingLayer {
  final MeshManager mesh = MeshManager.instance;

  /// إنشاء عقد افتراضية من الأجهزة الحقيقية
  List<NetworkNode> generateNodes() {
    final devices = mesh.connectedDevices;

    return List.generate(devices.length, (index) {
      final name = devices[index];

      return NetworkNode(
        id: 'node_$index',
        name: name.replaceAll('JISR_', ''),
        battery: 70 + (index * 7) % 30,
        signal: 65 + (index * 9) % 35,
        activeTransfers: index % 3,
        hasInternet: index == 0,
        distance: 15.0 + (index * 18),
      );
    });
  }

  /// حساب تقييم الجهاز
  double score(NetworkNode node) {
    double result = 0;

    result += node.battery * 0.35;
    result += node.signal * 0.30;
    result -= node.activeTransfers * 12;
    result += node.hasInternet ? 40 : 0;
    result += (100 - node.distance) * 0.15;

    return result;
  }

  /// أفضل جهاز وسيط
  NetworkNode? getBestRelay() {
    final nodes = generateNodes();
    if (nodes.isEmpty) return null;

    nodes.sort((a, b) => score(b).compareTo(score(a)));
    return nodes.first;
  }

  /// أفضل مسار
  List<NetworkNode> getOptimalRoute() {
    final best = getBestRelay();
    if (best == null) return [];
    return [best];
  }
}