// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    senderId: json['sender_id'] as String,
    recipientId: json['recipient_id'] as String,
    content: json['content'] as String,
    createdAt: json['created_at'] as int?,
  );

  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final int? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': content,
      'created_at': createdAt,
  };
}
