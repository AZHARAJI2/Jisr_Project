import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/transaction_packet.dart';
import '../data/local_db.dart';
import 'security_service.dart';

class PeerTelemetry {
  final String endpointId;
  final String displayName;
  final int successfulSends;
  final int failedSends;
  final int routedTransfers;
  final int lastSeenMs;
  final int lastHelloMs;

  const PeerTelemetry({
    required this.endpointId,
    required this.displayName,
    required this.successfulSends,
    required this.failedSends,
    required this.routedTransfers,
    required this.lastSeenMs,
    required this.lastHelloMs,
  });

  double get successRate {
    final total = successfulSends + failedSends;
    if (total <= 0) return 0.5;
    return successfulSends / total;
  }

  double score(int nowMs) {
    final ageSec = ((nowMs - lastSeenMs).clamp(0, 120000)) / 1000.0;
    final freshness = (1.0 - (ageSec / 120.0)).clamp(0.0, 1.0);
    return (successRate * 65.0) + (freshness * 25.0) + (routedTransfers * 2.0);
  }
}

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
  String _userId = '';
  String _deviceId = '';
  final SecurityService _security = SecurityService.instance;

  final Map<String, String> _connectedEndpoints = {};
  final Map<String, String> _discoveredEndpoints = {};
  final Map<String, String> _peerUserByEndpoint = {};
  final Map<String, String> _peerSignPubByEndpoint = {};
  final Map<String, String> _peerKxPubByEndpoint = {};
  final Map<String, int> _peerSuccessCount = {};
  final Map<String, int> _peerFailCount = {};
  final Map<String, int> _peerRouteCount = {};
  final Map<String, int> _peerLastSeenMs = {};
  final Map<String, int> _peerLastHelloMs = {};
  final Set<String> _seenSecureFrames = <String>{};
  final List<String> _seenSecureFramesOrder = <String>[];
  final Set<String> _seenTraceEvents = <String>{};
  final List<String> _seenTraceEventsOrder = <String>[];
  final Set<String> _pendingRequests = {};
  final Set<String> _helloSent = {};
  static const int _maxClockSkewMs = 2 * 60 * 1000;
  static const int _maxReplayCache = 2000;

  bool _isRunning = false;
  bool get isRunning => _isRunning;
  int get connectedCount => _connectedEndpoints.length;
  List<String> get connectedDevices => _connectedEndpoints.values.toList();

  Future<void> Function(TransactionPacket txn)? onPacketReceived;
  Future<void> Function(Map<String, dynamic> trace)? onTraceReceived;

  final _statusCtrl = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusCtrl.stream;
  final _peersCtrl = StreamController<int>.broadcast();
  Stream<int> get peersStream => _peersCtrl.stream;

  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);
  final _logCtrl = StreamController<String>.broadcast();
  Stream<String> get logStream => _logCtrl.stream;
  bool _handlerRegistered = false;

  // ──────────────────────────────────────────
  //  Handler — يُسجّل مرة واحدة ويبقى
  // ──────────────────────────────────────────

  void _setupHandler() {
    if (_handlerRegistered) return;
    Future<dynamic> handler(MethodCall call) async {
      final args = call.arguments as Map<dynamic, dynamic>;
      _log('📨 JISR: ${call.method}');

        switch (call.method) {
          case 'dis.onEndpointFound':
            final id = args['endpointId'] as String? ?? '';
            final name = args['endpointName'] as String? ?? '';
            _touchPeer(id);
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
            _touchPeer(id);
            _log('🤝 [DIS] اتصال: $name ($id)');
            _log('🤝 [DIS] auto-accepted in native plugin');
            break;

          case 'dis.onConnectionResult':
            final id = args['endpointId'] as String? ?? '';
            final code = args['statusCode'] as int? ?? 2;
            _touchPeer(id);
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
            _touchPeer(id);
            _log('🤝 [AD] وارد: $name ($id)');
            _log('🤝 [AD] auto-accepted in native plugin');
            break;

          case 'ad.onConnectionResult':
            final id = args['endpointId'] as String? ?? '';
            final code = args['statusCode'] as int? ?? 2;
            _touchPeer(id);
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
              await _onPayload(id, bytes);
            }
            break;
        }
    }

    // استقبل الأحداث من قناة jisr_events فقط لتجنب تكرار نفس الحدث مرتين.
    _events.setMethodCallHandler(handler);
    _handlerRegistered = true;
    _log('🔧 JISR handler مُسجّل ✅');
  }

  // ──────────────────────────────────────────
  //  التهيئة
  // ──────────────────────────────────────────

  Future<void> configure({
    required String userName,
    required String deviceId,
    required String userId,
  }) async {
    await _security.initialize();
    _userName = userName.length > 15 ? userName.substring(0, 15) : userName;
    _userId = userId;
    _deviceId = deviceId;
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
      // بعض الأجهزة ترجع خطأ صلاحية مؤقت؛ أعد المحاولة مرة واحدة.
      await Future.delayed(const Duration(seconds: 2));
      try {
        final retry = await _ch.invokeMethod<bool>('startDiscovery', <String, dynamic>{
          'userNickName': _userName,
          'strategy': 2,
          'serviceId': _serviceId,
        }) ?? false;
        _log('🔁 إعادة محاولة الاكتشاف: ${retry ? "✅" : "❌"}');
      } catch (retryErr) {
        _log('❌ فشل إعادة الاكتشاف: $retryErr');
      }
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
    _peerUserByEndpoint.clear();
    _peerSignPubByEndpoint.clear();
    _peerKxPubByEndpoint.clear();
    _peerSuccessCount.clear();
    _peerFailCount.clear();
    _peerRouteCount.clear();
    _peerLastSeenMs.clear();
    _peerLastHelloMs.clear();
    _pendingRequests.clear();
    _helloSent.clear();
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
    // طلب الاتصال يتم تلقائيا من Native plugin داخل onEndpointFound.
    // لا نكرر requestConnection من Flutter حتى لا يحدث collision/8003.
    _pendingRequests.add(id);
    _log('🤖 AUTO native connect -> $name ($id)');
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
      _sendHello(id);
      _sendPending(id);
    } else {
      _log('❌ اتصال: $id → code=$statusCode');
    }
  }

  void _handleDisconnection(String id) {
    final name = _connectedEndpoints.remove(id) ?? id;
    _pendingRequests.remove(id);
    _peerUserByEndpoint.remove(id);
    _peerSignPubByEndpoint.remove(id);
    _peerKxPubByEndpoint.remove(id);
    _helloSent.remove(id);
    _peersCtrl.add(_connectedEndpoints.length);
    _emitStatus(_connectedEndpoints.isEmpty
        ? 'شبكة نشطة 🔵 — يبحث...'
        : 'متصل بـ ${_connectedEndpoints.length} جهاز 🟢');
    _log('🔌 انقطع $name');
  }

  // ──────────────────────────────────────────
  //  البيانات
  // ──────────────────────────────────────────

  Future<void> _onPayload(String id, Uint8List bytes) async {
    try {
      final raw = utf8.decode(bytes);
      final Map<String, dynamic> msg = Map<String, dynamic>.from(
        jsonDecode(raw) as Map,
      );
      final type = msg['type'] as String? ?? '';

      if (type == 'hello') {
        await _handleHelloMessage(id, msg);
        return;
      }

      if (type == 'txn') {
        await _handleSecureTransactionMessage(id, msg);
        return;
      }
      if (type == 'trace') {
        await _handleTraceMessage(id, msg);
        return;
      }

      _log('🚫 payload غير معتمد (ليس hello/txn)');
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
      final peerKx = _peerKxPubByEndpoint[epId];
      if (peerKx == null || peerKx.isEmpty) {
        _log('🔐 لا يوجد مفتاح للجهاز $epId، جارٍ انتظار HELLO...');
        return false;
      }
      final aad = 'jisr:$epId:${txn.id}';
      final enc = await _security.encryptForPeer(
        plaintext: txn.toJsonString(),
        peerKeyAgreementPublicKeyB64: peerKx,
        aad: aad,
      );
      final ts = DateTime.now().millisecondsSinceEpoch;
      final signPayload = '$aad|$ts|${enc['nonce']}|${enc['cipherText']}|${enc['mac']}';
      final sig = await _security.signToB64(utf8.encode(signPayload));
      final envelope = <String, dynamic>{
        'type': 'txn',
        'ts': ts,
        'aad': aad,
        'nonce': enc['nonce'],
        'cipherText': enc['cipherText'],
        'mac': enc['mac'],
        'sig': sig,
        'sigPub': _security.signingPublicKeyB64,
      };
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
      await _ch.invokeMethod('sendPayload', <String, dynamic>{
        'endpointId': epId,
        'bytes': bytes,
      });
      _peerSuccessCount[epId] = (_peerSuccessCount[epId] ?? 0) + 1;
      _touchPeer(epId);
      _log('📤✅ ${txn.id.substring(0, 8)}');
      return true;
    } catch (e) {
      _peerFailCount[epId] = (_peerFailCount[epId] ?? 0) + 1;
      _touchPeer(epId);
      _log('📤❌ $e');
      return false;
    }
  }

  Future<void> broadcastTransaction(TransactionPacket txn) async {
    final eps = _connectedEndpoints.keys.toList();
    if (eps.isEmpty) { _log('⚠️ لا أجهزة'); return; }
    for (final ep in eps) { await sendTransaction(txn, ep); }
  }

  Future<void> _sendHello(String endpointId) async {
    if (_helloSent.contains(endpointId)) return;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final core = '$_userId|$_deviceId|${_security.signingPublicKeyB64}|${_security.keyAgreementPublicKeyB64}|$ts';
      final sig = await _security.signToB64(utf8.encode(core));
      final hello = <String, dynamic>{
        'type': 'hello',
        'userId': _userId,
        'deviceId': _deviceId,
        'sigPub': _security.signingPublicKeyB64,
        'kxPub': _security.keyAgreementPublicKeyB64,
        'ts': ts,
        'sig': sig,
      };
      await _ch.invokeMethod('sendPayload', <String, dynamic>{
        'endpointId': endpointId,
        'bytes': Uint8List.fromList(utf8.encode(jsonEncode(hello))),
      });
      _helloSent.add(endpointId);
      _log('🔐 HELLO -> $endpointId');
    } catch (e) {
      _log('⚠️ HELLO fail: $e');
    }
  }

  Future<void> _handleHelloMessage(String endpointId, Map<String, dynamic> msg) async {
    final userId = msg['userId'] as String? ?? '';
    final sigPub = msg['sigPub'] as String? ?? '';
    final kxPub = msg['kxPub'] as String? ?? '';
    final ts = msg['ts'] as int? ?? 0;
    final sig = msg['sig'] as String? ?? '';
    final deviceId = msg['deviceId'] as String? ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - ts).abs() > _maxClockSkewMs) {
      _log('🚫 HELLO expired/skew from $endpointId');
      return;
    }
    final core = '$userId|$deviceId|$sigPub|$kxPub|$ts';
    final ok = await _security.verifyFromB64(
      message: utf8.encode(core),
      signatureB64: sig,
      publicKeyB64: sigPub,
    );
    if (!ok) {
      _log('🚫 HELLO signature invalid from $endpointId');
      return;
    }

    final knownSign = _peerSignPubByEndpoint[endpointId];
    if (knownSign != null && knownSign.isNotEmpty && knownSign != sigPub) {
      _log('🚫 HELLO key changed (possible MITM) from $endpointId');
      return;
    }
    final knownKx = _peerKxPubByEndpoint[endpointId];
    if (knownKx != null && knownKx.isNotEmpty && knownKx != kxPub) {
      _log('🚫 HELLO agreement key changed from $endpointId');
      return;
    }

    _peerUserByEndpoint[endpointId] = userId;
    _peerSignPubByEndpoint[endpointId] = sigPub;
    _peerKxPubByEndpoint[endpointId] = kxPub;
    _peerLastHelloMs[endpointId] = DateTime.now().millisecondsSinceEpoch;
    _connectedEndpoints[endpointId] = userId.isEmpty ? endpointId : userId;
    _peersCtrl.add(_connectedEndpoints.length);
    _log('🔐 HELLO OK <- ${userId.isEmpty ? endpointId : userId}');
    await _sendHello(endpointId);
  }

  Future<void> _handleSecureTransactionMessage(
    String endpointId,
    Map<String, dynamic> msg,
  ) async {
    final aad = msg['aad'] as String? ?? '';
    final nonce = msg['nonce'] as String? ?? '';
    final cipherText = msg['cipherText'] as String? ?? '';
    final mac = msg['mac'] as String? ?? '';
    final sig = msg['sig'] as String? ?? '';
    final sigPub = msg['sigPub'] as String? ?? '';
    final ts = msg['ts'] as int? ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - ts).abs() > _maxClockSkewMs) {
      _log('🚫 SEC frame expired/skew from $endpointId');
      return;
    }
    final frameId = '$endpointId|$aad|$nonce|$mac';
    if (_seenSecureFrames.contains(frameId)) {
      _log('🚫 SEC replay detected from $endpointId');
      return;
    }
    _rememberSecureFrame(frameId);

    final signPayload = '$aad|$ts|$nonce|$cipherText|$mac';
    final knownPub = _peerSignPubByEndpoint[endpointId];
    final pubToVerify = (knownPub != null && knownPub.isNotEmpty) ? knownPub : sigPub;
    final verified = await _security.verifyFromB64(
      message: utf8.encode(signPayload),
      signatureB64: sig,
      publicKeyB64: pubToVerify,
    );
    if (!verified) {
      _log('🚫 SEC message signature invalid from $endpointId');
      return;
    }

    final kxPub = _peerKxPubByEndpoint[endpointId];
    if (kxPub == null || kxPub.isEmpty) {
      _log('🚫 SEC message without peer key from $endpointId');
      return;
    }

    final plain = await _security.decryptFromPeer(
      nonceB64: nonce,
      cipherTextB64: cipherText,
      macB64: mac,
      peerKeyAgreementPublicKeyB64: kxPub,
      aad: aad,
    );
    final txn = TransactionPacket.fromJsonString(plain);
    _peerRouteCount[endpointId] = (_peerRouteCount[endpointId] ?? 0) + 1;
    _touchPeer(endpointId);
    _log('📥🔐 حوالة: ${txn.amount} ${txn.senderId}→${txn.receiverId}');
    await onPacketReceived?.call(txn);
  }

  Future<void> publishTraceEvent({
    required String txnId,
    required String state,
    required List<String> path,
    int ttl = 4,
  }) async {
    final eventId = 'trace-$txnId-$_userId-${DateTime.now().millisecondsSinceEpoch}';
    _rememberTrace(eventId);
    final trace = <String, dynamic>{
      'type': 'trace',
      'eventId': eventId,
      'txnId': txnId,
      'nodeId': _userId,
      'state': state,
      'path': path,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'ttl': ttl,
    };
    await _broadcastRaw(jsonEncode(trace));
  }

  Future<void> _handleTraceMessage(String fromEndpoint, Map<String, dynamic> msg) async {
    final eventId = msg['eventId'] as String? ?? '';
    if (eventId.isEmpty || _seenTraceEvents.contains(eventId)) return;
    _rememberTrace(eventId);
    _touchPeer(fromEndpoint);
    await onTraceReceived?.call(msg);

    final ttl = (msg['ttl'] as int?) ?? 0;
    if (ttl <= 0) return;
    final forward = Map<String, dynamic>.from(msg);
    forward['ttl'] = ttl - 1;
    await _broadcastRaw(jsonEncode(forward), exceptEndpoint: fromEndpoint);
  }

  void _rememberSecureFrame(String frameId) {
    _seenSecureFrames.add(frameId);
    _seenSecureFramesOrder.add(frameId);
    if (_seenSecureFramesOrder.length <= _maxReplayCache) return;
    final oldest = _seenSecureFramesOrder.removeAt(0);
    _seenSecureFrames.remove(oldest);
  }

  void _rememberTrace(String eventId) {
    _seenTraceEvents.add(eventId);
    _seenTraceEventsOrder.add(eventId);
    if (_seenTraceEventsOrder.length <= _maxReplayCache) return;
    final oldest = _seenTraceEventsOrder.removeAt(0);
    _seenTraceEvents.remove(oldest);
  }

  void _touchPeer(String endpointId) {
    _peerLastSeenMs[endpointId] = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _broadcastRaw(String payload, {String? exceptEndpoint}) async {
    final bytes = Uint8List.fromList(utf8.encode(payload));
    final endpoints = _connectedEndpoints.keys.toList();
    for (final ep in endpoints) {
      if (exceptEndpoint != null && ep == exceptEndpoint) continue;
      try {
        await _ch.invokeMethod('sendPayload', <String, dynamic>{
          'endpointId': ep,
          'bytes': bytes,
        });
      } catch (_) {}
    }
  }

  List<PeerTelemetry> getPeerTelemetry() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final peers = <PeerTelemetry>[];
    for (final entry in _connectedEndpoints.entries) {
      final ep = entry.key;
      peers.add(PeerTelemetry(
        endpointId: ep,
        displayName: entry.value,
        successfulSends: _peerSuccessCount[ep] ?? 0,
        failedSends: _peerFailCount[ep] ?? 0,
        routedTransfers: _peerRouteCount[ep] ?? 0,
        lastSeenMs: _peerLastSeenMs[ep] ?? now,
        lastHelloMs: _peerLastHelloMs[ep] ?? 0,
      ));
    }
    peers.sort((a, b) => b.score(now).compareTo(a.score(now)));
    return peers;
  }

  void _emitStatus(String s) => _statusCtrl.add(s);

  Future<void> dispose() async {
    await stop();
    _statusCtrl.close();
    _peersCtrl.close();
    _logCtrl.close();
  }
}
