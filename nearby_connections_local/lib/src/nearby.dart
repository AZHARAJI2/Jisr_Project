import 'dart:async';

import 'package:flutter/services.dart';
import 'package:nearby_connections/src/classes.dart';
import 'package:nearby_connections/src/defs.dart';

/// حدث من الـ Nearby handler
class NearbyEvent {
  final String method;
  final Map<dynamic, dynamic> args;
  NearbyEvent(this.method, this.args);
}

class Nearby {
  static Nearby? _instance;

  /// ═══ EVENT STREAM — instance level ═══
  final StreamController<NearbyEvent> _eventController =
      StreamController<NearbyEvent>.broadcast();
  Stream<NearbyEvent> get eventStream => _eventController.stream;

  factory Nearby() {
    if (_instance == null) {
      _instance = Nearby._();
    }
    return _instance!;
  }

  Nearby._() {
    _channel.setMethodCallHandler((MethodCall handler) {
      Map<dynamic, dynamic> args = handler.arguments!;
      
      // ═══ استخدم _instance! بدل this — لأن this قد يكون instance قديم ═══
      final self = _instance!;
      print('📨 HANDLER: ${handler.method} | self=${identityHashCode(self)}');

      // ═══ عالج الـ callbacks من self (النسخة الصحيحة) ═══
      switch (handler.method) {
        case "ad.onConnectionInitiated":
          String endpointId = args['endpointId'] ?? '-1';
          String endpointName = args['endpointName'] ?? '-1';
          String authenticationToken = args['authenticationToken'] ?? '-1';
          bool isIncomingConnection = args['isIncomingConnection'] ?? false;
          self._advertConnectionInitiated?.call(
              endpointId,
              ConnectionInfo(
                  endpointName, authenticationToken, isIncomingConnection));
          break;
        case "ad.onConnectionResult":
          String endpointId = args['endpointId'] ?? '-1';
          Status statusCode =
              Status.values[args['statusCode'] ?? Status.ERROR.index];
          self._advertConnectionResult?.call(endpointId, statusCode);
          break;
        case "ad.onDisconnected":
          String endpointId = args['endpointId'] ?? '-1';
          self._advertDisconnected?.call(endpointId);
          break;

        case "dis.onConnectionInitiated":
          String endpointId = args['endpointId'] ?? '-1';
          String endpointName = args['endpointName'] ?? '-1';
          String authenticationToken = args['authenticationToken'] ?? '-1';
          bool isIncomingConnection = args['isIncomingConnection'] ?? false;
          self._discoverConnectionInitiated?.call(
              endpointId,
              ConnectionInfo(
                  endpointName, authenticationToken, isIncomingConnection));
          break;
        case "dis.onConnectionResult":
          String endpointId = args['endpointId'] ?? '-1';
          Status statusCode =
              Status.values[args['statusCode'] ?? Status.ERROR.index];
          self._discoverConnectionResult?.call(endpointId, statusCode);
          break;
        case "dis.onDisconnected":
          String endpointId = args['endpointId'] ?? '-1';
          self._discoverDisconnected?.call(endpointId);
          break;

        case "dis.onEndpointFound":
          String endpointId = args['endpointId'] ?? '-1';
          String endpointName = args['endpointName'] ?? '-1';
          String serviceId = args['serviceId'] ?? '-1';
          self._onEndpointFound?.call(endpointId, endpointName, serviceId);
          break;
        case "dis.onEndpointLost":
          String endpointId = args['endpointId'] ?? '-1';
          self._onEndpointLost?.call(endpointId);
          break;
        case "onPayloadReceived":
          String endpointId = args['endpointId'] ?? '-1';
          int type = args['type'] ?? PayloadType.NONE;
          Uint8List bytes = args['bytes'] ?? Uint8List(0);
          int payloadId = args['payloadId'] ?? -1;
          String? filePath = args['filePath'];
          String? uri = args['uri'];
          Payload payload = Payload(
            type: PayloadType.values[type],
            bytes: bytes,
            id: payloadId,
            filePath: filePath,
            uri: uri,
          );
          self._onPayloadReceived?.call(endpointId, payload);
          break;
        case "onPayloadTransferUpdate":
          String endpointId = args['endpointId'] ?? '-1';
          int payloadId = args['payloadId'] ?? -1;
          int status = args['status'] ?? Status.ERROR.index;
          int bytesTransferred = args['bytesTransferred'] ?? 0;
          int totalBytes = args['totalBytes'] ?? 0;
          PayloadTransferUpdate payloadTransferUpdate = PayloadTransferUpdate(
            id: payloadId,
            status: PayloadStatus.values[status],
            bytesTransferred: bytesTransferred,
            totalBytes: totalBytes,
          );
          self._onPayloadTransferUpdate?.call(endpointId, payloadTransferUpdate);
          break;
      }
      return Future.value();
    });
  }

  //for advertisers
  OnConnectionInitiated? _advertConnectionInitiated,
      _discoverConnectionInitiated;
  OnConnectionResult? _advertConnectionResult, _discoverConnectionResult;
  OnDisconnected? _advertDisconnected, _discoverDisconnected;

  //for discoverers
  OnEndpointFound? _onEndpointFound;
  OnEndpointLost? _onEndpointLost;

  //for receiving payload
  OnPayloadReceived? _onPayloadReceived;
  OnPayloadTransferUpdate? _onPayloadTransferUpdate;

  static const MethodChannel _channel =
      const MethodChannel('nearby_connections');

