import 'package:myapp/core/auth/auth_state.dart';
import 'package:myapp/core/supabase_client.dart';

class BlockedProfile {
  BlockedProfile({
    required this.profileId,
    this.userId,
    this.fullName,
    this.studentId,
  });

  final String profileId;
  final String? userId;
  final String? fullName;
  final String? studentId;
}

/// 사용자 차단/해제 및 차단 목록 조회.
class UserBlockRepository {
  UserBlockRepository();

  /// 현재 사용자가 차단한 profile_id 집합.
  Future<Set<String>> fetchBlockedProfileIds() async {
    final profile = await getCurrentProfile();
    if (profile == null) return <String>{};

    final res = await supabase
        .from('user_blocks')
        .select('blocked_profile_id')
        .eq('blocker_profile_id', profile.id);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list
        .map((row) => row['blocked_profile_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  /// 현재 사용자가 차단한 user_id 집합 (프로필 조인 기준).
  Future<Set<String>> fetchBlockedUserIds() async {
    final profile = await getCurrentProfile();
    if (profile == null) return <String>{};

    final res = await supabase
        .from('user_blocks')
        .select(
          'blocked_profile_id, profiles!user_blocks_blocked_profile_id_fkey(user_id)',
        )
        .eq('blocker_profile_id', profile.id);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list
        .map((row) {
          final profileRow = row['profiles'] as Map<String, dynamic>?;
          return profileRow?['user_id'] as String?;
        })
        .where((id) => id != null && id.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  /// 차단된 사용자 목록과 프로필 정보.
  Future<List<BlockedProfile>> fetchBlockedProfiles() async {
    final profile = await getCurrentProfile();
    if (profile == null) return const [];

    final res = await supabase
        .from('user_blocks')
        .select(
          'blocked_profile_id, profiles!user_blocks_blocked_profile_id_fkey(full_name, student_id, user_id)',
        )
        .eq('blocker_profile_id', profile.id);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map((row) {
      final blockedId = row['blocked_profile_id'] as String?;
      final profileRow = row['profiles'] as Map<String, dynamic>?;
      return BlockedProfile(
        profileId: blockedId ?? '',
        userId: profileRow?['user_id'] as String?,
        fullName: profileRow?['full_name'] as String?,
        studentId: profileRow?['student_id'] as String?,
      );
    }).where((b) => b.profileId.isNotEmpty).toList();
  }

  /// 대상 프로필을 차단한다.
  Future<void> blockProfile(String targetProfileId) async {
    final profile = await getCurrentProfile();
    if (profile == null) {
      throw Exception('로그인 정보가 없어 사용자를 차단할 수 없습니다.');
    }

    await supabase.from('user_blocks').insert({
      'blocker_profile_id': profile.id,
      'blocked_profile_id': targetProfileId,
    });
  }

  /// user_id 기준으로 프로필을 조회해 차단한다.
  Future<void> blockByUserId(String userId) async {
    final res = await supabase
        .from('profiles')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    final profileId = (res?['id'] as String?) ?? '';
    if (profileId.isEmpty) {
      throw Exception('차단할 사용자의 프로필 정보를 찾을 수 없습니다.');
    }
    await blockProfile(profileId);
  }

  /// 대상 프로필 차단을 해제한다.
  Future<void> unblockProfile(String targetProfileId) async {
    final profile = await getCurrentProfile();
    if (profile == null) {
      throw Exception('로그인 정보가 없어 차단을 해제할 수 없습니다.');
    }

    await supabase
        .from('user_blocks')
        .delete()
        .eq('blocker_profile_id', profile.id)
        .eq('blocked_profile_id', targetProfileId);
  }
}

