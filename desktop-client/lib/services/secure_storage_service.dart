import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _keyCookie = 'tl_session_cookie';
const _keyAccessToken = 'tl_access_token';

/// Persists auth credentials in the OS keystore via flutter_secure_storage.
///
/// On Windows this uses the Windows Credential Manager (DPAPI-encrypted).
/// On macOS the Keychain, on Linux libsecret.
class SecureStorageService {
  SecureStorageService._();

  /// Global singleton instance.
  static final SecureStorageService instance = SecureStorageService._();

  static const FlutterSecureStorage _s = FlutterSecureStorage();

  /// Read the persisted HTTP session cookie, or null if none is stored.
  Future<String?> readCookie() => _s.read(key: _keyCookie);

  /// Persist the HTTP session cookie.
  Future<void> writeCookie(String value) =>
      _s.write(key: _keyCookie, value: value);

  /// Read the persisted JWT access token, or null if none is stored.
  Future<String?> readAccessToken() => _s.read(key: _keyAccessToken);

  /// Persist the JWT access token.
  Future<void> writeAccessToken(String value) =>
      _s.write(key: _keyAccessToken, value: value);

  /// Delete both credentials from the keystore.
  Future<void> clearCredentials() async {
    await _s.delete(key: _keyCookie);
    await _s.delete(key: _keyAccessToken);
  }
}
