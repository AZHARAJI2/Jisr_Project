import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'models/models.dart';
import 'network/network.dart';
import 'data/data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDB.initialize();
  runApp(const CrisisBridgeApp());
}

class CrisisBridgeApp extends StatelessWidget {
  const CrisisBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جسر الأزمات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: WithForegroundTask(child: const HomeScreen()),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MeshManager _mesh = MeshManager.instance;
  double _balance = 0;
  String _userId = '';
  bool _isInitialized = false;
  String _statusText = 'جاري التهيئة...';
  int _connectedPeers = 0;

  List<TransactionPacket> _completedTxns = [];
  List<TransactionPacket> _pendingTxns = [];

  /// سجل الأحداث للعرض (debug)
  List<String> _debugLogs = [];

  StreamSubscription<TransactionPacket>? _incomingSub;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<int>? _peersSub;
  StreamSubscription<String>? _logSub;
  Timer? _refreshTimer;

  /// هل نعرض لوحة التتبع؟
  bool _showDebug = true;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await _requestPermissions();

    // معرّف فريد ومستمر لكل جهاز (يتخزن في Hive)
    final idBox = await Hive.openBox('device_id');
    _userId = idBox.get('userId') as String? ?? '';
    if (_userId.isEmpty) {
      // أنشئ معرّف جديد قصير وفريد
      final now = DateTime.now().millisecondsSinceEpoch;
      _userId = 'user_${now % 100000}'; // آخر 5 أرقام — فريد لكل جهاز
      await idBox.put('userId', _userId);
    }
    debugPrint('🆔 معرّف المستخدم: $_userId');

    await _mesh.initialize(_userId);
    await _mesh.start();

    try {
      await JisrForegroundService.start();
    } catch (e) {
      debugPrint('⚠️ Foreground service error: $e');
    }

