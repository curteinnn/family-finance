class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.familyId,
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String? familyId;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? 'Pengguna',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    familyId: json['familyId']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role,
    if (familyId != null) 'familyId': familyId,
  };
}
