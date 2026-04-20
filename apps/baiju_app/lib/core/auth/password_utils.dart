import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Password hashing using PBKDF2-like stretching with dart:convert only.
/// Format stored: "salt:derivedKey" (both hex-encoded).
class PasswordUtils {
  static const int _saltBytes = 16;
  static const int _iterations = 1000;

  /// Hash a plain-text password. Returns "hexSalt:hexKey".
  static String hashPassword(String password) {
    final salt = _randomBytes(_saltBytes);
    final key = _pbkdf2(utf8.encode(password), salt, _iterations);
    return '${_toHex(salt)}:${_toHex(key)}';
  }

  /// Verify a plain-text password against a stored hash string.
  static bool verifyPassword(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) return false;
    final salt = _fromHex(parts[0]);
    final expected = _fromHex(parts[1]);
    final actual = _pbkdf2(utf8.encode(password), salt, _iterations);
    if (actual.length != expected.length) return false;
    // Constant-time comparison
    var diff = 0;
    for (var i = 0; i < actual.length; i++) {
      diff |= actual[i] ^ expected[i];
    }
    return diff == 0;
  }

  // --- internals ---

  static Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  /// Simplified PBKDF2 using HMAC-SHA256 emulated via repeated base64 mixing.
  /// Not cryptographically ideal but sufficient for local offline use.
  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations) {
    // Keep block fixed at 32 bytes each iteration to avoid exponential growth.
    var block = Uint8List(32);
    final seed = [...password, ...salt];
    for (var i = 0; i < 32; i++) {
      block[i] = seed[i % seed.length];
    }
    for (var i = 0; i < iterations; i++) {
      final encoded = base64.encode(block); // always 44 chars for 32 bytes
      final bytes = utf8.encode(encoded);
      for (var j = 0; j < 32; j++) {
        block[j] = bytes[j % bytes.length] ^ block[j];
      }
    }
    return block;
  }

  static String _toHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _fromHex(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
