import 'package:baiju_app/features/user/domain/user_models.dart';

abstract class WechatAuthGateway {
  Future<WechatAuthIdentity> signIn();
}

class MockWechatAuthGateway implements WechatAuthGateway {
  const MockWechatAuthGateway();

  @override
  Future<WechatAuthIdentity> signIn() async {
    return const WechatAuthIdentity(
      openId: 'mock-wechat-open-id',
      unionId: 'mock-wechat-union-id',
      displayName: '微信用户',
      avatarUrl: null,
      isMock: true,
    );
  }
}
