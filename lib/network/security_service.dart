import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';

class SecurityService {
  SecurityService._();
  static final SecurityService instance = SecurityService._();

  static const _boxName = 'security_keys';
  static const _signPrivKey = 'ed25519_private';
  static const _signPubKey = 'ed25519_public';
  static const _kxPrivKey = 'x25519_private';
  static const _kxPubKey = 'x25519_public';

  final Ed25519 _ed25519 = Ed25519();
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  final Cipher _cipher = Chacha20.poly1305Aead();

  bool _initialized = false;
  late SimpleKeyPair _signingKeyPair;
  late List<int> _signingPublicKey;
  late SimpleKeyPair _keyAgreementKeyPair;
  late List<int> _keyAgreementPublicKey;

  String get signingPublicKeyB64 => base64Encode(_signingPublicKey);
  String get keyAgreementPublicKeyB64 => base64Encode(_keyAgreementPublicKey);

  Future<void> initialize() async {
    if (_initialized) return;

    final box = await Hive.openBox(_boxName);

    final storedSignPriv = box.get(_signPrivKey) as String?;
    final storedSignPub = box.get(_signPubKey) as String?;
    final storedKxPriv = box.get(_kxPrivKey) as String?;
    final storedKxPub = box.get(_kxPubKey) as String?;

    if (storedSignPriv != null &&
        storedSignPub != null &&
        storedKxPriv != null &&
        storedKxPub != null) {
      final signPrivBytes = base64Decode(storedSignPriv);
      final signPubBytes = base64Decode(storedSignPub);
      final kxPrivBytes = base64Decode(storedKxPriv);
      final kxPubBytes = base64Decode(storedKxPub);

      _signingKeyPair = SimpleKeyPairData(
        signPrivBytes,
        publicKey: SimplePublicKey(signPubBytes, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );
      _signingPublicKey = signPubBytes;

      _keyAgreementKeyPair = SimpleKeyPairData(
        kxPrivBytes,
        publicKey: SimplePublicKey(kxPubBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      _keyAgreementPublicKey = kxPubBytes;
    } else {
      _signingKeyPair = await _ed25519.newKeyPair();
      final signPub = await _signingKeyPair.extractPublicKey();
      final signPriv = await _signingKeyPair.extractPrivateKeyBytes();
      _signingPublicKey = signPub.bytes;

      _keyAgreementKeyPair = await _x25519.newKeyPair();
      final kxPub = await _keyAgreementKeyPair.extractPublicKey();
      final kxPriv = await _keyAgreementKeyPair.extractPrivateKeyBytes();
      _keyAgreementPublicKey = kxPub.bytes;

      await box.put(_signPrivKey, base64Encode(signPriv));
      await box.put(_signPubKey, base64Encode(signPub.bytes));
      await box.put(_kxPrivKey, base64Encode(kxPriv));
      await box.put(_kxPubKey, base64Encode(kxPub.bytes));
    }

    _initialized = true;
  }

  Future<String> signToB64(List<int> bytes) async {
    final sig = await _ed25519.sign(bytes, keyPair: _signingKeyPair);
    return base64Encode(sig.bytes);
  }

  Future<bool> verifyFromB64({
    required List<int> message,
    required String signatureB64,
    required String publicKeyB64,
  }) async {
    try {
      final sig = Signature(
        base64Decode(signatureB64),
        publicKey: SimplePublicKey(
          base64Decode(publicKeyB64),
          type: KeyPairType.ed25519,
        ),
      );
      return _ed25519.verify(message, signature: sig);
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> encryptForPeer({
    required String plaintext,
    required String peerKeyAgreementPublicKeyB64,
    required String aad,
  }) async {
    final peerPub = SimplePublicKey(
      base64Decode(peerKeyAgreementPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyAgreementKeyPair,
      remotePublicKey: peerPub,
    );
    final sessionKey = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: Uint8List.fromList(utf8.encode(aad)),
      info: Uint8List.fromList(utf8.encode('jisr-mesh-transport-v1')),
    );
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: sessionKey,
      aad: utf8.encode(aad),
    );
    return {
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
  }

  Future<String> decryptFromPeer({
    required String nonceB64,
    required String cipherTextB64,
    required String macB64,
    required String peerKeyAgreementPublicKeyB64,
    required String aad,
  }) async {
    final peerPub = SimplePublicKey(
      base64Decode(peerKeyAgreementPublicKeyB64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: _keyAgreementKeyPair,
      remotePublicKey: peerPub,
    );
    final sessionKey = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: Uint8List.fromList(utf8.encode(aad)),
      info: Uint8List.fromList(utf8.encode('jisr-mesh-transport-v1')),
    );
    final box = SecretBox(
      base64Decode(cipherTextB64),
      nonce: base64Decode(nonceB64),
      mac: Mac(base64Decode(macB64)),
    );
    final bytes = await _cipher.decrypt(
      box,
      secretKey: sessionKey,
      aad: utf8.encode(aad),
    );
    return utf8.decode(bytes);
  }
}
