import 'dart:convert';

class InviteCode {
  const InviteCode({required this.serverUrl, required this.token});

  final String serverUrl;
  final String token;

  static const _prefix = 'TLK1.';

  String encode() {
    final json = jsonEncode({'u': serverUrl, 't': token});
    final bytes = utf8.encode(json);
    final b64 = base64Url.encode(bytes).replaceAll('=', '');
    return '$_prefix$b64';
  }

  static InviteCode? tryDecode(String raw) {
    final s = raw.trim();
    if (!s.startsWith(_prefix)) return null;
    final body = s.substring(_prefix.length);
    final padded = body.padRight(body.length + (4 - body.length % 4) % 4, '=');
    try {
      final bytes = base64Url.decode(padded);
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final url = map['u'] as String?;
      final token = map['t'] as String?;
      if (url == null || token == null) return null;
      return InviteCode(serverUrl: url, token: token);
    } catch (_) {
      return null;
    }
  }
}
