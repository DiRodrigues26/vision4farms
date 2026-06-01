class UserModel {
  final int userId;
  final String username;
  final int userStatus;
  final ProfileModel? profile;

  UserModel({
    required this.userId,
    required this.username,
    required this.userStatus,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    userId: (json['user_id'] as num?)?.toInt() ?? 0,
    username: json['username']?.toString() ?? '',
    userStatus: (json['user_status'] as num?)?.toInt() ?? 1,
    profile: json['profile'] is Map<String, dynamic>
        ? ProfileModel.fromJson(json['profile'] as Map<String, dynamic>)
        : null,
  );
}

class ProfileModel {
  final int profileId;
  final String profileName;
  final String profileEmail;
  final String? profileMobile;
  final String? profilePhone;
  final String? profilePicture;
  final String? profileNif;
  final String? profileNifap;
  final String? profileCardfit;

  ProfileModel({
    required this.profileId,
    required this.profileName,
    required this.profileEmail,
    this.profileMobile,
    this.profilePhone,
    this.profilePicture,
    this.profileNif,
    this.profileNifap,
    this.profileCardfit,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
    profileId: (json['profile_id'] as num?)?.toInt() ?? 0,
    profileName: json['profile_name']?.toString() ?? '',
    profileEmail: json['profile_email']?.toString() ?? '',
    profileMobile: json['profile_mobile']?.toString(),
    profilePhone: json['profile_phone']?.toString(),
    profilePicture: json['profile_picture']?.toString(),
    profileNif: json['profile_nif']?.toString(),
    profileNifap: json['profile_nifap']?.toString(),
    profileCardfit: json['profile_cardfit']?.toString(),
  );
}
