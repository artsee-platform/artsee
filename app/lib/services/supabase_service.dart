import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

final _client = Supabase.instance.client;

class SupabaseService {
  // ── Auth ──────────────────────────────────────────────
  static User? get currentUser => _client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// 注册方法已废弃，请使用 BackendApiService.signup()
  /// 该方法通过 Next.js API 统一处理 Auth 和 user_profiles 创建
  @Deprecated('Use BackendApiService.signup() instead')
  static Future<AuthResponse> signUp(
      String email, String password, String nickname) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'nickname': nickname},
    );
    return res;
  }

  /// 完成冷启动：感兴趣的艺术领域
  static Future<void> completeInterestOnboarding(List<String> topicIds) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('user_profiles').upsert({
        'id': currentUser!.id,
        'interested_categories': topicIds,
        'has_completed_onboarding': true,
      }, onConflict: 'id');
    } catch (e) {
      // 若数据库尚未添加对应列，忽略 PGRST204 错误
      debugPrint('completeInterestOnboarding skipped: $e');
    }
  }

  static Future<void> updateAvatarUrl(String publicUrl) async {
    if (!isLoggedIn) return;
    await _client.from('user_profiles').update({
      'avatar_url': publicUrl,
    }).eq('id', currentUser!.id);
  }

  /// 更新个人资料（昵称、简介、所在地等）
  static Future<void> updateProfileFields({
    String? nickname,
    String? bio,
    String? location,
  }) async {
    if (!isLoggedIn) return;
    final map = <String, dynamic>{};
    if (nickname != null) map['nickname'] = nickname;
    if (bio != null) map['bio'] = bio;
    if (location != null) map['location'] = location;
    if (map.isEmpty) return;
    await _client.from('user_profiles').update(map).eq('id', currentUser!.id);
  }

  static Future<void> signOut() => _client.auth.signOut();

  // ── Home Feed ─────────────────────────────────────────
  static Future<List<AppCase>> fetchFeedCases() async {
    final data = await _client
        .from('cases')
        .select('*, user_profiles(nickname)')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List).map((e) => AppCase.fromJson(e)).toList();
  }

  static Future<List<AppPost>> fetchFeedPosts() async {
    final data = await _client
        .from('posts')
        .select('*, user_profiles(nickname)')
        .eq('status', 'published')
        .order('created_at', ascending: false)
        .limit(10);
    return (data as List).map((e) => AppPost.fromJson(e)).toList();
  }

  // ── Explore ───────────────────────────────────────────
  static Future<List<AppProgram>> fetchPrograms() async {
    final data = await _client
        .from('programs')
        .select('*, schools(*), program_admissions(*), program_fees(*)')
        .eq('status', 'active')
        .order('id');
    return (data as List).map((e) => AppProgram.fromJson(e)).toList();
  }

  static Future<AppProgram?> fetchProgram(String id) async {
    final data = await _client
        .from('programs')
        .select('*, schools(*), program_admissions(*), program_fees(*)')
        .eq('id', id)
        .single();
    return AppProgram.fromJson(data);
  }

  // ── Cases ─────────────────────────────────────────────
  static Future<List<AppCase>> fetchCases({String? result}) async {
    var query = _client
        .from('cases')
        .select('*, user_profiles(nickname)')
        .eq('status', 'published');
    if (result != null) query = query.eq('result', result);
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => AppCase.fromJson(e)).toList();
  }

  static Future<AppCase?> fetchCase(String id) async {
    final data = await _client
        .from('cases')
        .select('*, user_profiles(nickname)')
        .eq('id', id)
        .single();
    return AppCase.fromJson(data);
  }

  static Future<String?> createCase({
    required String title,
    required String targetSchool,
    required String targetProgram,
    required String result,
    required String content,
    String? undergrad,
    String? gpa,
    String? excerpt,
    String? year,
    bool isAnonymous = false,
    List<String> tags = const [],
  }) async {
    if (!isLoggedIn) return null;
    final res = await _client
        .from('cases')
        .insert({
          'author_id': currentUser!.id,
          'title': title,
          'target_school': targetSchool,
          'target_program': targetProgram,
          'result': result,
          'content': content,
          'undergrad': undergrad,
          'gpa': gpa,
          'excerpt': excerpt,
          'year': year,
          'is_anonymous': isAnonymous,
          'tags': tags,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // ── Forum ─────────────────────────────────────────────
  static Future<List<AppPost>> fetchPosts({String? type}) async {
    var query = _client
        .from('posts')
        .select('*, user_profiles(nickname)')
        .eq('status', 'published');
    if (type != null) query = query.eq('type', type);
    final data = await query.order('created_at', ascending: false);
    return (data as List).map((e) => AppPost.fromJson(e)).toList();
  }

  static Future<AppPost?> fetchPost(String id) async {
    final data = await _client
        .from('posts')
        .select('*, user_profiles(nickname)')
        .eq('id', id)
        .single();
    return AppPost.fromJson(data);
  }

  static Future<List<AppReply>> fetchReplies(String postId) async {
    final data = await _client
        .from('post_replies')
        .select('*, user_profiles(nickname)')
        .eq('post_id', postId)
        .order('created_at');
    return (data as List).map((e) => AppReply.fromJson(e)).toList();
  }

  static Future<bool> createReply(String postId, String content) async {
    if (!isLoggedIn) return false;
    await _client.from('post_replies').insert({
      'post_id': postId,
      'author_id': currentUser!.id,
      'content': content,
    });
    return true;
  }

  static Future<String?> createPost({
    required String title,
    required String type,
    required String content,
    List<String> tags = const [],
  }) async {
    if (!isLoggedIn) return null;
    final res = await _client
        .from('posts')
        .insert({
          'author_id': currentUser!.id,
          'title': title,
          'type': type,
          'content': content,
          'tags': tags,
        })
        .select('id')
        .single();
    return res['id'] as String;
  }

  // ── Profile ───────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchProfile() async {
    if (!isLoggedIn) return null;
    final data = await _client
        .from('user_profiles')
        .select('*')
        .eq('id', currentUser!.id)
        .maybeSingle();
    return data;
  }

  static Future<List<Map<String, dynamic>>> fetchAiConversations() async {
    if (!isLoggedIn) return [];
    try {
      final data = await _client
          .from('ai_conversations')
          .select('*, ai_messages(*)')
          .eq('user_id', currentUser!.id)
          .order('updated_at', ascending: false)
          .limit(20);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('fetchAiConversations skipped: $e');
      return [];
    }
  }

  static Future<void> saveAiConversation({
    required String id,
    required String title,
    required List<Map<String, dynamic>> messages,
  }) async {
    if (!isLoggedIn) return;
    try {
      await _client.from('ai_conversations').upsert({
        'id': id,
        'user_id': currentUser!.id,
        'title': title,
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _client.from('ai_messages').delete().eq('conversation_id', id);
      if (messages.isEmpty) return;
      await _client.from('ai_messages').insert(
            messages.asMap().entries.map((entry) {
              final value = Map<String, dynamic>.from(entry.value);
              return {
                'conversation_id': id,
                'user_id': currentUser!.id,
                'role': value['role'],
                'content': value['content'],
                'metadata': value['metadata'] ?? <String, dynamic>{},
                'position': entry.key,
              };
            }).toList(),
          );
    } catch (e) {
      debugPrint('saveAiConversation skipped: $e');
    }
  }

  static Future<List<AppCase>> fetchMyCases() async {
    if (!isLoggedIn) return [];
    final data = await _client
        .from('cases')
        .select('*, user_profiles(nickname)')
        .eq('author_id', currentUser!.id)
        .order('created_at', ascending: false);
    return (data as List).map((e) => AppCase.fromJson(e)).toList();
  }
}