  @Deprecated("Consider using package:permission_handler")
  Future<bool> checkLocationPermission() async =>
      await _channel.invokeMethod('checkLocationPermission') ?? false;

  @Deprecated("Consider using package:permission_handler")
  Future<bool> askLocationPermission() async =>
      await _channel.invokeMethod('askLocationPermission') ?? false;

  @Deprecated("Consider using package:permission_handler")
  Future<bool> checkExternalStoragePermission() async =>
      await _channel.invokeMethod('checkExternalStoragePermission') ?? false;

  @Deprecated("Consider using package:permission_handler")
  Future<bool> checkBluetoothPermission() async =>
      await _channel.invokeMethod('checkBluetoothPermission') ?? false;

  @Deprecated("Consider using package:permission_handler")
  Future<bool> checkLocationEnabled() async =>
      await _channel.invokeMethod('checkLocationEnabled') ?? false;

  Future<bool> enableLocationServices() async =>
      await _channel.invokeMethod('enableLocationServices') ?? false;

  @Deprecated("Consider using package:permission_handler")
  void askExternalStoragePermission() =>
      _channel.invokeMethod('askExternalStoragePermission');

  @Deprecated("Consider using package:permission_handler")
  void askBluetoothPermission() =>
      _channel.invokeMethod('askBluetoothPermission');

  @Deprecated("Consider using package:permission_handler")
  void askLocationAndExternalStoragePermission() =>
      _channel.invokeMethod('askLocationAndExternalStoragePermission');

  Future<bool> copyFileAndDeleteOriginal(
          String sourceUri, String destinationFilepath) async =>
      await _channel.invokeMethod('copyFileAndDeleteOriginal', {
        'sourceUri': sourceUri,
        'destinationFilepath': destinationFilepath,
      });

  Future<bool> startAdvertising(
    String userNickName,
    Strategy strategy, {
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
    String serviceId = "com.pkmnapps.nearby_connections",
  }) async {
    this._advertConnectionInitiated = onConnectionInitiated;
    this._advertConnectionResult = onConnectionResult;
    this._advertDisconnected = onDisconnected;
    print('📡 startAdvertising: instance=${identityHashCode(this)}');

    return await _channel.invokeMethod('startAdvertising', <String, dynamic>{
          'userNickName': userNickName,
          'strategy': strategy.index,
          'serviceId': serviceId,
        }) ??
        false;
  }

  Future<void> stopAdvertising() async {
    await _channel.invokeMethod('stopAdvertising');
  }

  Future<bool> startDiscovery(
    String userNickName,
    Strategy strategy, {
    required OnEndpointFound onEndpointFound,
    required OnEndpointLost onEndpointLost,
    String serviceId = "com.pkmnapps.nearby_connections",
  }) async {
    this._onEndpointFound = onEndpointFound;
    print('🔍 startDiscovery: instance=${identityHashCode(this)} | _onEndpointFound=${_onEndpointFound != null}');
    this._onEndpointLost = onEndpointLost;

    return await _channel.invokeMethod('startDiscovery', <String, dynamic>{
          'userNickName': userNickName,
          'strategy': strategy.index,
          'serviceId': serviceId,
        }) ??
        false;
  }

  Future<void> stopDiscovery() async {
    await _channel.invokeMethod('stopDiscovery');
  }

  Future<void> stopAllEndpoints() async {
    await _channel.invokeMethod('stopAllEndpoints');
  }

  Future<void> disconnectFromEndpoint(String endpointId) async {
    await _channel.invokeMethod(
        'disconnectFromEndpoint', <String, dynamic>{'endpointId': endpointId});
  }

  Future<bool> requestConnection(
    String userNickName,
    String endpointId, {
    required OnConnectionInitiated onConnectionInitiated,
    required OnConnectionResult onConnectionResult,
    required OnDisconnected onDisconnected,
  }) async {
    this._discoverConnectionInitiated = onConnectionInitiated;
    this._discoverConnectionResult = onConnectionResult;
    this._discoverDisconnected = onDisconnected;

    return await _channel.invokeMethod(
          'requestConnection',
          <String, dynamic>{
            'userNickName': userNickName,
            'endpointId': endpointId,
          },
        ) ??
        false;
  }

  Future<bool> acceptConnection(
    String endpointId, {
    required OnPayloadReceived onPayLoadRecieved,
    OnPayloadTransferUpdate? onPayloadTransferUpdate,
  }) async {
    this._onPayloadReceived = onPayLoadRecieved;
    this._onPayloadTransferUpdate = onPayloadTransferUpdate;

    return await _channel.invokeMethod(
          'acceptConnection',
          <String, dynamic>{
            'endpointId': endpointId,
          },
        ) ??
        false;
  }

  Future<bool> rejectConnection(String endpointId) async {
    return await _channel.invokeMethod(
          'rejectConnection',
          <String, dynamic>{
            'endpointId': endpointId,
          },
        ) ??
        false;
  }

  Future<void> sendBytesPayload(String endpointId, Uint8List bytes) async {
    return await _channel.invokeMethod(
      'sendPayload',
      <String, dynamic>{
        'endpointId': endpointId,
        'bytes': bytes,
      },
    );
  }

  Future<int> sendFilePayload(String endpointId, String filePath) async {
    return await _channel.invokeMethod(
      'sendFilePayload',
      <String, dynamic>{
        'endpointId': endpointId,
        'filePath': filePath,
      },
    );
  }

  Future<void> cancelPayload(int payloadId) async {
    return await _channel.invokeMethod(
      'cancelPayload',
      <String, dynamic>{
        'payloadId': payloadId.toString(),
      },
    );
  }
}
