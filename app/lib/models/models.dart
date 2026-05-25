// Data models matching Supabase schema

export 'school_detail.dart';
export 'program_with_school.dart';

class ApplicationTrackerItem {
  final String id;
  final String? schoolId;
  final String? programId;
  final String schoolName;
  final String? programName;
  final String tier;
  final String status;
  final String? deadline;
  final String? notes;
  final String createdAt;
  final String? updatedAt;

  const ApplicationTrackerItem({
    required this.id,
    this.schoolId,
    this.programId,
    required this.schoolName,
    this.programName,
    required this.tier,
    required this.status,
    this.deadline,
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  factory ApplicationTrackerItem.fromJson(Map<String, dynamic> json) {
    return ApplicationTrackerItem(
      id: json['id'].toString(),
      schoolId: json['school_id']?.toString(),
      programId: json['program_id']?.toString(),
      schoolName: json['school_name']?.toString() ?? '未命名院校',
      programName: json['program_name']?.toString(),
      tier: json['tier']?.toString() ?? 'match',
      status: json['status']?.toString() ?? 'planning',
      deadline: json['deadline']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
    );
  }
}

class ApplicationTimelineTask {
  final String date;
  final String task;
  final String schoolName;
  final String priority;

  const ApplicationTimelineTask({
    required this.date,
    required this.task,
    required this.schoolName,
    required this.priority,
  });

  factory ApplicationTimelineTask.fromJson(Map<String, dynamic> json) {
    return ApplicationTimelineTask(
      date: json['date']?.toString() ?? '',
      task: json['task']?.toString() ?? '',
      schoolName: json['schoolName']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
    );
  }
}

class AppCase {
  final String id;
  final String title;
  final String? undergrad;
  final String? gpa;
  final String? targetSchool;
  final String? targetProgram;
  final String result; // admitted | waitlisted | rejected
  final String? content;
  final String? excerpt;
  final String? coverGradient;
  final bool isAnonymous;
  final List<String> tags;
  final String? year;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final String createdAt;
  final String? authorNickname;

  const AppCase({
    required this.id,
    required this.title,
    this.undergrad,
    this.gpa,
    this.targetSchool,
    this.targetProgram,
    required this.result,
    this.content,
    this.excerpt,
    this.coverGradient,
    required this.isAnonymous,
    required this.tags,
    this.year,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.createdAt,
    this.authorNickname,
  });

  factory AppCase.fromJson(Map<String, dynamic> json) {
    final profile = json['user_profiles'];
    return AppCase(
      id: json['id'] as String,
      title: json['title'] as String,
      undergrad: json['undergrad'] as String?,
      gpa: json['gpa'] as String?,
      targetSchool: json['target_school'] as String?,
      targetProgram: json['target_program'] as String?,
      result: json['result'] as String? ?? 'admitted',
      content: json['content'] as String?,
      excerpt: json['excerpt'] as String?,
      coverGradient: json['cover_gradient'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      year: json['year'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      saveCount: json['save_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      authorNickname: profile != null ? profile['nickname'] as String? : null,
    );
  }
}

/// 首页「社区」图文流（`community_posts` 表，经 Next `/api/v1/community/posts`）
class AppCommunityPost {
  final String id;
  final String title;
  final String? body;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool likedByMe;
  final String createdAt;
  final String? authorNickname;
  final String? authorAvatarUrl;

  const AppCommunityPost({
    required this.id,
    required this.title,
    this.body,
    required this.imageUrls,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    this.likedByMe = false,
    required this.createdAt,
    this.authorNickname,
    this.authorAvatarUrl,
  });

  factory AppCommunityPost.fromJson(Map<String, dynamic> json) {
    final up = json['user_profiles'];
    String? nick;
    if (up is Map<String, dynamic>) {
      nick = up['nickname'] as String?;
    }
    String? avatarUrl;
    if (up is Map<String, dynamic>) {
      avatarUrl = up['avatar_url'] as String?;
    }
    final urls = json['image_urls'];
    return AppCommunityPost(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String?,
      imageUrls: urls is List ? urls.map((e) => e.toString()).toList() : [],
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      authorNickname: nick,
      authorAvatarUrl: avatarUrl,
    );
  }
}

class AppCommunityComment {
  final String id;
  final String body;
  final int likeCount;
  final String createdAt;
  final String? authorNickname;
  final String? authorAvatarUrl;

  const AppCommunityComment({
    required this.id,
    required this.body,
    required this.likeCount,
    required this.createdAt,
    this.authorNickname,
    this.authorAvatarUrl,
  });

  factory AppCommunityComment.fromJson(Map<String, dynamic> json) {
    final up = json['user_profiles'];
    String? nick;
    String? avatarUrl;
    if (up is Map<String, dynamic>) {
      nick = up['nickname'] as String?;
      avatarUrl = up['avatar_url'] as String?;
    }
    return AppCommunityComment(
      id: json['id'] as String,
      body: json['body'] as String? ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      authorNickname: nick,
      authorAvatarUrl: avatarUrl,
    );
  }
}

class AppPost {
  final String id;
  final String type; // question | discussion | news
  final String title;
  final String? content;
  final List<String> tags;
  final int likeCount;
  final int answerCount;
  final int viewCount;
  final bool isMentorPost;
  final String createdAt;
  final String? authorNickname;

  const AppPost({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    required this.tags,
    required this.likeCount,
    required this.answerCount,
    required this.viewCount,
    required this.isMentorPost,
    required this.createdAt,
    this.authorNickname,
  });

  factory AppPost.fromJson(Map<String, dynamic> json) {
    final profile = json['user_profiles'];
    return AppPost(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'question',
      title: json['title'] as String,
      content: json['content'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
              [],
      likeCount: json['like_count'] as int? ?? 0,
      answerCount: json['answer_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      isMentorPost: json['is_mentor_post'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      authorNickname: profile != null ? profile['nickname'] as String? : null,
    );
  }
}

class AppProgram {
  final String id;
  final String programName;
  final String? degreeType;
  final String? durationText;
  final bool requiresPortfolio;
  final bool requiresInterview;
  final String? programOverview;
  final String? schoolNameZh;
  final int? qsArtRank;
  final double? ieltsOverall;
  final String? regularDeadline;
  final int? internationalTuitionFee;
  final String? currencyCode;
  final String? coverImageUrl;
  final List<String> coverImageUrls;

  const AppProgram({
    required this.id,
    required this.programName,
    this.degreeType,
    this.durationText,
    required this.requiresPortfolio,
    required this.requiresInterview,
    this.programOverview,
    this.schoolNameZh,
    this.qsArtRank,
    this.ieltsOverall,
    this.regularDeadline,
    this.internationalTuitionFee,
    this.currencyCode,
    this.coverImageUrl,
    this.coverImageUrls = const [],
  });

  factory AppProgram.fromJson(Map<String, dynamic> json) {
    final school = json['schools'] as Map<String, dynamic>?;
    final admission = _firstOrSingle(json['program_admissions']);
    final fee = _firstOrSingle(json['program_fees']);
    final coverImageUrl = json['cover_image_url'] as String?;
    final coverImageUrls = <String>{
      ..._stringList(json['cover_image_urls']),
      if (coverImageUrl != null && coverImageUrl.isNotEmpty) coverImageUrl,
      ..._stringList(school?['campus_image_urls']),
    }.toList();

    return AppProgram(
      id: json['id'].toString(),
      programName: json['program_name'] as String,
      degreeType: (json['degree_type'] ??
          json['normalized_degree_type'] ??
          json['raw_degree_type']) as String?,
      durationText: json['duration_text'] as String?,
      requiresPortfolio: json['requires_portfolio'] as bool? ?? false,
      requiresInterview: json['requires_interview'] as bool? ?? false,
      programOverview: json['program_overview'] as String?,
      schoolNameZh: school?['name_zh'] as String?,
      qsArtRank:
          (school?['qs_art_rank'] ?? school?['qs_art_design_rank']) as int?,
      ieltsOverall: (admission?['ielts_overall'] as num?)?.toDouble(),
      regularDeadline: admission?['regular_deadline'] as String?,
      internationalTuitionFee:
          (fee?['international_tuition_fee'] as num?)?.round(),
      currencyCode: fee?['currency_code'] as String?,
      coverImageUrl: coverImageUrl ??
          (coverImageUrls.isNotEmpty ? coverImageUrls.first : null),
      coverImageUrls: coverImageUrls,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
  return const [];
}

class AppReply {
  final String id;
  final String content;
  final int likeCount;
  final String createdAt;
  final String? authorNickname;

  const AppReply({
    required this.id,
    required this.content,
    required this.likeCount,
    required this.createdAt,
    this.authorNickname,
  });

  factory AppReply.fromJson(Map<String, dynamic> json) {
    final profile = json['user_profiles'];
    return AppReply(
      id: json['id'] as String,
      content: json['content'] as String,
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      authorNickname: profile != null ? profile['nickname'] as String? : null,
    );
  }
}

/// 首页内容（`home_contents` 表，经 Next `/api/v1/home-contents`）
class HomeContent {
  final String id;
  final String sectionType;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkText;
  final String? badge;
  final int displayOrder;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const HomeContent({
    required this.id,
    required this.sectionType,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.linkUrl,
    this.linkText,
    this.badge,
    required this.displayOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory HomeContent.fromJson(Map<String, dynamic> json) {
    return HomeContent(
      id: json['id'] as String? ?? '',
      sectionType: json['section_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String?,
      linkUrl: json['link_url'] as String?,
      linkText: json['link_text'] as String?,
      badge: json['badge'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

/// 兼容 Supabase 一对一关系返回的 Object 或一对多返回的 List
Map<String, dynamic>? _firstOrSingle(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is List && value.isNotEmpty) {
    return value.first as Map<String, dynamic>?;
  }
  return null;
}
