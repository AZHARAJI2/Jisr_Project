import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/transaction_packet.dart';
import '../data/local_db.dart';

/// ════════════════════════════════════════════════
/// NearbyMeshService — 100% مباشر بدون مكتبة
///
/// يستخدم MethodChannel مباشرة لكل العمليات
/// ════════════════════════════════════════════════
class NearbyMeshService {
  static const String _serviceId = 'com.crisisbridge.crisis_bridge';
  static const MethodChannel _ch = MethodChannel('nearby_connections');
  static const MethodChannel _events = MethodChannel('jisr_events');

  String _userName = 'JISR';

  final Map<String, String> _connectedEndpoints = {};
  final Map<String, String> _discoveredEndpoints = {};
  final Set<String> _pendingRequests = {};

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  int get connectedCount => _connectedEndpoints.length;
  List<String> get connectedDevices => _connectedEndpoints.values.toList();

  void Function(TransactionPacket txn)? onPacketReceived;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusCtrl.stream;
  final _peersCtrl = StreamController<int>.broadcast();
  Stream<int> get peersStream => _peersCtrl.stream;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  final _logCtrl = StreamController<String>.broadcast();
  Stream<String> get logStream => _logCtrl.stream;

  // ──────────────────────────────────────────
  //  Handler — يُسجّل مرة واحدة ويبقى
  // ──────────────────────────────────────────

  void _setupHandler() {
    _events.setMethodCallHandler((MethodCall call) async {
      final args = call.arguments as Map<dynamic, dynamic>;
      _log('📨 JISR: ${call.method}');

        switch (call.method) {
          case 'dis.onEndpointFound':
            final id = args['endpointId'] as String? ?? '';
            final name = args['endpointName'] as String? ?? '';
            final svc = args['serviceId'] as String? ?? '';
            _log('🔍✅ وُجد: $name ($id)');
            _handleEndpointFound(id, name);
            break;

          case 'dis.onEndpointLost':
            final id = args['endpointId'] as String? ?? '';
            _log('📡 فُقد: $id');
            _discoveredEndpoints.remove(id);
            _pendingRequests.remove(id);
            break;

          case 'dis.onConnectionInitiated':
            final id = args['endpointId'] as String? ?? '';
            final name = args['endpointName'] as String? ?? '';
            _log('🤝 [DIS] اتصال: $name ($id)');
            _acceptConnection(id, name, 'DIS');
            break;

          case 'dis.onConnectionResult':
            final id = args['endpointId'] as String? ?? '';
            final code = args['statusCode'] as int? ?? 2;
            _log('📊 [DIS] نتيجة: $id → $code');
            _handleConnectionResult(id, code);
            break;

          case 'dis.onDisconnected':
            final id = args['endpointId'] as String? ?? '';
            _log('🔌 [DIS] انقطع: $id');
            _handleDisconnection(id);
            break;

          case 'ad.onConnectionInitiated':
            final id = args['endpointId'] as String? ?? '';
            final name = args['endpointName'] as String? ?? '';
            _log('🤝 [AD] وارد: $name ($id)');
            _acceptConnection(id, name, 'AD');
            break;

          case 'ad.onConnectionResult':
            final id = args['endpointId'] as String? ?? '';
            final code = args['statusCode'] as int? ?? 2;
            _log('📊 [AD] نتيجة: $id → $code');
            _handleConnectionResult(id, code);
            break;

          case 'ad.onDisconnected':
            final id = args['endpointId'] as String? ?? '';
            _log('🔌 [AD] انقطع: $id');
            _handleDisconnection(id);
            break;

          case 'onPayloadReceived':
            final id = args['endpointId'] as String? ?? '';
            final bytes = args['bytes'] as Uint8List?;
            if (bytes != null) {
              _log('📦 بيانات (${bytes.length}B)');
              _onPayload(id, bytes);
            }
            break;
        }
    });
    _log('🔧 JISR handler مُسجّل ✅');
  }

  // ──────────────────────────────────────────
  //  التهيئة
  // ──────────────────────────────────────────

  void configure({required String userName, required String deviceId}) {
    _userName = userName.length > 15 ? userName.substring(0, 15) : userName;
    _log('⚙️ تهيئة: اسم=$_userName | device=${deviceId.substring(0, 8)}...');
  }

  void _log(String msg) {
    debugPrint(msg);
    final e = '${DateTime.now().toString().substring(11, 19)} $msg';
    _logs.add(e);
    if (_logs.length > 100) _logs.removeAt(0);
    _logCtrl.add(e);
  }

  // ──────────────────────────────────────────
  //  التشغيل — invokeMethod مباشر
  // ──────────────────────────────────────────

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _log('🚀 بدء التشغيل...');
    _emitStatus('جاري التشغيل...');

    // ═══ سجل handler أولاً — BinaryMessenger مباشر ═══
    _setupHandler();

    // GPS
    try {
      final loc = await _ch.invokeMethod<bool>('checkLocationEnabled') ?? false;
      if (!loc) {
        await _ch.invokeMethod('enableLocationServices');
      }
    } catch (_) {}
    _log('✅ GPS');

    // بث
    try {
      _log('📡 بدء البث...');
      final ok = await _ch.invokeMethod<bool>('startAdvertising', <String, dynamic>{
        'userNickName': _userName,
        'strategy': 2, // P2P_CLUSTER
        'serviceId': _serviceId,
      }) ?? false;
      _log('📡 البث: ${ok ? "✅ يعمل" : "❌"}');

      // ═══ أعد تسجيل handler بعد startAdvertising ═══
      _setupHandler();
    } catch (e) {
      _log('❌ بث: $e');
    }

    _log('⏳ انتظار 2 ثانية قبل الاكتشاف...');
    await Future.delayed(const Duration(seconds: 2));

