// ignore_for_file: public_member_api_docs

import 'package:desktop_client/services/ws_client.dart';
import 'package:desktop_client/shared/models/sync_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the current WebSocket connection state as a [SyncState] stream.
///
/// Widgets can watch this to show online/offline/syncing indicators.
final syncStateProvider = StreamProvider<SyncState>((ref) {
  return ref.watch(wsClientProvider).connectionState;
});
