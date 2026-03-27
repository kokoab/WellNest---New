import '../utils/json_helpers.dart';

/// Report model for admin moderation (matches backend GET admin/reports response).
class Report {
  final int id;
  final String? reporter;
  final String? reason;
  final String? details;
  final String status;
  final String createdAt;
  final ReportableSummary? reportable;

  Report({
    required this.id,
    this.reporter,
    this.reason,
    this.details,
    required this.status,
    required this.createdAt,
    this.reportable,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    ReportableSummary? reportable;
    final r = json['reportable'];
    if (r != null && r is Map<String, dynamic>) {
      reportable = ReportableSummary.fromJson(r);
    }
    return Report(
      id: jsonDecodeInt(json['id']),
      reporter: json['reporter'] as String?,
      reason: json['reason'] as String?,
      details: json['details'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
      reportable: reportable,
    );
  }

  String get reportableLabel {
    if (reportable == null) return 'Unknown';
    return reportable!.displayLabel;
  }

  bool get isUserReport => reportable?.type == 'user';
  bool get isRecipeReport => reportable?.type == 'recipe';
  bool get isPostReport => reportable?.type == 'post';
}

/// Summary of the reported item (user, recipe, or post).
class ReportableSummary {
  final String type; // 'user' | 'recipe' | 'post'
  final int id;
  final String? name;
  final String? email;
  final String? title;
  final String? content;

  ReportableSummary({
    required this.type,
    required this.id,
    this.name,
    this.email,
    this.title,
    this.content,
  });

  factory ReportableSummary.fromJson(Map<String, dynamic> json) {
    return ReportableSummary(
      type: json['type'] as String? ?? '',
      id: jsonDecodeInt(json['id']),
      name: json['name'] as String?,
      email: json['email'] as String?,
      title: json['title'] as String?,
      content: json['content'] as String?,
    );
  }

  String get displayLabel {
    switch (type) {
      case 'user':
        return name ?? email ?? 'User #$id';
      case 'recipe':
        return title ?? 'Recipe #$id';
      case 'post':
        return content != null && content!.isNotEmpty ? content! : 'Post #$id';
      default:
        return 'Unknown #$id';
    }
  }
}
