import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilities for application security, password hashing,
/// and Thai citizen personal identity validation.
class SecurityUtils {
  // Salt pepper applied to password hashes to protect against rainbow table attacks
  static const String _salt = 'water_flood_gis_salt_secure_2026';

  /// Hash password using SHA-256 with cryptographic salt
  static String hashPassword(String password) {
    if (password.isEmpty) return '';
    final bytes = utf8.encode('$password$_salt');
    return sha256.convert(bytes).toString();
  }

  /// Validate Thai National ID Card (เลขประจำตัวประชาชน 13 หลัก)
  /// Checks 13-digit length, non-uniform digits, and Mod 11 checksum algorithm.
  static bool validateThaiNationalId(String id) {
    final cleanId = id.replaceAll(RegExp(r'\D'), '');
    if (cleanId.length != 13) return false;

    // Reject all identical digits (e.g., 0000000000000, 1111111111111)
    if (RegExp(r'^(\d)\1{12}$').hasMatch(cleanId)) return false;

    int sum = 0;
    for (int i = 0; i < 12; i++) {
      sum += int.parse(cleanId[i]) * (13 - i);
    }
    final check = (11 - (sum % 11)) % 10;
    return check == int.parse(cleanId[12]);
  }

  /// Format Thai National ID with standard hyphens: x-xxxx-xxxxx-xx-x
  static String formatThaiNationalId(String id) {
    final clean = id.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 13) return id;
    return '${clean.substring(0, 1)}-${clean.substring(1, 5)}-${clean.substring(5, 10)}-${clean.substring(10, 12)}-${clean.substring(12, 13)}';
  }

  /// Mask Thai National ID for privacy display: x-xxxx-xxxxx-12-3 -> 1-xxxx-xxxxx-12-3
  static String maskThaiNationalId(String id) {
    final formatted = formatThaiNationalId(id);
    if (formatted.length != 17) return id;
    return '${formatted.substring(0, 2)}xxxx-xxxxx${formatted.substring(12)}';
  }

  /// Validate Thai phone number (10 digits starting with '0')
  static bool validateThaiPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    return clean.length == 10 && clean.startsWith('0');
  }

  /// Format Thai phone number: 0xx-xxx-xxxx
  static String formatPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length != 10) return phone;
    return '${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6, 10)}';
  }
}
