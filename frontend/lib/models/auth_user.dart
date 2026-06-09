/// The signed-in account plus its linked Person (from /auth/login/ and /auth/me/).
class AuthUser {
  final int id;
  final String username;
  final int? personId;
  final String? personName;

  AuthUser({
    required this.id,
    required this.username,
    required this.personId,
    required this.personName,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        username: json['username'] as String? ?? '',
        personId: json['person_id'] as int?,
        personName: json['person_name'] as String?,
      );
}
