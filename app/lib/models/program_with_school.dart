class ProgramWithSchool {
  final String id;
  final String programName;
  final String? degreeType;
  final int? durationMonths;
  final bool requiresPortfolio;
  final double? tuitionFee;
  final String? applicationDeadline;
  final SchoolInfo? school;

  ProgramWithSchool({
    required this.id,
    required this.programName,
    this.degreeType,
    this.durationMonths,
    required this.requiresPortfolio,
    this.tuitionFee,
    this.applicationDeadline,
    this.school,
  });

  factory ProgramWithSchool.fromJson(Map<String, dynamic> json) {
    return ProgramWithSchool(
      id: json['id'].toString(),
      programName: json['program_name'] as String,
      degreeType: json['degree_type'] as String?,
      durationMonths: json['duration_months'] as int?,
      requiresPortfolio: json['requires_portfolio'] as bool? ?? false,
      tuitionFee: (json['tuition_fee'] as num?)?.toDouble(),
      applicationDeadline: json['application_deadline'] as String?,
      school: json['schools'] != null
          ? SchoolInfo.fromJson(json['schools'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SchoolInfo {
  final String id;
  final String nameZh;
  final String? nameEn;
  final String? logoUrl;

  SchoolInfo({
    required this.id,
    required this.nameZh,
    this.nameEn,
    this.logoUrl,
  });

  factory SchoolInfo.fromJson(Map<String, dynamic> json) {
    return SchoolInfo(
      id: json['id'].toString(),
      nameZh: json['name_zh'] as String,
      nameEn: json['name_en'] as String?,
      logoUrl: json['logo_url'] as String?,
    );
  }
}
