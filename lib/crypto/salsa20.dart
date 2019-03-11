
import 'package:crypto_wallet/crypto/encrypt.dart';
import 'package:crypto_wallet/crypto/helpers.dart';
import 'package:crypto_wallet/crypto/salsa20_engine.dart';

import 'package:pointycastle/api.dart' show ParametersWithIV, KeyParameter;

import 'dart:typed_data';

class Salsa20 implements Algorithm {
  final String key;
  final String iv;
  final ParametersWithIV<KeyParameter> _params;

  final Salsa20Engine _cipher = Salsa20Engine();

  Salsa20(this.key, this.iv)
      : _params = ParametersWithIV<KeyParameter>(
            KeyParameter(Uint8List.fromList(key.codeUnits)),
            Uint8List.fromList(iv.codeUnits));

  String encrypt(String plainText) {
    _cipher
      ..reset()
      ..init(true, _params);

    final input = Uint8List.fromList(plainText.codeUnits);
    final output = _cipher.process(input);

    return formatBytesAsHexString(output);
  }

  String decrypt(String cipherText) {
    _cipher
      ..reset()
      ..init(false, _params);

    final input = createUint8ListFromHexString(cipherText);
    final output = _cipher.process(input);

    return String.fromCharCodes(output);
  }
}
