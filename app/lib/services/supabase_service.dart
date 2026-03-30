import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';

final _client = Supabase.instance.client;

class SupabaseService {
  // ── Auth ──────────────────────────────────────────────
  static User? get currentUser => _client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  static Future<AuthResponse> signUp(String email, String password, String nickname) async {
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.user != null) {
      await _client.from('user_profiles').insert({
        'id': res.user!.id,
        'nickname': nickname,
      });
    }
    return res;
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

  static Future<AppProgram?> fetchProgram(int id) async {
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
    final res = await _client.from('cases').insert({
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
    }).select('id').single();
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
    final res = await _client.from('posts').insert({
      'author_id': currentUser!.id,
      'title': title,
      'type': type,
      'content': content,
      'tags': tags,
    }).select('id').single();
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
