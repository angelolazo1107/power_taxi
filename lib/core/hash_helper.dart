import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

class HashHelper {
  HashHelper._(); // prevent instantiation

  /// Returns the SHA-256 hex digest of [input].
  /// Use this for all password / PIN storage and comparison.
  static String sha256(String input) {
    final bytes = utf8.encode(input);
    return crypto.sha256.convert(bytes).toString();
  }
}