    // اكتشاف
    try {
      _log('🔍 بدء الاكتشاف...');
      final ok = await _ch.invokeMethod<bool>('startDiscovery', <String, dynamic>{
        'userNickName': _userName,
        'strategy': 2,
        'serviceId': _serviceId,
      }) ?? false;
      _log('🔍 الاكتشاف: ${ok ? "✅ يعمل" : "❌"}');

      // ═══ أعد تسجيل handler بعد startDiscovery ═══
      _setupHandler();
    } catch (e) {
      _log('❌ اكتشاف: $e');
    }

    _emitStatus('شبكة نشطة 🔵 — يبحث عن أجهزة...');
    _log('✅ البث والاكتشاف يعملان');
    _log('📋 اسم: $_userName | خدمة: $_serviceId');
  }

  Future<void> stop() async {
    _isRunning = false;
    try { await _ch.invokeMethod('stopAdvertising'); } catch (_) {}
    try { await _ch.invokeMethod('stopDiscovery'); } catch (_) {}
    try { await _ch.invokeMethod('stopAllEndpoints'); } catch (_) {}
    _connectedEndpoints.clear();
    _discoveredEndpoints.clear();
    _pendingRequests.clear();
    _emitStatus('متوقف');
    _peersCtrl.add(0);
    _log('⏹️ تم الإيقاف');
  }

  // ──────────────────────────────────────────
  //  معالجة الأحداث
  // ──────────────────────────────────────────

  void _handleEndpointFound(String id, String name) {
    _discoveredEndpoints[id] = name;
    if (_connectedEndpoints.containsKey(id) || _pendingRequests.contains(id)) {
      _log('⏭️ $name — موجود');
      return;
    }
    _pendingRequests.add(id);
    _requestConnection(id, name);
  }

  Future<void> _requestConnection(String id, String name) async {
    try {
      _log('🔗 طلب اتصال بـ $name ...');
      final ok = await _ch.invokeMethod<bool>('requestConnection', <String, dynamic>{
        'userNickName': _userName,
        'endpointId': id,
      }) ?? false;
      _log('🔗 طلب: ${ok ? "✅" : "❌"}');
      // ═══ أعد التسجيل ═══
      _setupHandler();
    } catch (e) {
      _log('⚠️ طلب: $e');
      _pendingRequests.remove(id);
    }
  }

  Future<void> _acceptConnection(String id, String name, String src) async {
    try {
      _log('✅ [$src] قبول: $name ...');
      final ok = await _ch.invokeMethod<bool>('acceptConnection', <String, dynamic>{
        'endpointId': id,
      }) ?? false;
      _log('✅ [$src] قبول: ${ok ? "نجح ✅" : "فشل ❌"}');
      // ═══ أعد التسجيل ═══
      _setupHandler();
    } catch (e) {
      _log('❌ [$src] قبول: $e');
    }
  }

  void _handleConnectionResult(String id, int statusCode) {
    _pendingRequests.remove(id);
    // 0 = CONNECTED, 1 = REJECTED, 2 = ERROR
    if (statusCode == 0) {
      final name = _discoveredEndpoints[id] ?? id;
      _connectedEndpoints[id] = name;
      _peersCtrl.add(_connectedEndpoints.length);
      _emitStatus('متصل بـ ${_connectedEndpoints.length} جهاز 🟢');
      _log('🎉🎉 متصل بـ $name! (${_connectedEndpoints.length})');
      _sendPending(id);
    } else {
      _log('❌ اتصال: $id → code=$statusCode');
    }
  }

  void _handleDisconnection(String id) {
    final name = _connectedEndpoints.remove(id) ?? id;
    _pendingRequests.remove(id);
    _peersCtrl.add(_connectedEndpoints.length);
    _emitStatus(_connectedEndpoints.isEmpty
        ? 'شبكة نشطة 🔵 — يبحث...'
        : 'متصل بـ ${_connectedEndpoints.length} جهاز 🟢');
    _log('🔌 انقطع $name');
  }

  // ──────────────────────────────────────────
  //  البيانات
  // ──────────────────────────────────────────

  void _onPayload(String id, Uint8List bytes) {
    try {
      final txn = TransactionPacket.fromJsonString(utf8.decode(bytes));
      _log('📥 حوالة: ${txn.amount} ${txn.senderId}→${txn.receiverId}');
      onPacketReceived?.call(txn);
    } catch (e) {
      _log('⚠️ بيانات: $e');
    }
  }

  Future<void> _sendPending(String epId) async {
    final txns = LocalDB.getAllPending();
    if (txns.isEmpty) return;
    _log('📤 إرسال ${txns.length} حوالة');
    for (final txn in txns) {
      if (txn.ttl <= 0) { await LocalDB.removePending(txn.id); continue; }
      await sendTransaction(txn, epId);
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> sendTransaction(TransactionPacket txn, String epId) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(txn.toJsonString()));
      await _ch.invokeMethod('sendPayload', <String, dynamic>{
        'endpointId': epId,
        'bytes': bytes,
      });
      _log('📤✅ ${txn.id.substring(0, 8)}');
      return true;
    } catch (e) {
      _log('📤❌ $e');
      return false;
    }
  }

  Future<void> broadcastTransaction(TransactionPacket txn) async {
    final eps = _connectedEndpoints.keys.toList();
    if (eps.isEmpty) { _log('⚠️ لا أجهزة'); return; }
    for (final ep in eps) { await sendTransaction(txn, ep); }
  }

  void _emitStatus(String s) => _statusCtrl.add(s);

  Future<void> dispose() async {
    await stop();
    _statusCtrl.close();
    _peersCtrl.close();
    _logCtrl.close();
  }
}
