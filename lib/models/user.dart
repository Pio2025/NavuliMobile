import 'child_summary.dart';

class NavuliUser {
  final int userId;
  final String name;
  final String email;
  final String gender;
  final String photo;
  final int roleId;
  final String? roleName;
  final int roleCatId;
  final String roleCatName;
  final int schId;
  final Set<String> permissions;
  final bool isAParent;
  final List<ChildSummary> children;

  NavuliUser({
    required this.userId,
    required this.name,
    required this.email,
    required this.gender,
    required this.photo,
    required this.roleId,
    this.roleName,
    required this.roleCatId,
    required this.roleCatName,
    required this.schId,
    this.permissions = const {},
    this.isAParent = false,
    this.children = const [],
  });

  bool hasPermission(String code) => permissions.contains(code);

  factory NavuliUser.fromJson(Map<String, dynamic> json) {
    return NavuliUser(
      userId: json['userId'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      gender: json['gender'] ?? '',
      photo: json['photo'] ?? '',
      roleId: json['roleID'] ?? 0,
      roleName: json['roleName'],
      roleCatId: json['roleCatID'] ?? 0,
      roleCatName: json['roleCatName'] ?? 'Unknown',
      schId: json['schID'] ?? 0,
      permissions: Set<String>.from(json['permissions'] ?? const []),
      isAParent: json['isAParent'] ?? false,
      children: (json['children'] as List<dynamic>? ?? [])
          .map((c) => ChildSummary.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'gender': gender,
        'photo': photo,
        'roleID': roleId,
        'roleName': roleName,
        'roleCatID': roleCatId,
        'roleCatName': roleCatName,
        'schID': schId,
        'permissions': permissions.toList(),
        'isAParent': isAParent,
        'children': children.map((c) => c.toJson()).toList(),
      };
}