    _incomingSub = _mesh.incomingTransfers.listen((txn) {
      if (!mounted) return;
      _refreshData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💰 وصلك ${txn.amount} من ${txn.senderId}'),
          backgroundColor: Colors.green,
        ),
      );
    });

    _statusSub = _mesh.statusStream.listen((status) {
      if (mounted) {
        setState(() => _statusText = status);
        debugPrint('🖥️ UI حالة: $status');
      }
    });

    _peersSub = _mesh.peersStream.listen((count) {
      if (mounted) {
        setState(() {
          _connectedPeers = count;
          debugPrint('🖥️ UI أجهزة: $count — ${_mesh.connectedDevices}');
        });
      }
    });

    // استمع لسجل الأحداث الحي
    _logSub = _mesh.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _debugLogs = _mesh.logs;
        });
      }
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _refreshData();
    });

    _refreshData();
    setState(() {
      _isInitialized = true;
      _debugLogs = _mesh.logs;
    });
  }

  void _refreshData() {
    if (!mounted) return;
    setState(() {
      _balance = _mesh.getBalance();
      _completedTxns = _mesh.completedTransactions;
      _pendingTxns = _mesh.pendingTransactions;
      _connectedPeers = _mesh.connectedCount;
      _debugLogs = _mesh.logs;
    });
  }

  Future<void> _requestPermissions() async {
    await Permission.location.request();
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();
    await Permission.nearbyWifiDevices.request();
    await Permission.notification.request();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: const Text('جِسر الأزمات'),
        centerTitle: true,
        actions: [
          // زر عرض/إخفاء التتبع
          IconButton(
            icon: Icon(_showDebug ? Icons.bug_report : Icons.bug_report_outlined),
            onPressed: () => setState(() => _showDebug = !_showDebug),
          ),
          // مؤشر الأجهزة
          Container(
            margin: const EdgeInsets.only(left: 8, right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _connectedPeers > 0 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.devices, size: 16),
                const SizedBox(width: 4),
                Text('$_connectedPeers'),
              ],
            ),
          ),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildStatusBanner(),
                const SizedBox(height: 12),
                _buildBalanceCard(),
                const SizedBox(height: 12),
                _buildActionButtons(),
                const SizedBox(height: 12),
                _buildMeshInfo(),
                if (_showDebug) ...[
                  const SizedBox(height: 12),
                  _buildDebugPanel(),
                ],
                const SizedBox(height: 12),
                _buildTransactionList(),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    final connected = _connectedPeers > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: connected ? Colors.green.shade50 : Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected ? Colors.green.shade200 : Colors.teal.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(connected ? Icons.link : Icons.wifi_tethering,
              color: connected ? Colors.green : Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_statusText,
                style: TextStyle(
                    color: connected ? Colors.green.shade800 : Colors.teal.shade800,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade800],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('رصيدك', style: TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 8),
            Text('${_balance.toStringAsFixed(0)} ريال',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            // معرّف قابل للنسخ
            GestureDetector(
              onLongPress: () {
                // نسخ المعرف
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('معرّفك: $_userId')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('اضغط طويلاً لنسخ المعرّف: $_userId',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showSendDialog,
            icon: const Icon(Icons.send),
            label: const Text('إرسال'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              // إعادة تشغيل الشبكة
              await _mesh.stop();
              await Future.delayed(const Duration(seconds: 1));
              await _mesh.start();
              _refreshData();
            },
            icon: const Icon(Icons.restart_alt),
            label: const Text('إعادة تشغيل'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMeshInfo() {
    final devices = _mesh.connectedDevices;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('الشبكة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                // مؤشر حالة بارز
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _connectedPeers > 0 ? Colors.green.shade100 : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _connectedPeers > 0 ? Colors.green : Colors.orange,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _connectedPeers > 0 ? Icons.wifi : Icons.wifi_find,
                        size: 14,
                        color: _connectedPeers > 0 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _connectedPeers > 0 ? 'متصل ($_connectedPeers)' : 'يبحث...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _connectedPeers > 0 ? Colors.green.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _row(Icons.devices, 'أجهزة متصلة', '$_connectedPeers'),
            _row(Icons.pending_actions, 'حوالات معلّقة', '${_pendingTxns.length}'),
            _row(Icons.check_circle_outline, 'حوالات مكتملة', '${_completedTxns.length}'),
            if (devices.isNotEmpty) ...[
              const Divider(),
              const Text('الأجهزة المتصلة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...devices.map((n) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.phone_android, size: 16, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(child: Text(n, style: const TextStyle(fontSize: 13))),
                    ]),
                  )),
            ] else ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('يبحث عن أجهزة قريبة...', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ── لوحة التتبع الحي ──
  Widget _buildDebugPanel() {
    return Card(
      color: Colors.grey.shade900,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📋 سجل الأحداث',
                    style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('تحديث', style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _debugLogs.isEmpty
                  ? const Text('لا أحداث بعد...', style: TextStyle(color: Colors.grey, fontSize: 12))
                  : ListView.builder(
                      reverse: true,
                      itemCount: _debugLogs.length,
                      itemBuilder: (_, i) {
                        final log = _debugLogs[_debugLogs.length - 1 - i];
                        Color color = Colors.white70;
                        if (log.contains('✅')) color = Colors.greenAccent;
                        if (log.contains('❌')) color = Colors.redAccent;
                        if (log.contains('⚠️')) color = Colors.orangeAccent;
                        if (log.contains('🔍')) color = Colors.cyanAccent;
                        if (log.contains('📤')) color = Colors.blueAccent;
                        if (log.contains('📥')) color = Colors.lightGreenAccent;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(log, style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace')),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    final allTxns = [..._completedTxns, ..._pendingTxns];
    allTxns.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الحوالات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (allTxns.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا حوالات بعد', style: TextStyle(color: Colors.grey))))
            else
              ...allTxns.take(10).map(_txnRow),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.teal),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _txnRow(TransactionPacket txn) {
    final isIn = txn.receiverId == _userId;
    final done = LocalDB.isCompleted(txn.id);
    final t = DateTime.fromMillisecondsSinceEpoch(txn.timestamp);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isIn ? Colors.green.shade100 : Colors.red.shade100,
        child: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIn ? Colors.green : Colors.red),
      ),
      title: Text('${txn.amount.toStringAsFixed(0)} ريال',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(isIn ? 'من: ${txn.senderId}' : 'إلى: ${txn.receiverId}',
          style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
      trailing: Text(done ? '✅' : '⏳',
          style: TextStyle(fontSize: 16, color: done ? Colors.green : Colors.orange)),
    );
  }

  void _showSendDialog() {
    final amtCtrl = TextEditingController();
    final recCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إرسال حوالة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: recCtrl,
              decoration: InputDecoration(
                labelText: 'معرّف المستلم',
                hintText: 'user_...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amtCtrl,
              decoration: InputDecoration(
                labelText: 'المبلغ',
                suffixText: 'ريال',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text);
              final to = recCtrl.text.trim();
              if (amt == null || amt <= 0 || to.isEmpty) return;

              final txn = await _mesh.createAndSendTransaction(receiverId: to, amount: amt);
              if (ctx.mounted) Navigator.pop(ctx);
              _refreshData();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(txn != null ? '✅ تم إرسال $amt ريال' : '❌ رصيد غير كافٍ'),
                  backgroundColor: txn != null ? Colors.green : Colors.red,
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _statusSub?.cancel();
    _peersSub?.cancel();
    _logSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}