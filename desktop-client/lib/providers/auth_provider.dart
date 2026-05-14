import 'package:desktop_client/features/projects/project_providers.dart';
import 'package:desktop_client/models/user.dart';
import 'package:desktop_client/services/api_client.dart';
import 'package:desktop_client/services/ws_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the currently authenticated [User].
///
/// Holds `null` when no user is logged in.
class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final api = ref.read(apiClientProvider);
    await api.initFromStorage();
    try {
      final data = await api.getMe();
      return User.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 401) return null;
      rethrow;
    }
  }

  /// Authenticate with [email] and [password].
  Future<void> login(String email, String password) async {
    final previous = state;
    state = const AsyncLoading();
    try {
      final data = await ref.read(apiClientProvider).login(
        email: email,
        password: password,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AsyncData(user);
      WsClient.instance.joinUser(user.id);
      _refreshAllCaches();
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// Register a new account and sign in immediately.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final previous = state;
    state = const AsyncLoading();
    try {
      final data = await ref.read(apiClientProvider).register(
        name: name,
        email: email,
        password: password,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      state = AsyncData(user);
      WsClient.instance.joinUser(user.id);
      _refreshAllCaches();
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  /// End the current session and drop cached project/task/dm state.
  Future<void> logout() async {
    try {
      await ref.read(apiClientProvider).logout();
    } catch (_) {
      // Even if the server is unreachable, drop the local state.
    }
    ref.read(apiClientProvider).clearSession();
    WsClient.instance.leave();
    state = const AsyncData(null);
    _refreshAllCaches();
  }

  void _refreshAllCaches() {
    // Invalidate every list/detail provider that depends on user identity.
    // Family-scoped providers (membersProvider, tasksProvider, etc.) are
    // re-fetched lazily the next time a widget subscribes — we just need to
    // make sure top-level lists are not served stale.
    ref.invalidate(projectsProvider);
    ref.invalidate(allTasksProvider);
  }
}

/// Provides the current [User], or `null` when unauthenticated.
final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);
