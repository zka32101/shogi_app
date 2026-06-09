// lib/models/user_profile.dart

class UserProfile {
  final String uid;
  final String username;
  final int rating;
  final int reportCount;
  final bool isBanned;
  final DateTime? bannedAt;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.username,
    this.rating = 1500,
    this.reportCount = 0,
    this.isBanned = false,
    this.bannedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'username': username,
      'rating': rating,
      'report_count': reportCount,
      'is_banned': isBanned,
      'banned_at': bannedAt,
      'created_at': createdAt,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      username: json['username'] as String,
      rating: json['rating'] as int? ?? 1500,
      reportCount: json['report_count'] as int? ?? 0,
      isBanned: json['is_banned'] as bool? ?? false,
      bannedAt: json['banned_at'] != null
          ? DateTime.parse(json['banned_at'].toString())
          : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
}
