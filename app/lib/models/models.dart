// Data models matching Supabase schema

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
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      year: json['year'] as String?,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      saveCount: json['save_count'] as int? ?? 0,
      createdAt: json['created_at'] as String,
      authorNickname: profile != null ? profile['nickname'] as String? : null,
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
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
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
  final int id;
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
  });

  factory AppProgram.fromJson(Map<String, dynamic> json) {
    final school = json['schools'] as Map<String, dynamic>?;
    final admissions = json['program_admissions'] as List<dynamic>?;
    final fees = json['program_fees'] as List<dynamic>?;
    final admission = admissions?.isNotEmpty == true ? admissions!.first as Map<String, dynamic> : null;
    final fee = fees?.isNotEmpty == true ? fees!.first as Map<String, dynamic> : null;

    return AppProgram(
      id: json['id'] as int,
      programName: json['program_name'] as String,
      degreeType: json['degree_type'] as String?,
      durationText: json['duration_text'] as String?,
      requiresPortfolio: json['requires_portfolio'] as bool? ?? false,
      requiresInterview: json['requires_interview'] as bool? ?? false,
      programOverview: json['program_overview'] as String?,
      schoolNameZh: school?['name_zh'] as String?,
      qsArtRank: school?['qs_art_rank'] as int?,
      ieltsOverall: (admission?['ielts_overall'] as num?)?.toDouble(),
      regularDeadline: admission?['regular_deadline'] as String?,
      internationalTuitionFee: fee?['international_tuition_fee'] as int?,
      currencyCode: fee?['currency_code'] as String?,
    );
  }
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
