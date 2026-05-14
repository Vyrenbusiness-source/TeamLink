import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_state.freezed.dart';

/// Represents the current offline-sync state of the desktop client.
///
/// Transitions: offline → syncing → online (or → error on failure).
@freezed
sealed class SyncState with _$SyncState {
  const factory SyncState.offline() = _Offline;
  const factory SyncState.syncing() = _Syncing;
  const factory SyncState.online() = _Online;
  const factory SyncState.error(String message) = _Error;
}
