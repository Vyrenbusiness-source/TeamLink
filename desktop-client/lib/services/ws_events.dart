// ignore_for_file: public_member_api_docs

abstract final class WsEvent {
  // Client → Server
  static const String join = 'join';
  static const String leave = 'leave';
  static const String ping = 'ping';

  // Server → Client
  static const String pong = 'pong';
  static const String welcome = 'welcome';
  static const String error = 'error';

  // Project broadcast (Server → Client)
  static const String taskCreated = 'task_created';
  static const String taskUpdated = 'task_updated';
  static const String taskDeleted = 'task_deleted';
  static const String projectUpdated = 'project_updated';
  static const String projectDeleted = 'project_deleted';
  static const String memberAdded = 'member_added';
  static const String memberUpdated = 'member_updated';
  static const String memberRemoved = 'member_removed';
  static const String noteUpdated = 'note_updated';
  static const String messageCreated = 'message_created';
}
