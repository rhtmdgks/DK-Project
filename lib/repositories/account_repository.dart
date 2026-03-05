import 'dart:async';

import 'package:myapp/core/supabase_client.dart';

/// 계정 삭제 등 사용자 계정 관련 서버 연동.
class AccountRepository {
  AccountRepository();

  static final AccountRepository instance = AccountRepository();

  /// 현재 로그인한 사용자의 계정을 영구 삭제한다.
  ///
  /// 서버(Supabase)에는 `delete_user_account()` RPC가 정의되어 있다고 가정한다.
  /// - auth.users, profiles, 알림 토큰, UGC 비식별화/삭제 등은 서버에서 처리한다.
  Future<void> deleteCurrentAccount() async {
    try {
      await supabase
          .rpc(
            'delete_user_account',
          )
          .timeout(const Duration(seconds: 20), onTimeout: () {
        throw TimeoutException('계정 삭제 요청이 시간 초과되었습니다.');
      });
    } catch (e) {
      // 상위에서 사용자에게 표시할 수 있도록 래핑
      throw Exception('계정 삭제에 실패했습니다: $e');
    }
  }
}

