enum AppUserAuthProvider {
  local('local', '本地用户'),
  wechat('wechat', '微信');

  const AppUserAuthProvider(this.value, this.label);

  final String value;
  final String label;

  static AppUserAuthProvider fromValue(String value) {
    return AppUserAuthProvider.values.firstWhere(
      (item) => item.value == value,
      orElse: () => AppUserAuthProvider.local,
    );
  }
}

enum UserRole {
  admin('admin', '管理员'),
  member('member', '普通用户');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (item) => item.value == value,
      orElse: () => UserRole.member,
    );
  }
}

class UserWorkspace {
  const UserWorkspace({required this.userId, required this.deviceId});

  const UserWorkspace.local()
    : userId = 'local_user',
      deviceId = 'local_device';

  final String userId;
  final String deviceId;

  String get workspaceId => userId;
}

class WechatAuthIdentity {
  const WechatAuthIdentity({
    required this.openId,
    required this.unionId,
    required this.displayName,
    this.avatarUrl,
    this.isMock = false,
  });

  final String openId;
  final String unionId;
  final String displayName;
  final String? avatarUrl;
  final bool isMock;
}
