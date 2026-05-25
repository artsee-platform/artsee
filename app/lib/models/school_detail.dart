class SchoolDetail {
  final String id;
  final String nameZh;
  final String? nameEn;
  final String? country;
  final String? city;
  final String? schoolType;
  final int? qsArtRank;
  final int? qsArtDesignRank;
  final String? officialWebsite;
  final String? logoUrl;
  final String? bannerUrl;
  final String? description;
  final String status;
  final List<ProgramInfo> programs;
  final List<SchoolDocument> documents;
  final SchoolMedia media;
  final SchoolMetrics metrics;

  SchoolDetail({
    required this.id,
    required this.nameZh,
    this.nameEn,
    this.country,
    this.city,
    this.schoolType,
    this.qsArtRank,
    this.qsArtDesignRank,
    this.officialWebsite,
    this.logoUrl,
    this.bannerUrl,
    this.description,
    required this.status,
    required this.programs,
    required this.documents,
    required this.media,
    required this.metrics,
  });

  factory SchoolDetail.fromJson(Map<String, dynamic> json) {
    return SchoolDetail(
      id: json['id'].toString(),
      nameZh: json['name_zh'] as String,
      nameEn: json['name_en'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      schoolType: json['school_type'] as String?,
      qsArtRank: json['qs_art_rank'] as int?,
      qsArtDesignRank: json['qs_art_design_rank'] as int?,
      officialWebsite: json['official_website'] as String?,
      logoUrl: json['logo_url'] as String?,
      bannerUrl: json['banner_url'] as String?,
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      programs: (json['programs'] as List<dynamic>?)
              ?.map((e) => ProgramInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      documents: (json['documents'] as List<dynamic>?)
              ?.map((e) => SchoolDocument.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      media: json['media'] != null
          ? SchoolMedia.fromJson(json['media'] as Map<String, dynamic>)
          : SchoolMedia.empty(),
      metrics: json['metrics'] != null
          ? SchoolMetrics.fromJson(json['metrics'] as Map<String, dynamic>)
          : SchoolMetrics.empty(),
    );
  }
}

class ProgramInfo {
  final String id;
  final String programName;
  final String? degreeType;
  final int? durationMonths;
  final bool requiresPortfolio;
  final double? tuitionFee;
  final String? applicationDeadline;

  ProgramInfo({
    required this.id,
    required this.programName,
    this.degreeType,
    this.durationMonths,
    required this.requiresPortfolio,
    this.tuitionFee,
    this.applicationDeadline,
  });

  factory ProgramInfo.fromJson(Map<String, dynamic> json) {
    return ProgramInfo(
      id: json['id'].toString(),
      programName: json['program_name'] as String,
      degreeType: json['degree_type'] as String?,
      durationMonths: json['duration_months'] as int?,
      requiresPortfolio: json['requires_portfolio'] as bool? ?? false,
      tuitionFee: (json['tuition_fee'] as num?)?.toDouble(),
      applicationDeadline: json['application_deadline'] as String?,
    );
  }
}

class SchoolDocument {
  final String id;
  final String title;
  final String? content;
  final String documentType;

  SchoolDocument({
    required this.id,
    required this.title,
    this.content,
    required this.documentType,
  });

  factory SchoolDocument.fromJson(Map<String, dynamic> json) {
    return SchoolDocument(
      id: json['id'].toString(),
      title: json['title'] as String,
      content: json['content'] as String?,
      documentType: json['document_type'] as String? ?? 'general',
    );
  }
}

class SchoolMedia {
  final bool hasLogo;
  final bool hasBanner;
  final bool hasGallery;

  SchoolMedia({
    required this.hasLogo,
    required this.hasBanner,
    required this.hasGallery,
  });

  factory SchoolMedia.fromJson(Map<String, dynamic> json) {
    return SchoolMedia(
      hasLogo: json['has_logo'] as bool? ?? false,
      hasBanner: json['has_banner'] as bool? ?? false,
      hasGallery: json['has_gallery'] as bool? ?? false,
    );
  }

  factory SchoolMedia.empty() {
    return SchoolMedia(hasLogo: false, hasBanner: false, hasGallery: false);
  }
}

class SchoolMetrics {
  final int totalPrograms;
  final int totalDocuments;
  final int totalMedia;
  final double? avgTuitionFee;
  final double? acceptanceRate;

  SchoolMetrics({
    required this.totalPrograms,
    required this.totalDocuments,
    required this.totalMedia,
    this.avgTuitionFee,
    this.acceptanceRate,
  });

  factory SchoolMetrics.fromJson(Map<String, dynamic> json) {
    return SchoolMetrics(
      totalPrograms: json['total_programs'] as int? ?? 0,
      totalDocuments: json['total_documents'] as int? ?? 0,
      totalMedia: json['total_media'] as int? ?? 0,
      avgTuitionFee: (json['avg_tuition_fee'] as num?)?.toDouble(),
      acceptanceRate: (json['acceptance_rate'] as num?)?.toDouble(),
    );
  }

  factory SchoolMetrics.empty() {
    return SchoolMetrics(
      totalPrograms: 0,
      totalDocuments: 0,
      totalMedia: 0,
    );
  }
}
