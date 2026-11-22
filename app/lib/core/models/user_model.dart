enum UserRole {
  superAdmin('SUPER_ADMIN', 'Super Admin'),
  adminGudang('ADMIN_GUDANG', 'Admin Gudang'),
  petugasLapangan('PETUGAS_LAPANGAN', 'Petugas Lapangan'),
  viewer('VIEWER', 'Management Viewer');

  const UserRole(this.apiValue, this.displayLabel);
  final String apiValue;
  final String displayLabel;

  static UserRole fromApi(String raw) {
    return UserRole.values.firstWhere(
      (r) => r.apiValue == raw,
      orElse: () => UserRole.viewer,
    );
  }
}

class LocationRef {
  const LocationRef({
    required this.id,
    required this.code,
    required this.name,
    required this.locationType,
  });

  final int id;
  final String code;
  final String name;
  final String locationType;

  factory LocationRef.fromJson(Map<String, dynamic> json) {
    return LocationRef(
      id: (json['id'] as num).toInt(),
      code: json['code'] as String,
      name: json['name'] as String,
      locationType: (json['locationType'] as String?) ?? 'WAREHOUSE',
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.mustChangePassword,
    this.assignedLocation,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool mustChangePassword;
  final LocationRef? assignedLocation;

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get isViewer => role == UserRole.viewer;

  /// Penyesuaian visibilitas tombol UI mengikuti RBAC Read Global, Write Local (SRS-CAP-003).
  /// Penegakan keamanan sejati tetap diverifikasi server-side.
  bool canWriteLocation(int targetLocationId, {bool allowFieldTech = true}) {
    if (role == UserRole.superAdmin) return true;
    if (role == UserRole.viewer) return false;
    if (role == UserRole.petugasLapangan && !allowFieldTech) return false;
    return assignedLocation?.id == targetLocationId;
  }

  UserProfile copyWith({bool? mustChangePassword}) {
    return UserProfile(
      id: id,
      username: username,
      fullName: fullName,
      role: role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      assignedLocation: assignedLocation,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      fullName: json['fullName'] as String,
      role: UserRole.fromApi(json['role'] as String),
      mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
      assignedLocation: json['assignedLocation'] != null
          ? LocationRef.fromJson(json['assignedLocation'] as Map<String, dynamic>)
          : null,
    );
  }
}
