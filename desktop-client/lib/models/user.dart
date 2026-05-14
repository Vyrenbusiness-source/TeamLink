// GENERATED — do not edit by hand. Run: node shared-models/generate.js
// ignore_for_file: lines_longer_than_80_chars, public_member_api_docs

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    createdAt: json['created_at'] as int?,
  );

  final String id;
  final String name;
  final String email;
  final int? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt,
  };
}
