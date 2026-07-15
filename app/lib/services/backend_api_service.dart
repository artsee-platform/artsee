import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import 'local_school_csv_service.dart';

class ApiException implements Exception {
  final int code;
  final String message;
  final String? requestId;

  ApiException({required this.code, required this.message, this.requestId});

  @override
  String toString() => 'ApiException($code): $message';
}

/// 通过 Next.js（`web/`）访问 Supabase 中的业务数据，与 Flutter 直连并存时可逐步迁移。
class BackendApiService {
  BackendApiService._();

  static Uri _api(String path, [Map<String, String>? query]) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
    final p = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$p').replace(queryParameters: query);
  }

  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };
    if (withAuth) {
      final t = Supabase.instance.client.auth.currentSession?.accessToken;
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final h = <String, String>{};
    final t = Supabase.instance.client.auth.currentSession?.accessToken;
    if (t != null) h['Authorization'] = 'Bearer $t';
    return h;
  }

  static Map<String, dynamic> _decodeBody(http.Response r) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(r.body) as Map<String, dynamic>;
    } on FormatException {
      final preview = r.body.replaceAll(RegExp(r'\s+'), ' ').trim();
      throw ApiException(
        code: r.statusCode,
        message:
            '后端返回非 JSON：${preview.length > 120 ? '${preview.substring(0, 120)}...' : preview}',
      );
    }
    final rawCode = decoded['code'];
    final code = rawCode is int
        ? rawCode
        : int.tryParse(rawCode?.toString() ?? '') ?? r.statusCode;
    final message =
        (decoded['message'] is String ? decoded['message'] as String? : null) ??
            (decoded['error'] is String ? decoded['error'] as String? : null);

    if (code == 401) {
      throw ApiException(code: code, message: message ?? '未授权，请重新登录');
    }
    if ((r.statusCode < 200 || r.statusCode >= 300) ||
        decoded['success'] == false) {
      throw ApiException(
        code: code,
        message: message ?? '接口请求失败',
        requestId: decoded['requestId'] as String?,
      );
    }
    return decoded;
  }

  static bool _refreshing = false;

  static Future<Map<String, dynamic>> _requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool withAuth = false,
  }) async {
    final uri = _api(path, query);
    var headers = await _headers(withAuth: withAuth);
    final payload = body == null ? null : jsonEncode(body);

    http.Response r;
    try {
      r = switch (method) {
        'GET' => await http.get(uri, headers: headers),
        'POST' => await http.post(uri, headers: headers, body: payload),
        'PUT' => await http.put(uri, headers: headers, body: payload),
        'PATCH' => await http.patch(uri, headers: headers, body: payload),
        'DELETE' => await http.delete(uri, headers: headers, body: payload),
        _ => throw ArgumentError('Unsupported method $method'),
      };
      return _decodeBody(r);
    } on ApiException catch (e) {
      if (e.code == 401 && withAuth && !_refreshing) {
        _refreshing = true;
        try {
          final refreshed =
              await Supabase.instance.client.auth.refreshSession();
          if (refreshed.session != null) {
            headers = await _headers(withAuth: withAuth);
            r = switch (method) {
              'GET' => await http.get(uri, headers: headers),
              'POST' => await http.post(uri, headers: headers, body: payload),
              'PUT' => await http.put(uri, headers: headers, body: payload),
              'PATCH' => await http.patch(uri, headers: headers, body: payload),
              'DELETE' =>
                await http.delete(uri, headers: headers, body: payload),
              _ => throw ArgumentError('Unsupported method $method'),
            };
            return _decodeBody(r);
          }
        } finally {
          _refreshing = false;
        }
      }
      rethrow;
    }
  }

  static Map<String, String> _params({
    int? limit,
    int? offset,
    Map<String, String?> extra = const {},
  }) {
    final params = <String, String>{};
    if (limit != null) params['limit'] = '$limit';
    if (offset != null) params['offset'] = '$offset';
    for (final entry in extra.entries) {
      final value = entry.value;
      if (value != null && value.isNotEmpty) params[entry.key] = value;
    }
    return params;
  }

  static ({List<Map<String, dynamic>> data, int? count, int limit, int offset})
      _paginated(
    Map<String, dynamic> decoded, {
    int limit = 20,
    int offset = 0,
  }) {
    final pagination = decoded['pagination'] as Map<String, dynamic>?;
    return (
      data: (decoded['data'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>(),
      count: decoded['count'] as int?,
      limit: pagination?['limit'] as int? ?? limit,
      offset: pagination?['offset'] as int? ?? offset,
    );
  }

  static Future<List<AppCase>> fetchCases({
    int limit = 20,
    int offset = 0,
    String? result,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (result != null && result.isNotEmpty) params['result'] = result;
    final r = await http.get(_api('/api/v1/cases', params),
        headers: await _headers());
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'cases ${r.statusCode}');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCase.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AppCase?> fetchCaseDetail(String id) async {
    final r = await http.get(
      _api('/api/v1/cases/$id'),
      headers: await _headers(),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'case ${r.statusCode}');
    }
    return AppCase.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<List<AppCommunityPost>> fetchCommunityPosts({
    int limit = 20,
    int offset = 0,
    String? kind,
  }) async {
    final r = await http.get(
      _api('/api/v1/community/posts', {
        'limit': '$limit',
        'offset': '$offset',
        if (kind != null) 'kind': kind,
      }),
      headers: await _headers(withAuth: true),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'community ${r.statusCode}');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AppCommunityPost>> fetchPlazaPosts({
    int limit = 20,
    int offset = 0,
    String? kind,
    String? group,
    String? source,
    String sort = 'latest',
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/plaza/feed',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'kind': kind,
          'group': group,
          'source': source,
          'sort': sort,
        },
      ),
    );
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AppCommunityPost?> fetchPlazaPost(String id) async {
    try {
      final decoded = await _requestJson(
        'GET',
        '/api/v1/plaza/posts/$id',
        withAuth: true,
      );
      return AppCommunityPost.fromJson(
        decoded['data'] as Map<String, dynamic>,
      );
    } on Exception catch (e) {
      if (e.toString().contains('未找到')) return null;
      rethrow;
    }
  }

  static Future<List<AppCommunityPost>> fetchSavedCommunityPosts({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/saved-community-posts',
      withAuth: true,
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCommunityPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<AppCommunityHotTopic>> fetchCommunityHotTopics({
    int limit = 10,
    int offset = 0,
    String? category,
    bool? pinned,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/community/hot-topics',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'category': category,
          if (pinned != null) 'pinned': pinned ? 'true' : 'false',
        },
      ),
    );
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCommunityHotTopic.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<({bool liked, int likeCount})> likeHotTopicAnswer({
    required String topicId,
    required int answerIndex,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/hot-topics/$topicId/answers/$answerIndex/like',
      withAuth: true,
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      liked: data['liked'] as bool? ?? true,
      likeCount: data['like_count'] as int? ?? 0,
    );
  }

  static Future<({bool liked, int likeCount})> unlikeHotTopicAnswer({
    required String topicId,
    required int answerIndex,
  }) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/community/hot-topics/$topicId/answers/$answerIndex/like',
      withAuth: true,
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: data['like_count'] as int? ?? 0,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchHotTopicAnswerComments({
    required String topicId,
    required int answerIndex,
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/community/hot-topics/$topicId/answers/$answerIndex/comments',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  static Future<Map<String, dynamic>> createHotTopicAnswerComment({
    required String topicId,
    required int answerIndex,
    required String body,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/hot-topics/$topicId/answers/$answerIndex/comments',
      withAuth: true,
      body: {'body': body},
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return {
      ...data,
      if (decoded['comment_count'] != null)
        'comment_count': decoded['comment_count'],
    };
  }

  static Future<AppCommunityPost?> fetchCommunityPost(String id) async {
    final r = await http.get(
      _api('/api/v1/community/posts/$id'),
      headers: await _headers(withAuth: true),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'community post ${r.statusCode}');
    }
    return AppCommunityPost.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<({bool liked, int likeCount})> likeCommunityPost(
      String id) async {
    final r = await http.post(
      _api('/api/v1/community/posts/$id/like'),
      headers: await _headers(withAuth: true),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? '点赞失败 ${r.statusCode}');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      liked: data['liked'] as bool? ?? true,
      likeCount: data['like_count'] as int? ?? 0,
    );
  }

  static Future<({bool liked, int likeCount})> unlikeCommunityPost(
      String id) async {
    final r = await http.delete(
      _api('/api/v1/community/posts/$id/like'),
      headers: await _headers(withAuth: true),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? '取消点赞失败 ${r.statusCode}');
    }
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      liked: data['liked'] as bool? ?? false,
      likeCount: data['like_count'] as int? ?? 0,
    );
  }

  static Future<({bool saved, int saveCount})> saveCommunityPost(
      String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/posts/$id/save',
      withAuth: true,
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      saved: data['saved'] as bool? ?? true,
      saveCount: data['save_count'] as int? ?? 0,
    );
  }

  static Future<({bool saved, int saveCount})> unsaveCommunityPost(
      String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/community/posts/$id/save',
      withAuth: true,
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? {};
    return (
      saved: data['saved'] as bool? ?? false,
      saveCount: data['save_count'] as int? ?? 0,
    );
  }

  static Future<List<AppCommunityComment>> fetchCommunityComments(
    String postId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final r = await http.get(
      _api('/api/v1/community/posts/$postId/comments', {
        'limit': '$limit',
        'offset': '$offset',
      }),
      headers: await _headers(),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'comments ${r.statusCode}');
    }
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppCommunityComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<AppCommunityComment> createCommunityComment({
    required String postId,
    required String body,
  }) async {
    final r = await http.post(
      _api('/api/v1/community/posts/$postId/comments'),
      headers: await _headers(withAuth: true),
      body: jsonEncode({'body': body}),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 201 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? '评论失败 ${r.statusCode}');
    }
    return AppCommunityComment.fromJson(
        decoded['data'] as Map<String, dynamic>);
  }

  static Future<
      ({
        AppCommunityComment comment,
        AppCommunityComment? aiReply,
      })> createPlazaComment({
    required String postId,
    required String body,
    String? parentId,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/plaza/posts/$postId/comments',
      withAuth: true,
      body: {
        'body': body,
        if (parentId != null) 'parent_id': parentId,
        if (metadata != null) 'metadata': metadata,
      },
    );
    final rawAiReply = decoded['ai_reply'];
    return (
      comment: AppCommunityComment.fromJson(
        decoded['data'] as Map<String, dynamic>,
      ),
      aiReply: rawAiReply is Map<String, dynamic>
          ? AppCommunityComment.fromJson(rawAiReply)
          : null,
    );
  }

  static Future<List<AppProgram>> fetchPrograms(
      {int limit = 80, int offset = 0}) async {
    final r = await http.get(
      _api('/api/v1/programs', {'limit': '$limit', 'offset': '$offset'}),
      headers: await _headers(),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'programs ${r.statusCode}');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => AppProgram.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<({List<AppProgram> data, int? count, int limit, int offset})>
      fetchProgramsPaginated({
    int limit = 20,
    int offset = 0,
    String? keyword,
    String? degreeType,
    String? schoolId,
    bool? requiresPortfolio,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (degreeType != null && degreeType.isNotEmpty) {
      params['degree_type'] = degreeType;
    }
    if (schoolId != null) params['school_id'] = schoolId;
    if (requiresPortfolio != null) {
      params['requires_portfolio'] = requiresPortfolio ? 'true' : 'false';
    }

    final r = await http.get(
      _api('/api/v1/programs', params),
      headers: await _headers(),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'programs ${r.statusCode}');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    final count = body['count'] as int?;
    final pagination = body['pagination'] as Map<String, dynamic>?;
    return (
      data: list
          .map((e) => AppProgram.fromJson(e as Map<String, dynamic>))
          .toList(),
      count: count,
      limit: pagination?['limit'] as int? ?? limit,
      offset: pagination?['offset'] as int? ?? offset,
    );
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchArticles({
    int limit = 20,
    int offset = 0,
    String? category,
    String? keyword,
    bool? featured,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/articles',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'category': category,
          'keyword': keyword,
          'featured': featured == null ? null : '$featured',
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> fetchWorkbenchServiceBooking(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/service-bookings/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateWorkbenchServiceBooking({
    required String id,
    String? status,
    String? scheduledAt,
    String? notes,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/workbench/service-bookings/$id',
      body: {
        if (status != null) 'status': status,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (notes != null) 'notes': notes,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchSchools({
    int limit = 20,
    int offset = 0,
    String? keyword,
    String? country,
    String? regionTag,
    String? schoolType,
    String? advantageSubject,
    int? minRank,
    int? maxRank,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (country != null && country.isNotEmpty) params['country'] = country;
    if (regionTag != null && regionTag.isNotEmpty) {
      params['region_tag'] = regionTag;
    }
    if (schoolType != null && schoolType.isNotEmpty) {
      params['school_type'] = schoolType;
    }
    if (advantageSubject != null && advantageSubject.isNotEmpty) {
      params['advantage_subject'] = advantageSubject;
    }
    if (minRank != null) params['min_rank'] = '$minRank';
    if (maxRank != null) params['max_rank'] = '$maxRank';

    Future<
        ({
          List<Map<String, dynamic>> data,
          int? count,
          int limit,
          int offset
        })> localFallback() {
      return LocalSchoolCsvService.fetchSchools(
        limit: limit,
        offset: offset,
        keyword: keyword,
        country: country,
        regionTag: regionTag,
        schoolType: schoolType,
        advantageSubject: advantageSubject,
        minRank: minRank,
        maxRank: maxRank,
      );
    }

    if (ApiConfig.forceLocalSchoolsData) return localFallback();

    try {
      final r = await http.get(
        _api('/api/v1/schools', params),
        headers: await _headers(),
      );
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode != 200 || body['success'] != true) {
        return localFallback();
      }
      final list =
          (body['data'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (list.isEmpty && (keyword?.trim().isNotEmpty ?? false)) {
        final local = await localFallback();
        if (local.data.isNotEmpty) return local;
      }
      final count = body['count'] as int?;
      final pagination = body['pagination'] as Map<String, dynamic>?;
      return (
        data: list,
        count: count,
        limit: pagination?['limit'] as int? ?? limit,
        offset: pagination?['offset'] as int? ?? offset,
      );
    } catch (_) {
      return localFallback();
    }
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchSavedSchools({
    int limit = 50,
    int offset = 0,
  }) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      return (
        data: <Map<String, dynamic>>[],
        count: 0,
        limit: limit,
        offset: offset
      );
    }
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/saved-schools',
      query: _params(limit: limit, offset: offset),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> saveSchool(String schoolId) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/saved-schools',
      body: {'school_id': schoolId},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<void> removeSavedSchool(String schoolId) async {
    await _requestJson(
      'DELETE',
      '/api/v1/me/saved-schools/$schoolId',
      withAuth: true,
    );
  }

  static Future<Map<String, dynamic>> compareSchools({
    required List<String> schoolIds,
    List<String> dimensions = const [
      'rank',
      'location',
      'portfolio',
      'programs',
      'cost',
      'career',
    ],
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/schools/compare',
      withAuth: true,
      body: {
        'school_ids': schoolIds,
        'dimensions': dimensions,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchApplicationPlan() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/application-plan',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateApplicationPlan() async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/application-plan/generate',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateApplicationPlanTask(
    String taskId,
    String status,
  ) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/application-plan/tasks/$taskId',
      body: {'status': status},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchPortfolioTasks() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/portfolio-tasks',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generatePortfolioTasks() async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/portfolio-tasks/generate',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePortfolioTask(
    String taskId,
    String status,
  ) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/portfolio-tasks/$taskId',
      body: {'status': status},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchConsultations({
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations',
      query: _params(limit: limit, offset: offset),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchNearbyOrganizations({
    int limit = 30,
    int offset = 0,
    String? city,
    String? province,
    String? focusArea,
    String? serviceMode,
    String? schoolId,
    String? schoolName,
    double? latitude,
    double? longitude,
    String sort = 'comprehensive',
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/organizations/nearby',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'city': city?.trim(),
          'province': province?.trim(),
          'focus_area': focusArea?.trim(),
          'service_mode': serviceMode?.trim(),
          'school_id': schoolId?.trim(),
          'school_name': schoolName?.trim(),
          'latitude': latitude?.toString(),
          'longitude': longitude?.toString(),
          'sort': sort,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> fetchOrganization(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/organizations/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchMembership() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/membership',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createMembershipUpgrade({
    String plan = 'yearly',
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/membership/upgrade',
      body: {'plan': plan},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyContracts({
    int limit = 50,
    int offset = 0,
    String? status,
    String? organizationId,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/contracts',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'status': status?.trim(),
          'organization_id': organizationId?.trim(),
        },
      ),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createContractArchive({
    required String organizationId,
    String? consultationId,
    String? fileUrl,
    String? signedAt,
    String status = 'pending',
    String? notes,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/contracts',
      withAuth: true,
      body: {
        'organization_id': organizationId.trim(),
        if (consultationId != null && consultationId.trim().isNotEmpty)
          'consultation_id': consultationId.trim(),
        if (fileUrl != null && fileUrl.trim().isNotEmpty)
          'file_url': fileUrl.trim(),
        if (signedAt != null && signedAt.trim().isNotEmpty)
          'signed_at': signedAt.trim(),
        'status': status,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchWorkbenchContracts({
    int limit = 50,
    int offset = 0,
    String? status,
    String? organizationId,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/contracts',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'status': status?.trim(),
          'organization_id': organizationId?.trim(),
        },
      ),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> updateWorkbenchContractStatus({
    required String contractId,
    required String status,
    String? notes,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/workbench/contracts/${contractId.trim()}',
      withAuth: true,
      body: {
        'status': status.trim(),
        if (notes != null) 'notes': notes.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resubmitMyContentSubmission({
    required String type,
    required String id,
    String? note,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/content-submissions/$type/$id/resubmit',
      withAuth: true,
      body: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMyContentSubmission({
    required String type,
    required String id,
    required Map<String, dynamic> fields,
    String? note,
    List<String> supplementalMaterials = const [],
    bool submit = true,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/content-submissions/$type/$id',
      withAuth: true,
      body: {
        'fields': fields,
        'submit': submit,
        if (supplementalMaterials.isNotEmpty)
          'supplemental_materials': supplementalMaterials,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyServiceBookings({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/service-bookings',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'status': status},
      ),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> fetchMyServiceBooking(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/service-bookings/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createConsultation({
    required String targetType,
    String? targetId,
    required String targetName,
    required String message,
    String? source,
    String? topic,
    String? targetMajor,
    String? intake,
    String? stage,
    String? organizationId,
    String? channel,
    Map<String, dynamic>? metadata,
  }) async {
    final cleanTopic = topic?.trim();
    final cleanTargetMajor = targetMajor?.trim();
    final cleanIntake = intake?.trim();
    final cleanStage = stage?.trim();
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/consultations',
      body: {
        'target_type': targetType,
        if (targetId != null) 'target_id': targetId,
        'target_name': targetName,
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
        if (cleanTopic != null && cleanTopic.isNotEmpty) 'topic': cleanTopic,
        if (cleanTargetMajor != null && cleanTargetMajor.isNotEmpty)
          'target_major': cleanTargetMajor,
        if (cleanIntake != null && cleanIntake.isNotEmpty)
          'intake': cleanIntake,
        if (cleanStage != null && cleanStage.isNotEmpty) 'stage': cleanStage,
        if (organizationId != null && organizationId.trim().isNotEmpty)
          'organization_id': organizationId.trim(),
        if (channel != null && channel.trim().isNotEmpty)
          'channel': channel.trim(),
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
        'message': message,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchConsultation(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchConsultationMessages({
    required String consultationId,
    int limit = 100,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$consultationId/messages',
      query: _params(limit: limit, offset: offset),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>?> fetchConsultationAssessment(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$id/assessment',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>?> fetchConsultationRecommendation(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$id/recommendation',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>> fetchConsultationConversion(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$id/conversion',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  static Future<Map<String, dynamic>?> fetchConsultationReview(
      String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/consultations/$id/review',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>> reviewConsultation({
    required String consultationId,
    required int rating,
    String? body,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/consultations/$consultationId/review',
      withAuth: true,
      body: {
        'rating': rating,
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendConsultationMessage({
    required String consultationId,
    required String body,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/consultations/$consultationId/messages',
      body: {'body': body},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchWorkbenchConsultationAssessment(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/consultations/$id/assessment',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>> saveWorkbenchConsultationAssessment({
    required String id,
    String? backgroundSummary,
    String? matchLevel,
    String? riskLevel,
    String? notes,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/consultations/$id/assessment',
      body: {
        if (backgroundSummary != null) 'background_summary': backgroundSummary,
        if (matchLevel != null) 'match_level': matchLevel,
        if (riskLevel != null) 'risk_level': riskLevel,
        if (notes != null) 'notes': notes,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchWorkbenchConsultationRecommendation(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/consultations/$id/recommendation',
      withAuth: true,
    );
    final data = decoded['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  static Future<Map<String, dynamic>> saveWorkbenchConsultationRecommendation({
    required String id,
    List<Map<String, dynamic>> schoolList = const [],
    String? timeline,
    String? portfolioStrategy,
    List<Map<String, dynamic>> recommendedServices = const [],
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/consultations/$id/recommendation',
      body: {
        'school_list': schoolList,
        if (timeline != null) 'timeline': timeline,
        if (portfolioStrategy != null) 'portfolio_strategy': portfolioStrategy,
        'recommended_services': recommendedServices,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchWorkbenchConsultations({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/consultations',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'status': status},
      ),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> fetchWorkbenchConsultation(
    String id,
  ) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/consultations/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
      })> fetchWorkbenchTeam({String status = 'active'}) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/team',
      query: _params(extra: {'status': status == 'active' ? null : status}),
      withAuth: true,
    );
    final list = decoded['data'] as List<dynamic>? ?? [];
    return (
      data: list.map((e) => e as Map<String, dynamic>).toList(),
      count: decoded['count'] as int?,
    );
  }

  static Future<Map<String, dynamic>> addWorkbenchTeamMember({
    String? organizationId,
    String? email,
    String? userId,
    String role = 'advisor',
    String? displayName,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/team',
      body: {
        if (organizationId != null && organizationId.trim().isNotEmpty)
          'organization_id': organizationId.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (userId != null && userId.trim().isNotEmpty)
          'user_id': userId.trim(),
        'role': role,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateWorkbenchTeamMember({
    required String memberId,
    String? role,
    String? status,
    String? displayName,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/workbench/team/$memberId',
      body: {
        if (role != null) 'role': role,
        if (status != null) 'status': status,
        if (displayName != null) 'display_name': displayName,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
      })> fetchWorkbenchTeamInvitations() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/team-invitations',
      withAuth: true,
    );
    final list = decoded['data'] as List<dynamic>? ?? [];
    return (
      data: list.map((e) => e as Map<String, dynamic>).toList(),
      count: decoded['count'] as int?,
    );
  }

  static Future<Map<String, dynamic>> respondWorkbenchTeamInvitation({
    required String memberId,
    required String action,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/team-invitations/$memberId/respond',
      body: {'action': action},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> assignWorkbenchConsultation({
    required String id,
    String? memberId,
    String? memberUserId,
    bool clear = false,
    String? note,
  }) async {
    final body = <String, dynamic>{
      if (clear) 'member_id': null,
      if (!clear && memberId != null) 'member_id': memberId,
      if (!clear && memberUserId != null) 'member_user_id': memberUserId,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    };
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/consultations/$id/assign',
      body: body,
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateWorkbenchConsultationCollaborators({
    required String id,
    String mode = 'replace',
    List<String> memberIds = const [],
    List<String> memberUserIds = const [],
    String? note,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/workbench/consultations/$id/collaborators',
      body: {
        'mode': mode,
        'member_ids': memberIds,
        'member_user_ids': memberUserIds,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateWorkbenchConsultation({
    required String id,
    String? status,
    String? action,
    int? orderAmountTotal,
    String? orderSubject,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/workbench/consultations/$id',
      body: {
        if (status != null) 'status': status,
        if (action != null) 'action': action,
        if (orderAmountTotal != null) 'order_amount_total': orderAmountTotal,
        if (orderSubject != null && orderSubject.trim().isNotEmpty)
          'order_subject': orderSubject.trim(),
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchWorkbenchConsultationMessages({
    required String consultationId,
    int limit = 100,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/consultations/$consultationId/messages',
      query: _params(limit: limit, offset: offset),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> sendWorkbenchConsultationMessage({
    required String consultationId,
    required String body,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/workbench/consultations/$consultationId/messages',
      body: {'body': body},
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchWorkbenchServiceBookings({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/workbench/service-bookings',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'status': status},
      ),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyOrganizations({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/organizations',
      query: _params(limit: limit, offset: offset),
      withAuth: true,
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createOrganization({
    required String name,
    String? type,
    Map<String, dynamic>? metadata,
  }) async {
    final cleanType = type?.trim();
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/organizations',
      body: {
        'name': name,
        if (cleanType != null && cleanType.isNotEmpty) 'type': cleanType,
        if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateOrganizationProfile({
    required String organizationId,
    String? name,
    String? type,
    String? city,
    String? province,
    String? latitude,
    String? longitude,
    List<String>? focusAreas,
    bool? supportsOnline,
    bool? supportsOffline,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/organizations/${organizationId.trim()}',
      body: {
        if (name != null) 'name': name.trim(),
        if (type != null) 'type': type.trim(),
        if (city != null) 'city': city.trim(),
        if (province != null) 'province': province.trim(),
        if (latitude != null) 'latitude': latitude.trim(),
        if (longitude != null) 'longitude': longitude.trim(),
        if (focusAreas != null) 'focus_areas': focusAreas,
        if (supportsOnline != null) 'supports_online': supportsOnline,
        if (supportsOffline != null) 'supports_offline': supportsOffline,
        if (metadata != null) 'metadata': metadata,
      },
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createOrganizationSubscriptionUpgrade({
    required String organizationId,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/organizations/${organizationId.trim()}/subscription/upgrade',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<AppProgram?> fetchProgram(String id) async {
    final r =
        await http.get(_api('/api/v1/programs/$id'), headers: await _headers());
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) return null;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'program ${r.statusCode}');
    }
    return AppProgram.fromJson(body['data'] as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> fetchProgramDetail(String id) async {
    final r =
        await http.get(_api('/api/v1/programs/$id'), headers: await _headers());
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode == 404) throw Exception('专业未找到');
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'program ${r.statusCode}');
    }
    return body['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchSchool(String id) async {
    Future<Map<String, dynamic>?> localFallback() {
      return LocalSchoolCsvService.findSchoolById(id);
    }

    if (ApiConfig.forceLocalSchoolsData || id.startsWith('aux-')) {
      final local = await localFallback();
      if (local != null) return local;
      throw Exception('学校未找到');
    }

    try {
      final r = await http.get(
        _api('/api/v1/schools/$id'),
        headers: await _headers(),
      );
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      if (r.statusCode == 404) {
        final local = await localFallback();
        if (local != null) return local;
        throw Exception('学校未找到');
      }
      if (r.statusCode != 200 || body['success'] != true) {
        final local = await localFallback();
        if (local != null) return local;
        throw Exception(body['error'] ?? 'school ${r.statusCode}');
      }
      return body['data'] as Map<String, dynamic>;
    } catch (_) {
      final local = await localFallback();
      if (local != null) return local;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> aiSchoolConsult(String query,
      {int limitSchools = 20}) {
    return aiSchoolSearch(query, limitSchools: limitSchools);
  }

  /// 统一 AI 咨询入口：适合首页「意见 AI」和普通问答。
  static Future<Map<String, dynamic>> aiConsult(
    String query, {
    String mode = 'short',
    String? schoolId,
    Map<String, dynamic>? userProfile,
    String? persona,
    String? intent,
    Map<String, dynamic>? context,
    List<Map<String, dynamic>>? messages,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/ai/consult',
      withAuth: true,
      body: {
        'query': query,
        'mode': mode,
        if (schoolId != null) 'schoolId': schoolId,
        if (userProfile != null) 'userProfile': userProfile,
        if (persona != null) 'persona': persona,
        if (intent != null) 'intent': intent,
        if (context != null) 'context': context,
        if (messages != null) 'messages': messages,
      },
    );
    return decoded;
  }

  /// 上传图片并获取 AI 分析
  static Future<Map<String, dynamic>> uploadImageAndAnalyze({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String? conversationId,
  }) async {
    final uri = _api('/api/v1/ai/image-analyze');
    final request = http.MultipartRequest('POST', uri);

    // 添加认证头
    final authHeaders = await _authHeaders();
    request.headers.addAll(authHeaders);

    // 添加图片文件。使用 bytes 而不是 path，兼容 Flutter Web 的浏览器文件。
    final multipartFile = http.MultipartFile.fromBytes(
      'image',
      bytes,
      filename: filename,
      contentType: _mediaType(contentType),
    );
    request.files.add(multipartFile);

    // 添加对话 ID（如果有）
    if (conversationId != null) {
      request.fields['conversationId'] = conversationId;
    }

    // 发送请求
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        code: response.statusCode,
        message: response.body.isEmpty ? '图片上传失败' : response.body,
      );
    }

    return _decodeBody(response);
  }

  /// 上传音频并转换为文字
  static Future<Map<String, dynamic>> transcribeAudio({
    required dynamic file,
    String? conversationId,
  }) async {
    final uri = _api('/api/v1/ai/transcribe');
    final request = http.MultipartRequest('POST', uri);

    // 添加认证头
    final authHeaders = await _authHeaders();
    request.headers.addAll(authHeaders);

    // 添加音频文件
    final multipartFile = await http.MultipartFile.fromPath(
      'audio',
      file.path,
      contentType: MediaType('audio', 'm4a'),
    );
    request.files.add(multipartFile);

    // 添加对话 ID（如果有）
    if (conversationId != null) {
      request.fields['conversationId'] = conversationId;
    }

    // 发送请求
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        code: response.statusCode,
        message: response.body.isEmpty ? '语音识别失败' : response.body,
      );
    }

    return _decodeBody(response);
  }

  static Stream<String> streamAiChat({
    required List<Map<String, String>> messages,
    Map<String, dynamic>? context,
  }) async* {
    final request = http.Request('POST', _api('/api/v1/ai/chat'));
    request.headers.addAll(await _headers(withAuth: true));
    request.headers['Accept'] = 'text/event-stream';
    request.body = jsonEncode({
      'messages': messages,
      if (context != null) 'context': context,
    });

    final client = http.Client();
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw ApiException(
        code: response.statusCode,
        message: errorBody.isEmpty ? 'AI 对话失败' : errorBody,
      );
    }

    try {
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final raw = line.substring(6).trim();
        if (raw == '[DONE]') break;
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final text = decoded['text'] as String?;
        if (text != null && text.isNotEmpty) yield text;
      }
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> aiAnalyze(
    List<String> institutionIds,
  ) async {
    return _requestJson(
      'POST',
      '/api/v1/ai/analyze',
      withAuth: true,
      body: {'institutionIds': institutionIds},
    );
  }

  static Future<Map<String, dynamic>> aiRecord({
    required String content,
    String kind = 'pin',
    String? conversationId,
    String? messageId,
  }) async {
    return _requestJson(
      'POST',
      '/api/v1/ai/record',
      withAuth: true,
      body: {
        'content': content,
        'kind': kind,
        if (conversationId != null) 'conversationId': conversationId,
        if (messageId != null) 'messageId': messageId,
      },
    );
  }

  static Future<List<Map<String, dynamic>>> getAiConversations() async {
    final decoded =
        await _requestJson('GET', '/api/v1/ai/conversations', withAuth: true);
    final conversations = decoded['conversations'] as List<dynamic>?;
    return conversations?.cast<Map<String, dynamic>>() ?? [];
  }

  static Future<Map<String, dynamic>> createAiConversation({
    String? title,
    String? aiProfileKey,
    String? userRoleSnapshot,
    String? userTypeSnapshot,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/ai/conversations',
      withAuth: true,
      body: {
        'title': title ?? '新对话',
        if (aiProfileKey != null) 'aiProfileKey': aiProfileKey,
        if (userRoleSnapshot != null) 'userRoleSnapshot': userRoleSnapshot,
        if (userTypeSnapshot != null) 'userTypeSnapshot': userTypeSnapshot,
      },
    );
    return decoded['conversation'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getAiConversation(
      String conversationId) async {
    return _requestJson('GET', '/api/v1/ai/conversations/$conversationId',
        withAuth: true);
  }

  static Future<void> deleteAiConversation(String conversationId) async {
    await _requestJson('DELETE', '/api/v1/ai/conversations/$conversationId',
        withAuth: true);
  }

  static Future<Map<String, dynamic>> saveAiMessage({
    required String conversationId,
    required String role,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/ai/conversations/$conversationId/messages',
      withAuth: true,
      body: {
        'role': role,
        'content': content,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['message'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> searchKnowledge({
    required String query,
    String? schoolId,
    double? matchThreshold,
    int matchCount = 5,
    String? userId,
  }) async {
    return _requestJson(
      'POST',
      '/api/v1/knowledge/search',
      body: {
        'query': query,
        if (schoolId != null) 'schoolId': schoolId,
        if (matchThreshold != null) 'matchThreshold': matchThreshold,
        'matchCount': matchCount,
        if (userId != null) 'userId': userId,
      },
    );
  }

  static Future<Map<String, dynamic>> fetchKnowledgeStats() async {
    final decoded = await _requestJson('GET', '/api/v1/knowledge/stats');
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  static Future<Map<String, dynamic>> createCommunityPost({
    required String title,
    String? body,
    List<String> imageUrls = const [],
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/posts',
      withAuth: true,
      body: {
        'title': title,
        'body': body,
        'image_urls': imageUrls,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return (decoded['data'] as Map<String, dynamic>? ?? {});
  }

  static Future<Map<String, dynamic>> createPlazaPost({
    required String title,
    String? body,
    List<String> imageUrls = const [],
    String kind = 'article',
    String? group,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/plaza/posts',
      withAuth: true,
      body: {
        'title': title,
        'body': body,
        'image_urls': imageUrls,
        'kind': kind,
        if (group != null && group.trim().isNotEmpty) 'group': group.trim(),
        if (tags != null) 'tags': tags,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return (decoded['data'] as Map<String, dynamic>? ?? {});
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMarketplaceBag({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/marketplace/bag',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'status': status,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> upsertMarketplaceBagItem({
    required String listingPostId,
    String? status,
    bool? saved,
    String? message,
    String? conversationId,
    String? orderId,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/marketplace/bag',
      withAuth: true,
      body: {
        'listing_post_id': listingPostId,
        if (status != null) 'status': status,
        if (saved != null) 'saved': saved,
        if (message != null) 'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
        if (orderId != null) 'order_id': orderId,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createMarketplaceOrder({
    required String listingPostId,
    int quantity = 1,
    String? message,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/marketplace/orders',
      withAuth: true,
      body: {
        'listing_post_id': listingPostId,
        'quantity': quantity,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchCommunityCircles({
    int limit = 30,
    int offset = 0,
    String? category,
    String? keyword,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/community/circles',
      withAuth: Supabase.instance.client.auth.currentUser != null,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'category': category,
          'keyword': keyword,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createCommunityCircle(
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/circles',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> joinCommunityCircle(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/community/circles/$id/join',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchConversations({
    int limit = 30,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/conversations',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createConversation({
    required List<String> participantIds,
    String type = 'direct',
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/conversations',
      withAuth: true,
      body: {
        'participant_ids': participantIds,
        'type': type,
        if (title != null) 'title': title,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createOrganizationConversation({
    required String organizationId,
    String? title,
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/conversations',
      withAuth: true,
      body: {
        'organization_id': organizationId,
        'type': 'organization',
        if (title != null) 'title': title,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchConversationMessages({
    required String conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/conversations/$conversationId/messages',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> sendConversationMessage({
    required String conversationId,
    required String body,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/conversations/$conversationId/messages',
      withAuth: true,
      body: {
        'body': body,
        'message_type': messageType,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sendConversationAttachment({
    required String conversationId,
    required String url,
    required String messageType,
    String? filename,
    String? contentType,
    int? size,
    Map<String, dynamic>? metadata,
  }) async {
    final normalizedType = messageType == 'image' ? 'image' : 'file';
    final decoded = await _requestJson(
      'POST',
      '/api/v1/conversations/$conversationId/messages',
      withAuth: true,
      body: {
        'body': normalizedType == 'image'
            ? '[图片]'
            : '[文件]${filename?.trim().isNotEmpty == true ? ' ${filename!.trim()}' : ''}',
        'message_type': normalizedType,
        'attachment_url': url,
        if (filename != null) 'attachment_name': filename,
        if (contentType != null) 'content_type': contentType,
        if (size != null) 'size': size,
        'metadata': {
          if (metadata != null) ...metadata,
          'attachment_url': url,
          if (filename != null) 'attachment_name': filename,
          if (contentType != null) 'content_type': contentType,
          if (size != null) 'size': size,
          'provider': metadata?['provider'] ?? 'tencent_cos',
        },
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchTencentImConfig() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/im/config',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchFriends({
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/friends',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchFriendCandidates({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/friends/candidates',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  static Future<Map<String, dynamic>> addFriend({
    required String targetUserId,
    String? message,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/friends',
      withAuth: true,
      body: {
        'target_user_id': targetUserId,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createMyQrCode({
    String type = 'user',
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/qr-codes',
      withAuth: true,
      body: {
        'type': type,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> resolveQrCode(String token) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/qr-codes/$token',
      withAuth: Supabase.instance.client.auth.currentUser != null,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> performQrCodeAction({
    required String token,
    String? action,
    String? message,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/qr-codes/$token/action',
      withAuth: true,
      body: {
        if (action != null) 'action': action,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createCheckoutSession({
    required String subject,
    required int amountTotal,
    String currency = 'cny',
    String itemType = 'service',
    String? itemId,
    Map<String, dynamic>? metadata,
  }) async {
    final r = await http.post(
      _api('/api/v1/payments/checkout'),
      headers: await _headers(withAuth: true),
      body: jsonEncode({
        'subject': subject,
        'amountTotal': amountTotal,
        'currency': currency,
        'itemType': itemType,
        if (itemId != null) 'itemId': itemId,
        if (metadata != null) 'metadata': metadata,
      }),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? '创建支付订单失败 ${r.statusCode}');
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchPaymentProviders() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/payments/providers',
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitVerification({
    required String type,
    required Map<String, dynamic> materials,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/verifications',
      withAuth: true,
      body: {'type': type, 'materials': materials},
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchMyVerifications() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/verifications/me',
      withAuth: true,
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> reviewVerification({
    required String id,
    required String status,
    String? reviewNote,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/admin/verifications/$id/review',
      withAuth: true,
      body: {
        'status': status,
        if (reviewNote != null) 'review_note': reviewNote,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchEvents({
    int limit = 20,
    int offset = 0,
    String? city,
    String? type,
    bool includeInactive = false,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/events',
      withAuth: includeInactive,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'city': city,
          'type': type,
          if (includeInactive) 'include_inactive': 'true',
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>?> fetchEvent(String id) async {
    try {
      final decoded = await _requestJson('GET', '/api/v1/events/$id');
      return decoded['data'] as Map<String, dynamic>;
    } on Exception catch (e) {
      if (e.toString().contains('未找到')) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createEvent(
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/events',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateEvent(
    String id,
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/events/$id',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> archiveEvent(String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/events/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> applyEvent({
    required String eventId,
    String? applyNote,
    Map<String, dynamic>? formData,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/events/$eventId/apply',
      withAuth: true,
      body: {
        if (applyNote != null) 'apply_note': applyNote,
        if (formData != null) 'form_data': formData,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyEventApplications({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/events/applications/me',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> reviewEventApplication({
    required String id,
    required String status,
    String? reviewNote,
    String? ticketCode,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/admin/event-applications/$id/review',
      withAuth: true,
      body: {
        'status': status,
        if (reviewNote != null) 'review_note': reviewNote,
        if (ticketCode != null) 'ticket_code': ticketCode,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> checkinEvent({
    required String eventId,
    required String ticketCode,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/events/$eventId/checkin',
      withAuth: true,
      body: {'ticket_code': ticketCode},
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchOpportunities({
    int limit = 20,
    int offset = 0,
    String? keyword,
    String? city,
    String? type,
    bool includeInactive = false,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/opportunities',
      withAuth: includeInactive,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'keyword': keyword,
          'city': city,
          'type': type,
          if (includeInactive) 'include_inactive': 'true',
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>?> fetchOpportunity(String id) async {
    try {
      final decoded = await _requestJson('GET', '/api/v1/opportunities/$id');
      return decoded['data'] as Map<String, dynamic>;
    } on Exception catch (e) {
      if (e.toString().contains('未找到')) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createOpportunity(
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/opportunities',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateOpportunity(
    String id,
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/opportunities/$id',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> archiveOpportunity(String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/opportunities/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> applyOpportunity({
    required String opportunityId,
    List<String> portfolioIds = const [],
    String? proposal,
    int? quoteAmount,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/opportunities/$opportunityId/apply',
      withAuth: true,
      body: {
        'portfolio_ids': portfolioIds,
        if (proposal != null) 'proposal': proposal,
        if (quoteAmount != null) 'quote_amount': quoteAmount,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyOpportunityApplications({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/opportunity-applications/me',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> reviewOpportunityApplication({
    required String id,
    required String status,
    String? reviewNote,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/admin/opportunity-applications/$id/review',
      withAuth: true,
      body: {
        'status': status,
        if (reviewNote != null) 'review_note': reviewNote,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyProjects({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/projects/me',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> updateProjectStatus({
    required String id,
    required String status,
  }) async {
    final decoded = await _requestJson(
      'PUT',
      '/api/v1/projects/$id/status',
      withAuth: true,
      body: {'status': status},
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchProjectStatus(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/projects/$id/status',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchCreatorCenter() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/creator-center',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyContentSubmissions({
    int limit = 50,
    int offset = 0,
    String type = 'all',
    String status = 'all',
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/content-submissions',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'type': type == 'all' ? null : type,
          'status': status == 'all' ? null : status,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMentors({
    int limit = 20,
    int offset = 0,
    String? keyword,
    String? university,
    String? major,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/mentors',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'keyword': keyword,
          'university': university,
          'major': major,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> fetchMentor(String id) async {
    final decoded = await _requestJson('GET', '/api/v1/mentors/$id');
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchMyMentorApplication() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/mentor-applications',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>> submitMentorApplication(
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/mentor-applications',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyMentorServices({
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/mentor/services',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createMentorService({
    required String title,
    required int durationMinutes,
    required int priceAmount,
    String? description,
    String serviceType = 'portfolio_review',
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/mentor/services',
      withAuth: true,
      body: {
        'title': title,
        'duration_minutes': durationMinutes,
        'price_amount': priceAmount,
        'service_type': serviceType,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> bookMentorService({
    required String mentorId,
    required String serviceId,
    String? scheduledAt,
    String? availabilitySlotId,
    String? studentNote,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/mentors/$mentorId/bookings',
      withAuth: true,
      body: {
        'service_id': serviceId,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (availabilitySlotId != null)
          'availability_slot_id': availabilitySlotId,
        if (studentNote != null && studentNote.trim().isNotEmpty)
          'student_note': studentNote.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMentorAvailability({
    required String mentorId,
    int limit = 50,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/mentors/$mentorId/availability',
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyMentorAvailability({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/mentor/availability',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'status': status},
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createMentorAvailability({
    required String startsAt,
    required String endsAt,
    String timezone = 'Asia/Shanghai',
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/mentor/availability',
      withAuth: true,
      body: {
        'starts_at': startsAt,
        'ends_at': endsAt,
        'timezone': timezone,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateMentorAvailability({
    required String slotId,
    String? status,
    String? startsAt,
    String? endsAt,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/mentor/availability/$slotId',
      withAuth: true,
      body: {
        if (status != null) 'status': status,
        if (startsAt != null) 'starts_at': startsAt,
        if (endsAt != null) 'ends_at': endsAt,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyMentorBookings({
    int limit = 50,
    int offset = 0,
    String role = 'all',
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/mentor/bookings',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'role': role},
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> updateMentorBooking({
    required String bookingId,
    String? status,
    String? scheduledAt,
    String? studentNote,
    String? advisorNote,
  }) async {
    final decoded = await _requestJson(
      'PATCH',
      '/api/v1/me/mentor/bookings/$bookingId',
      withAuth: true,
      body: {
        if (status != null) 'status': status,
        if (scheduledAt != null) 'scheduled_at': scheduledAt,
        if (studentNote != null) 'student_note': studentNote,
        if (advisorNote != null) 'advisor_note': advisorNote,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchMyMentorEarnings({
    int limit = 50,
    int offset = 0,
    String? status,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/me/mentor/earnings',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'status': status},
      ),
    );
    return decoded;
  }

  static Future<Map<String, dynamic>> requestMentorWithdrawal({
    required int amount,
    String currency = 'cny',
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/mentor/withdrawals',
      withAuth: true,
      body: {
        'amount': amount,
        'currency': currency,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> reviewMentorBooking({
    required String bookingId,
    required int rating,
    String? body,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/me/mentor/bookings/$bookingId/review',
      withAuth: true,
      body: {
        'rating': rating,
        if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchArtists({
    int limit = 20,
    int offset = 0,
    String? keyword,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/artists',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'keyword': keyword},
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> upsertArtistProfile(
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/artists',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchArtist(String id) async {
    try {
      final decoded = await _requestJson('GET', '/api/v1/artists/$id');
      return decoded['data'] as Map<String, dynamic>;
    } on Exception catch (e) {
      if (e.toString().contains('未找到')) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> fetchArtistDetail(String id) {
    return fetchArtist(id);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchArtworks({
    int limit = 20,
    int offset = 0,
    String? userId,
    String? category,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/artworks',
      query: _params(
        limit: limit,
        offset: offset,
        extra: {
          'user_id': userId,
          'category': category,
        },
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> createArtwork({
    required String title,
    String? category,
    List<String> images = const [],
    String? description,
    String visibility = 'public',
    String status = 'reviewing',
    Map<String, dynamic>? metadata,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/artworks',
      withAuth: true,
      body: {
        'title': title,
        if (category != null) 'category': category,
        'images': images,
        if (description != null) 'description': description,
        'visibility': visibility,
        'status': status,
        if (metadata != null) 'metadata': metadata,
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>?> fetchArtwork(String id) async {
    try {
      final decoded = await _requestJson('GET', '/api/v1/artworks/$id');
      return decoded['data'] as Map<String, dynamic>;
    } on Exception catch (e) {
      if (e.toString().contains('未找到')) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> updateArtwork(
    String id,
    Map<String, dynamic> body,
  ) async {
    final decoded = await _requestJson(
      'PUT',
      '/api/v1/artworks/$id',
      withAuth: true,
      body: body,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> archiveArtwork(String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/artworks/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteArtwork(String id) {
    return archiveArtwork(id);
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchMyArtworks({
    int limit = 20,
    int offset = 0,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/artworks/me',
      withAuth: true,
      query: _params(limit: limit, offset: offset),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<Map<String, dynamic>> likeArtwork(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/artworks/$id/like',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> unlikeArtwork(String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/artworks/$id/like',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> favoriteArtwork(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/artworks/$id/favorite',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> unfavoriteArtwork(String id) async {
    final decoded = await _requestJson(
      'DELETE',
      '/api/v1/artworks/$id/favorite',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchArtworkStats(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/artworks/$id/stats',
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<
      ({
        List<Map<String, dynamic>> data,
        int? count,
        int limit,
        int offset
      })> fetchNotifications({
    int limit = 20,
    int offset = 0,
    String? readStatus,
  }) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/notifications',
      withAuth: true,
      query: _params(
        limit: limit,
        offset: offset,
        extra: {'read_status': readStatus},
      ),
    );
    return _paginated(decoded, limit: limit, offset: offset);
  }

  static Future<int> fetchUnreadNotificationCount() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/notifications/unread-count',
      withAuth: true,
    );
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      final count = data['count'];
      if (count is num) return count.toInt();
      return int.tryParse(count?.toString() ?? '') ?? 0;
    }
    return 0;
  }

  static Future<Map<String, dynamic>> markNotificationRead(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/notifications/$id/read',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> markAllNotificationsRead() async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/notifications/read-all',
      withAuth: true,
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> uploadFile({
    required List<int> bytes,
    required String filename,
    required String contentType,
    String folder = 'uploads',
  }) async {
    try {
      return await _uploadFileToCos(
        bytes: bytes,
        filename: filename,
        contentType: contentType,
        folder: folder,
      );
    } on ApiException catch (e) {
      if (e.code == 503) {
        return _uploadFileLegacy(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
          folder: folder,
        );
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _uploadFileToCos({
    required List<int> bytes,
    required String filename,
    required String contentType,
    required String folder,
  }) async {
    final signDecoded = await _requestJson(
      'POST',
      '/api/v1/uploads/cos/sign',
      withAuth: true,
      body: {
        'file_name': filename,
        'content_type': contentType,
        'size': bytes.length,
        'scene': folder,
      },
    );
    final signed = signDecoded['data'] as Map<String, dynamic>? ?? {};
    final uploadUrl = signed['upload_url']?.toString() ?? '';
    if (uploadUrl.isEmpty) {
      throw ApiException(code: 500, message: '上传签名缺少 URL');
    }

    final rawHeaders = signed['headers'];
    final headers = <String, String>{};
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        headers[entry.key.toString()] = entry.value.toString();
      }
    }
    final uploaded = await http.put(
      Uri.parse(uploadUrl),
      headers: headers,
      body: bytes,
    );
    if (uploaded.statusCode < 200 || uploaded.statusCode >= 300) {
      throw ApiException(
        code: uploaded.statusCode,
        message: 'COS 上传失败 ${uploaded.statusCode}',
      );
    }

    final publicUrl = signed['public_url']?.toString() ?? '';
    final completeDecoded = await _requestJson(
      'POST',
      '/api/v1/uploads/cos/complete',
      withAuth: true,
      body: {
        'key': signed['key']?.toString() ?? '',
        'url': publicUrl,
        'bucket': signed['bucket']?.toString(),
        'file_type': contentType,
        'scene': folder,
        'size': bytes.length,
      },
    );
    final completed =
        completeDecoded['data'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return {
      ...signed,
      ...completed,
      'url': completed['url']?.toString().isNotEmpty == true
          ? completed['url']
          : publicUrl,
      'public_url': publicUrl,
      'provider': 'tencent_cos',
    };
  }

  static Future<Map<String, dynamic>> _uploadFileLegacy({
    required List<int> bytes,
    required String filename,
    required String contentType,
    required String folder,
  }) async {
    final request = http.MultipartRequest('POST', _api('/api/v1/upload'));
    request.headers.addAll(await _authHeaders());
    request.fields['folder'] = folder;
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _mediaType(contentType),
    ));
    final streamed = await request.send();
    final r = await http.Response.fromStream(streamed);
    final decoded = _decodeBody(r);
    final data = decoded['data'];
    final result = data is Map<String, dynamic>
        ? {...data}
        : <String, dynamic>{...decoded};
    final url = result['url']?.toString() ?? decoded['url']?.toString() ?? '';
    if (url.isNotEmpty) result['url'] = url;
    return result;
  }

  static Future<String> signSubmissionMaterial(String material) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/uploads/materials/sign',
      withAuth: true,
      body: {'url': material},
    );
    final signedUrl = decoded['signed_url']?.toString() ?? '';
    if (signedUrl.isEmpty) throw Exception('材料签名链接生成失败');
    return signedUrl;
  }

  static MediaType _mediaType(String raw) {
    final parts = raw.split('/');
    if (parts.length != 2) return MediaType('application', 'octet-stream');
    return MediaType(parts[0], parts[1]);
  }

  static Future<List<Map<String, dynamic>>> fetchMyOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    final r = await http.get(
      _api('/api/v1/orders', {'limit': '$limit', 'offset': '$offset'}),
      headers: await _headers(withAuth: true),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'orders ${r.statusCode}');
    }
    return (decoded['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> fetchMyOrder(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/orders/$id',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> fetchOrderRefunds(String id) async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/orders/$id/refunds',
      withAuth: true,
    );
    return (decoded['data'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> requestOrderRefund({
    required String id,
    String? reason,
  }) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/orders/$id/refunds',
      withAuth: true,
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> checkoutExistingOrder(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/orders/$id/checkout',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> confirmExistingOrder(String id) async {
    final decoded = await _requestJson(
      'POST',
      '/api/v1/orders/$id/confirm',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>;
  }

  /// 首页内容（`home_contents` 表，经 Next `/api/v1/home-contents`）
  static Future<List<HomeContent>> fetchHomeContents(
      {String? sectionType}) async {
    final params = <String, String>{};
    if (sectionType != null && sectionType.isNotEmpty) {
      params['section_type'] = sectionType;
    }
    final r = await http.get(
      _api('/api/v1/home-contents', params),
      headers: await _headers(),
    );
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'home_contents ${r.statusCode}');
    }
    final list = body['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => HomeContent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<HomeContent?> fetchHomeContent(String id) async {
    final r = await http.get(
      _api('/api/v1/home-contents/$id'),
      headers: await _headers(),
    );
    if (r.statusCode == 404) return null;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'home_content ${r.statusCode}');
    }
    final data = body['data'] as Map<String, dynamic>?;
    return data == null ? null : HomeContent.fromJson(data);
  }

  /// AI 选校：返回 Next 侧 JSON（含 `result` 表格字段）
  static Future<Map<String, dynamic>> aiSchoolSearch(String query,
      {int limitSchools = 40}) async {
    final r = await http.post(
      _api('/api/v1/ai/schools/search'),
      headers: await _headers(),
      body: jsonEncode({'query': query, 'limitSchools': limitSchools}),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200) {
      throw Exception(decoded['error'] ?? 'AI ${r.statusCode}');
    }
    return decoded;
  }

  /// 注册新用户（通过 Next.js API）
  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String nickname,
    required String emailOtp,
  }) async {
    final r = await http.post(
      _api('/api/v1/auth/signup'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
        'email_otp': emailOtp,
      }),
    );
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? '注册失败 ${r.statusCode}');
    }
    return decoded;
  }

  static Future<Map<String, dynamic>> sendEmailOtp({
    required String email,
    String? nickname,
    String purpose = 'signup',
  }) {
    return _requestJson(
      'POST',
      '/api/v1/auth/send-email-otp',
      body: {
        'email': email.trim(),
        'purpose': purpose,
        if (nickname != null && nickname.trim().isNotEmpty)
          'nickname': nickname.trim(),
      },
    );
  }

  static Future<Map<String, dynamic>> registerWithBff({
    required String email,
    required String password,
    required String username,
  }) {
    return _requestJson(
      'POST',
      '/api/v1/auth/register',
      body: {
        'email': email,
        'password': password,
        'username': username,
      },
    );
  }

  static Future<Map<String, dynamic>> loginWithBff({
    required String email,
    required String password,
  }) {
    return _requestJson(
      'POST',
      '/api/v1/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );
  }

  static Future<Map<String, dynamic>> devLogin({String? devSecret}) async {
    final headers = await _headers();
    if (devSecret != null && devSecret.isNotEmpty) {
      headers['x-dev-secret'] = devSecret;
    }
    final r = await http.post(
      _api('/api/v1/auth/dev-login'),
      headers: headers,
    );
    return _decodeBody(r);
  }

  static Future<Map<String, dynamic>> fetchAuthProfile() {
    return _requestJson('GET', '/api/v1/auth/profile', withAuth: true);
  }

  static Future<Map<String, dynamic>> updateAuthProfile(
    Map<String, dynamic> body,
  ) {
    return _requestJson(
      'POST',
      '/api/v1/auth/update-profile',
      withAuth: true,
      body: body,
    );
  }

  static Future<Map<String, dynamic>> exportAuthProfile() {
    return _requestJson(
      'GET',
      '/api/v1/auth/profile/export',
      withAuth: true,
    );
  }

  static Future<Map<String, dynamic>> fetchProfileFieldHistory(
    String field,
  ) {
    return _requestJson(
      'GET',
      '/api/v1/auth/profile/field-history',
      withAuth: true,
      query: {'field': field},
    );
  }

  static Future<Map<String, dynamic>> fetchPublicUserProfile(String userId) {
    return _requestJson(
      'GET',
      '/api/v1/users/$userId/public-profile',
    );
  }

  static Future<Map<String, dynamic>> sendSms({
    required String phone,
    String countryCode = '+86',
    String purpose = 'login',
  }) {
    return _requestJson(
      'POST',
      '/api/v1/auth/send-sms',
      body: {
        'phone': phone,
        'country_code': countryCode,
        'purpose': purpose,
      },
    );
  }

  static Future<Map<String, dynamic>> verifySms({
    required String phone,
    required String code,
    String countryCode = '+86',
  }) {
    return _requestJson(
      'POST',
      '/api/v1/auth/verify-sms',
      body: {
        'phone': phone,
        'code': code,
        'country_code': countryCode,
      },
    );
  }

  /// 完成 onboarding（通过 Next.js API）
  static Future<Map<String, dynamic>> completeOnboarding({
    required String userId,
    List<String>? interestedCategories,
    String? userRole,
    String? userType,
    String? primaryGoal,
    List<String>? goals,
    List<String>? targetDirections,
    List<String>? targetMajors,
    String? cityPreference,
    List<String>? activityCities,
    List<String>? eventPreferences,
    String? currentStage,
    String? verificationIntent,
    String? businessName,
    String? businessCity,
    String? businessContact,
    String? businessChannel,
    String? businessIntro,
    List<String>? businessMaterials,
    List<String>? businessProofFiles,
  }) async {
    final url = _api('/api/v1/auth/complete-onboarding');
    final body = jsonEncode({
      'userId': userId,
      'interestedCategories': interestedCategories,
      if (userRole != null) 'userRole': userRole,
      if (userType != null) 'userType': userType,
      if (primaryGoal != null) 'primaryGoal': primaryGoal,
      if (goals != null) 'goals': goals,
      if (targetDirections != null) 'targetDirections': targetDirections,
      if (targetMajors != null) 'targetMajors': targetMajors,
      if (cityPreference != null) 'cityPreference': cityPreference,
      if (activityCities != null) 'activityCities': activityCities,
      if (eventPreferences != null) 'eventPreferences': eventPreferences,
      if (currentStage != null) 'currentStage': currentStage,
      if (verificationIntent != null) 'verificationIntent': verificationIntent,
      if (businessName != null) 'businessName': businessName,
      if (businessCity != null) 'businessCity': businessCity,
      if (businessContact != null) 'businessContact': businessContact,
      if (businessChannel != null) 'businessChannel': businessChannel,
      if (businessIntro != null) 'businessIntro': businessIntro,
      if (businessMaterials != null) 'businessMaterials': businessMaterials,
      if (businessProofFiles != null) 'businessProofFiles': businessProofFiles,
    });
    final headers = await _headers(withAuth: true);
    final r = await http.post(url, headers: headers, body: body);
    final decoded = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200 || decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'onboarding 失败 ${r.statusCode}');
    }
    return decoded;
  }

  /// 获取 AI 推荐卡片（节点二）
  static Future<List<Map<String, dynamic>>> fetchAiRecommendCards() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/ai/recommend-cards',
      withAuth: true,
    );
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// 获取用户申请准备进度
  static Future<Map<String, dynamic>> fetchApplicationProgress() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/user/application-progress',
      withAuth: true,
    );
    return decoded['data'] as Map<String, dynamic>? ?? {};
  }

  /// 获取申请工具列表
  static Future<List<Map<String, dynamic>>> fetchTools() async {
    final decoded = await _requestJson(
      'GET',
      '/api/v1/tools',
      withAuth: false,
    );
    final data = decoded['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }
}
