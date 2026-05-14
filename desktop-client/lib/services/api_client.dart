import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_client/services/secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown when the server returns an HTTP error response.
class ApiException implements Exception {
  /// Creates an [ApiException].
  const ApiException(this.statusCode, this.message, {this.body});

  /// HTTP status code returned by the server.
  final int statusCode;

  /// Human-readable error message from the server.
  final String message;

  /// Parsed response body, present for conflict (409) responses containing
  /// a `current` field with the server's authoritative object.
  final Map<String, dynamic>? body;

  /// User-facing message. Strips the `ApiException(…):` prefix so UI code
  /// can use `e.toString()` directly without leaking the class name.
  @override
  String toString() => message;
}

/// Strip exception-class prefixes from an arbitrary error so it can be
/// shown to end users without leaking internals like `Exception:` or
/// `_ClientSocketException:`.
String humanizeError(Object error) {
  if (error is ApiException) return error.message;
  final s = error.toString();
  // Drop a leading "ClassName: " prefix if present.
  final colon = s.indexOf(': ');
  if (colon > 0 && colon < 80) return s.substring(colon + 2);
  return s;
}

/// Thin HTTP wrapper around the TeamLink sync-server.
///
/// Manages session cookies automatically. Use [apiClientProvider]
/// to obtain the singleton via Riverpod.
class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();

  /// Global singleton instance.
  static ApiClient get instance => _instance;

  final HttpClient _http = HttpClient();
  final SecureStorageService _storage = SecureStorageService.instance;
  String? _cookie;
  String? _accessToken;
  String _baseUrl = 'http://localhost:3000';

  /// Whether the client currently holds a session cookie.
  bool get hasSession => _cookie != null;

  /// JWT access token received during the last login/register, if any.
  String? get accessToken => _accessToken;

  /// Current HTTP base URL (no trailing slash).
  String get baseUrl => _baseUrl;

  /// Update the HTTP base URL. Trailing slashes are stripped.
  void setBaseUrl(String url) {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
  }

  /// Restore session from OS keystore. Must be called once before [getMe].
  Future<void> initFromStorage() async {
    _cookie = await _storage.readCookie();
    _accessToken = await _storage.readAccessToken();
  }

  /// Forget the session cookie and access token (used when switching servers).
  void clearSession() {
    _cookie = null;
    _accessToken = null;
    unawaited(_storage.clearCredentials());
  }

  void _saveCookies(HttpClientResponse res) {
    if (res.cookies.isEmpty) return;
    _cookie = res.cookies
        .map((c) => '${c.name}=${c.value}')
        .join('; ');
  }

  Future<dynamic> _finalize(
    HttpClientRequest req, [
    Map<String, dynamic>? body,
  ]) async {
    req.headers.contentType = ContentType.json;
    if (_cookie != null) req.headers.set('cookie', _cookie!);
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    _saveCookies(res);
    final raw = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 400) {
      var msg = 'request failed';
      Map<String, dynamic>? errorBody;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          errorBody = decoded;
          msg = decoded['error'] as String? ?? msg;
        }
      } on FormatException {
        // keep default message
      }
      throw ApiException(res.statusCode, msg, body: errorBody);
    }
    if (raw.isEmpty) return null;
    return jsonDecode(raw);
  }

  Future<dynamic> _get(String path) async {
    final req = await _http.getUrl(
      Uri.parse('$_baseUrl$path'),
    );
    return _finalize(req);
  }

  Future<dynamic> _post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final req = await _http.postUrl(
      Uri.parse('$_baseUrl$path'),
    );
    return _finalize(req, body);
  }

  Future<dynamic> _patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final req = await _http.patchUrl(
      Uri.parse('$_baseUrl$path'),
    );
    return _finalize(req, body);
  }

  Future<void> _delete(String path) async {
    final req = await _http.deleteUrl(
      Uri.parse('$_baseUrl$path'),
    );
    await _finalize(req);
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Authenticate with [email] and [password]; stores the session cookie.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final data =
        (await _post('/auth/login', {'email': email, 'password': password}))
            as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    await _persistCredentials();
    return data;
  }

  /// Create a new account.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = (await _post('/auth/register', {
      'name': name,
      'email': email,
      'password': password,
    })) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String?;
    await _persistCredentials();
    return data;
  }

  /// End the current session and clear the stored cookie.
  Future<void> logout() async {
    await _post('/auth/logout');
    _cookie = null;
    _accessToken = null;
    await _storage.clearCredentials();
  }

  Future<void> _persistCredentials() async {
    if (_cookie != null) await _storage.writeCookie(_cookie!);
    if (_accessToken != null) await _storage.writeAccessToken(_accessToken!);
  }

  /// Return the currently authenticated user.
  Future<Map<String, dynamic>> getMe() async =>
      (await _get('/auth/me')) as Map<String, dynamic>;

  // ── Invites ───────────────────────────────────────────────────────────────

  /// Host: create an invite token for [projectId] (or workspace-wide if null).
  Future<Map<String, dynamic>> createInvite({
    String? projectId,
    String role = 'member',
    int? ttlHours,
  }) async =>
      (await _post('/invites', {
        if (projectId != null) 'project_id': projectId,
        'role': role,
        if (ttlHours != null) 'ttl_hours': ttlHours,
      })) as Map<String, dynamic>;

  /// Joiner: read public info about an invite (project name, role).
  Future<Map<String, dynamic>> getInvite(String token) async =>
      (await _get('/invites/$token')) as Map<String, dynamic>;

  /// Joiner: redeem an invite by creating an account; server sets the session.
  Future<Map<String, dynamic>> acceptInvite({
    required String token,
    required String name,
    required String email,
    required String password,
  }) async =>
      (await _post('/invites/$token/accept', {
        'name': name,
        'email': email,
        'password': password,
      })) as Map<String, dynamic>;

  // ── Host info ─────────────────────────────────────────────────────────────

  /// Local-only: ask the running host server for its current tunnel state.
  Future<Map<String, dynamic>> getTunnelInfo() async =>
      (await _get('/host/tunnel')) as Map<String, dynamic>;

  // ── Projects ──────────────────────────────────────────────────────────────

  /// List all projects the current user belongs to.
  Future<List<dynamic>> getProjects() async =>
      (await _get('/projects')) as List<dynamic>;

  /// Create a new project named [name].
  Future<Map<String, dynamic>> createProject(String name) async =>
      (await _post('/projects', {'name': name}))
          as Map<String, dynamic>;

  /// List the members of [projectId].
  Future<List<dynamic>> getProjectMembers(String projectId) async =>
      (await _get('/projects/$projectId/members')) as List<dynamic>;

  /// Invite a user to [projectId] by [email] or [username].
  ///
  /// Exactly one of [email] or [username] must be non-null.
  Future<Map<String, dynamic>> inviteMember({
    required String projectId,
    String? email,
    String? username,
    String role = 'member',
  }) async {
    assert(
      email != null || username != null,
      'Provide email or username',
    );
    return (await _post('/projects/$projectId/members', {
      if (email != null) 'email': email,
      if (username != null) 'username': username,
      'role': role,
    })) as Map<String, dynamic>;
  }

  /// Change a member's role inside [projectId].
  Future<void> updateMemberRole({
    required String projectId,
    required String userId,
    required String role,
  }) async {
    await _patch('/projects/$projectId/members/$userId', {'role': role});
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTasks(String projectId) async =>
      (await _get('/projects/$projectId/tasks')) as List<dynamic>;

  Future<Map<String, dynamic>> createTask({
    required String projectId,
    required String title,
    int? deadline,
    String? assigneeId,
  }) async =>
      (await _post('/projects/$projectId/tasks', {
        'title': title,
        if (deadline != null) 'deadline': deadline,
        if (assigneeId != null) 'assignee_id': assigneeId,
      })) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateTask({
    required String projectId,
    required String taskId,
    String? title,
    String? description,
    int? deadline,
    bool clearDeadline = false,
    String? assigneeId,
    bool clearAssignee = false,
    String? status,
    String? priority,
    int? updatedAt,
  }) async =>
      (await _patch('/projects/$projectId/tasks/$taskId', {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (clearDeadline) 'deadline': null,
        if (!clearDeadline && deadline != null) 'deadline': deadline,
        if (clearAssignee) 'assignee_id': null,
        if (!clearAssignee && assigneeId != null) 'assignee_id': assigneeId,
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (updatedAt != null) 'updated_at': updatedAt,
      })) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateProject(
    String projectId, {
    String? name,
    String? description,
  }) async =>
      (await _patch('/projects/$projectId', {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
      })) as Map<String, dynamic>;

  Future<void> deleteTask({
    required String projectId,
    required String taskId,
  }) async =>
      _delete('/projects/$projectId/tasks/$taskId');

  // ── Notes ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getNote(String projectId) async =>
      (await _get('/projects/$projectId/notes')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> updateNote(
    String projectId,
    String content,
  ) async =>
      (await _patch('/projects/$projectId/notes', {'content': content}))
          as Map<String, dynamic>;

  // ── Messages ──────────────────────────────────────────────────────────────

  Future<List<dynamic>> getConversations() async =>
      (await _get('/messages/conversations')) as List<dynamic>;

  Future<List<dynamic>> getDmUsers() async =>
      (await _get('/messages/users')) as List<dynamic>;

  Future<List<dynamic>> getMessages(String partnerId) async =>
      (await _get('/messages/$partnerId')) as List<dynamic>;

  Future<Map<String, dynamic>> sendMessage(
    String partnerId,
    String content,
  ) async =>
      (await _post('/messages/$partnerId', {'content': content}))
          as Map<String, dynamic>;
}

/// Provides the [ApiClient] singleton.
final apiClientProvider = Provider<ApiClient>(
  (_) => ApiClient.instance,
);
