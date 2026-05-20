part of 'package:wellnest/screens/admin_dashboard.dart';

/// Matches API bucket count for line charts (two series must use the same N).
int _adminChartPointCount2(List<AdminStatPoint> a, List<AdminStatPoint> b) {
  final n = math.max(a.length, b.length);
  return n > 0 ? n : 6;
}

int _adminChartPointCount3(
  List<AdminStatPoint> a,
  List<AdminStatPoint> b,
  List<AdminStatPoint> c,
) {
  final n = math.max(math.max(a.length, b.length), c.length);
  return n > 0 ? n : 6;
}

class _ChartsSection extends StatelessWidget {
  final ThemeData theme;
  final List<AdminUser> users;
  final List<Report> reports;
  final List<ActivityLog> auditLogs;
  final bool analyticsLoading;
  final String? analyticsError;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  final bool isWide;

  const _ChartsSection({
    required this.theme,
    required this.users,
    required this.reports,
    required this.auditLogs,
    required this.analyticsLoading,
    required this.analyticsError,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MinimalSectionLabel(
          theme: theme,
          label: 'Analytics',
          subtitle: 'Growth and platform activity trends',
        ),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _UserGrowthCard(
                      theme: theme,
                      isDark: isDark,
                      userGrowthPoints: userGrowthPoints,
                      postFrequencyPoints: postFrequencyPoints,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _RecipeRatingsCard(
                      theme: theme,
                      isDark: isDark,
                      chatbotInteractionPoints: chatbotInteractionPoints,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _UserGrowthCard(
                    theme: theme,
                    isDark: isDark,
                    userGrowthPoints: userGrowthPoints,
                    postFrequencyPoints: postFrequencyPoints,
                  ),
                  const SizedBox(height: 12),
                  _RecipeRatingsCard(
                    theme: theme,
                    isDark: isDark,
                    chatbotInteractionPoints: chatbotInteractionPoints,
                  ),
                ],
              ),
        const SizedBox(height: 12),
        isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _ModerationDonutCard(
                      theme: theme,
                      isDark: isDark,
                      reports: reports,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AuditActivityCard(
                      theme: theme,
                      isDark: isDark,
                      userGrowthPoints: userGrowthPoints,
                      postFrequencyPoints: postFrequencyPoints,
                      chatbotInteractionPoints: chatbotInteractionPoints,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _ModerationDonutCard(
                    theme: theme,
                    isDark: isDark,
                    reports: reports,
                  ),
                  const SizedBox(height: 12),
                  _AuditActivityCard(
                    theme: theme,
                    isDark: isDark,
                    userGrowthPoints: userGrowthPoints,
                    postFrequencyPoints: postFrequencyPoints,
                    chatbotInteractionPoints: chatbotInteractionPoints,
                  ),
                ],
              ),
        if (analyticsLoading) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 2,
            color: kPrimaryGreen,
            backgroundColor: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
          ),
        ] else if (analyticsError != null && analyticsError!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            analyticsError!,
            style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
          ),
        ],
      ],
    );
  }
}

// ─── Chart Card Wrapper ───────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final ThemeData theme;
  final String title;
  final String subtitle;
  final String badge;
  final bool badgeGreen;
  final List<Widget> legend;
  final Widget child;

  const _ChartCard({
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeGreen,
    required this.legend,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1F2329) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: wellnestOutlineColor(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeGreen
                      ? kPrimaryGreen.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeGreen
                        ? kPrimaryGreen
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: legend),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _UserGrowthCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  const _UserGrowthCard({
    required this.theme,
    required this.isDark,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
  });

  @override
  Widget build(BuildContext context) {
    final pointsCount = _adminChartPointCount2(
      userGrowthPoints,
      postFrequencyPoints,
    );
    final chartPoints = userGrowthPoints.isNotEmpty
        ? userGrowthPoints
        : postFrequencyPoints;
    final labels = _buildDateLabels(chartPoints, pointsCount);
    final usersSeries = _normalizeSeries(userGrowthPoints, pointsCount);
    final postsSeries = _normalizeSeries(postFrequencyPoints, pointsCount);
    return _ChartCard(
      theme: theme,
      title: 'User growth',
      subtitle: 'Users and posts over time',
      badge: chartPoints.isEmpty ? 'No data' : 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'New users'),
        _LegendDot(color: kPrimaryGreen, label: 'Posts', dashed: true),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _LinePainter(
            seriesA: usersSeries,
            seriesB: postsSeries,
            colorA: const Color(0xFF378ADD),
            colorB: kPrimaryGreen,
            labels: labels,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _RecipeRatingsCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> chatbotInteractionPoints;
  const _RecipeRatingsCard({
    required this.theme,
    required this.isDark,
    required this.chatbotInteractionPoints,
  });

  @override
  Widget build(BuildContext context) {
    final pointsCount = chatbotInteractionPoints.isEmpty
        ? 6
        : chatbotInteractionPoints.length;
    final labels = _buildDateLabels(chatbotInteractionPoints, pointsCount);
    final values = _normalizeSeries(chatbotInteractionPoints, pointsCount);
    return _ChartCard(
      theme: theme,
      title: 'Chatbot interactions',
      subtitle: 'Messages started over time',
      badge: chatbotInteractionPoints.isEmpty ? 'No data' : 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'Conversations'),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(
            values: values,
            labels: labels,
            colors: const [
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
              Color(0xFF378ADD),
            ],
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _ModerationDonutCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<Report> reports;
  const _ModerationDonutCard({
    required this.theme,
    required this.isDark,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    final buckets = _countModerationStatuses(reports);
    final donutValues = <double>[
      buckets.open.toDouble(),
      buckets.dismissed.toDouble(),
      buckets.approved.toDouble(),
      buckets.removed.toDouble(),
    ];
    final total = reports.length;
    return _ChartCard(
      theme: theme,
      title: 'Moderation overview',
      subtitle: 'Report status breakdown',
      badge: total == 0 ? 'No reports' : '${buckets.open} open',
      badgeGreen: false,
      legend: [
        const _LegendDot(color: Color(0xFFBA7517), label: 'Open'),
        _LegendDot(color: kPrimaryGreen, label: 'Dismissed'),
        const _LegendDot(color: Color(0xFF378ADD), label: 'Approved'),
        const _LegendDot(color: Color(0xFFE24B4A), label: 'Removed'),
      ],
      child: SizedBox(
        height: 150,
        child: CustomPaint(
          size: Size.infinite,
          painter: _DonutPainter(
            values: donutValues,
            labels: const ['Open', 'Dismissed', 'Approved', 'Removed'],
            colors: const [
              Color(0xFFBA7517),
              kPrimaryGreen,
              Color(0xFF378ADD),
              Color(0xFFE24B4A),
            ],
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _AuditActivityCard extends StatelessWidget {
  final ThemeData theme;
  final bool isDark;
  final List<AdminStatPoint> userGrowthPoints;
  final List<AdminStatPoint> postFrequencyPoints;
  final List<AdminStatPoint> chatbotInteractionPoints;
  const _AuditActivityCard({
    required this.theme,
    required this.isDark,
    required this.userGrowthPoints,
    required this.postFrequencyPoints,
    required this.chatbotInteractionPoints,
  });

  @override
  Widget build(BuildContext context) {
    final pointsCount = _adminChartPointCount3(
      userGrowthPoints,
      postFrequencyPoints,
      chatbotInteractionPoints,
    );
    final labels = _buildDateLabels(
      userGrowthPoints.isNotEmpty
          ? userGrowthPoints
          : (postFrequencyPoints.isNotEmpty
                ? postFrequencyPoints
                : chatbotInteractionPoints),
      pointsCount,
    );
    final usersSeries = _normalizeSeries(userGrowthPoints, pointsCount);
    final postsSeries = _normalizeSeries(postFrequencyPoints, pointsCount);
    final chatbotSeries = _normalizeSeries(
      chatbotInteractionPoints,
      pointsCount,
    );
    return _ChartCard(
      theme: theme,
      title: 'Platform activity',
      subtitle: 'Users, posts, and chatbot activity',
      badge: 'Live',
      badgeGreen: true,
      legend: [
        const _LegendDot(color: Color(0xFF378ADD), label: 'Users'),
        _LegendDot(color: kPrimaryGreen, label: 'Posts'),
        const _LegendDot(color: Color(0xFFBA7517), label: 'Chatbot'),
      ],
      child: SizedBox(
        height: 160,
        child: CustomPaint(
          size: Size.infinite,
          painter: _StackedBarPainter(
            seriesA: usersSeries,
            seriesB: postsSeries,
            seriesC: chatbotSeries,
            colorA: const Color(0xFF378ADD),
            colorB: kPrimaryGreen,
            colorC: const Color(0xFFBA7517),
            labels: labels,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

List<double> _normalizeSeries(List<AdminStatPoint> source, int length) {
  final values = source.map((p) => p.count.toDouble()).toList();
  final tail = values.length > length
      ? values.sublist(values.length - length)
      : values;
  if (tail.length == length) return tail;
  return List<double>.filled(length - tail.length, 0) + tail;
}

List<String> _buildDateLabels(List<AdminStatPoint> source, int length) {
  final tail = source.length > length
      ? source.sublist(source.length - length)
      : source;
  final labels = tail
      .map((p) {
        final axis = p.axisLabel;
        if (axis != null && axis.trim().isNotEmpty) return axis.trim();
        return _formatChartBucketLabel(p.date);
      })
      .toList(growable: true);
  while (labels.length < length) {
    labels.insert(0, '—');
  }
  return labels;
}

/// X-axis bucket end date: full month name, day, and year (local time).
String _formatChartBucketLabel(DateTime d) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final local = d.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

double? _seriesPercentDelta(List<AdminStatPoint> points) {
  if (points.length < 2) return null;
  final last = points[points.length - 1].count.toDouble();
  final prev = points[points.length - 2].count.toDouble();
  if (prev == 0 && last == 0) return 0;
  if (prev == 0) return 100;
  return ((last - prev) / prev) * 100;
}

String _formatTrend(double? delta) {
  if (delta == null) return 'No data';
  final sign = delta >= 0 ? '+' : '';
  return '$sign${delta.toStringAsFixed(1)}%';
}

bool _isTrendUp(String trend) => trend.startsWith('+');

String _formatHumanDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[local.month - 1];
  final hour12 = local.hour == 0
      ? 12
      : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  final meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '$month ${local.day}, ${local.year} • $hour12:$minute $meridiem';
}

String _normalizeReportStatus(String status) {
  final normalized = status.trim().toLowerCase();
  if (normalized == 'pending') return 'open';
  return normalized;
}

({int open, int dismissed, int approved, int removed}) _countModerationStatuses(
  List<Report> reports,
) {
  var open = 0;
  var dismissed = 0;
  var approved = 0;
  var removed = 0;
  for (final report in reports) {
    switch (_normalizeReportStatus(report.status)) {
      case 'open':
        open++;
        break;
      case 'dismissed':
        dismissed++;
        break;
      case 'approved':
        approved++;
        break;
      case 'removed':
        removed++;
        break;
      default:
        open++;
        break;
    }
  }
  return (
    open: open,
    dismissed: dismissed,
    approved: approved,
    removed: removed,
  );
}

// ─── CustomPainter: Line Chart ────────────────────────────────────────────────
class _LinePainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final Color colorA;
  final Color colorB;
  final List<String> labels;
  final bool isDark;

  const _LinePainter({
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    final nX = labels.length;
    final double padBottom = nX > 9 ? 34 : 30;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final allValues = [...seriesA, ...seriesB];
    final dataMin = allValues.isNotEmpty ? allValues.reduce(math.min) : 0.0;
    final dataMax = allValues.isNotEmpty ? allValues.reduce(math.max) : 0.0;
    final minV = dataMin;
    final maxV = dataMax;
    final range = (maxV - minV) == 0 ? (maxV == 0 ? 1.0 : maxV) : maxV - minV;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    final double xFont = nX > 10 ? 6.0 : (nX > 7 ? 7.0 : 8.0);
    final xAxisLabelStyle = TextStyle(
      fontSize: xFont,
      height: 1.12,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    final double xLabelMaxW = nX > 1
        ? math.max(28, chartW / (nX - 1) * 0.9)
        : 120.0;
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      final val = minV + (i / gridCount) * range;
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toInt().toString();
      _drawText(
        canvas,
        label,
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    if (labels.isNotEmpty) {
      final denom = labels.length > 1 ? (labels.length - 1) : 1;
      for (int i = 0; i < labels.length; i++) {
        final x = padLeft + (i / denom) * chartW;
        final text = labels[i];
        if (text == '—') {
          _drawText(
            canvas,
            text,
            Offset(x - 4, size.height - padBottom + 4),
            xAxisLabelStyle,
            maxWidth: 16,
            align: TextAlign.center,
          );
        } else {
          final tp = TextPainter(
            text: TextSpan(text: text, style: xAxisLabelStyle),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: xLabelMaxW);
          tp.paint(
            canvas,
            Offset(x - tp.width / 2, size.height - padBottom + 4),
          );
        }
      }
    }
    Path buildPath(List<double> data) {
      final path = Path();
      if (data.isEmpty) return path;
      for (int i = 0; i < data.length; i++) {
        final x = data.length > 1
            ? padLeft + (i / (data.length - 1)) * chartW
            : padLeft + chartW / 2;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      return path;
    }

    void drawFill(List<double> data, Color color) {
      final path = buildPath(data);
      final fillPath = Path.from(path)
        ..lineTo(padLeft + chartW, padTop + chartH)
        ..lineTo(padLeft, padTop + chartH)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = color.withOpacity(0.08)
          ..style = PaintingStyle.fill,
      );
    }

    drawFill(seriesA, colorA);
    drawFill(seriesB, colorB);
    void drawLine(List<double> data, Color color, {bool dashed = false}) {
      final path = buildPath(data);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (!dashed) {
        canvas.drawPath(path, paint);
      } else {
        _drawDashedPath(canvas, path, paint);
      }
    }

    drawLine(seriesA, colorA);
    drawLine(seriesB, colorB, dashed: true);
    void drawDots(List<double> data, Color color) {
      for (int i = 0; i < data.length; i++) {
        final x = padLeft + (i / (data.length - 1)) * chartW;
        final y = padTop + chartH - ((data[i] - minV) / range) * chartH;
        canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = color);
        canvas.drawCircle(
          Offset(x, y),
          2,
          Paint()..color = isDark ? const Color(0xFF1C1C1C) : Colors.white,
        );
      }
    }

    drawDots(seriesA, colorA);
    drawDots(seriesB, colorB);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLen = 5.0;
    const gapLen = 3.0;
    final metric = path.computeMetrics().first;
    double dist = 0;
    bool drawing = true;
    while (dist < metric.length) {
      final next = (dist + (drawing ? dashLen : gapLen))
          .clamp(0.0, metric.length)
          .toDouble();
      if (drawing) canvas.drawPath(metric.extractPath(dist, next), paint);
      dist = next;
      drawing = !drawing;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.seriesA != seriesA ||
      old.seriesB != seriesB ||
      old.labels != labels ||
      old.isDark != isDark;
}

// ─── CustomPainter: Bar Chart ─────────────────────────────────────────────────
class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final bool isDark;
  const _BarPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    const double padBottom = 30;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final dataMax = values.isNotEmpty ? values.reduce(math.max) : 0.0;
    final maxV = dataMax <= 0 ? 1.0 : dataMax;
    final n = values.length;
    final barW = n > 0 ? (chartW / n) * 0.55 : 0.0;
    final gap = n > 0 ? (chartW / n) * 0.45 : 0.0;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    final nLab = labels.length;
    final double xBarFont = nLab > 10 ? 6.0 : (nLab > 7 ? 7.0 : 8.0);
    final xAxisLabelStyle = TextStyle(
      fontSize: xBarFont,
      height: 1.12,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      final val = (i / gridCount) * maxV;
      final label = val >= 1000
          ? '${(val / 1000).toStringAsFixed(1)}k'
          : val.toInt().toString();
      _drawText(
        canvas,
        label,
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      final barH = (values[i] / maxV) * chartH;
      final y = padTop + chartH - barH;
      final barColor = colors.isEmpty
          ? const Color(0xFF378ADD)
          : colors[i % colors.length];
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, y, barW, barH),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        Paint()..color = barColor,
      );
      final barCenter = x + barW / 2;
      final text = labels[i];
      final slotW = n > 0 ? chartW / n : chartW;
      if (text == '—') {
        _drawText(
          canvas,
          text,
          Offset(barCenter - 4, size.height - padBottom + 4),
          xAxisLabelStyle,
          maxWidth: 16,
          align: TextAlign.center,
        );
      } else {
        final tp = TextPainter(
          text: TextSpan(text: text, style: xAxisLabelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: math.max(32, slotW - 4));
        tp.paint(
          canvas,
          Offset(barCenter - tp.width / 2, size.height - padBottom + 4),
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.values != values || old.labels != labels || old.isDark != isDark;
}

// ─── CustomPainter: Donut Chart ───────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final List<Color> colors;
  final bool isDark;
  const _DonutPainter({
    required this.values,
    required this.labels,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    final safeTotal = total <= 0 ? 1.0 : total;
    final cx = size.width * 0.38;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 8;
    const strokeW = 26.0;
    double startAngle = -math.pi / 2;
    if (total > 0) {
      for (int i = 0; i < values.length; i++) {
        final sweep = (values[i] / safeTotal) * 2 * math.pi;
        if (sweep <= 0) {
          continue;
        }
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
          startAngle + 0.03,
          math.max(0, sweep - 0.06),
          false,
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeW
            ..strokeCap = StrokeCap.butt,
        );
        startAngle += sweep;
      }
    }
    _drawCenteredText(
      canvas,
      total.toInt().toString(),
      Offset(cx, cy - 8),
      TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF2C2C2A),
      ),
    );
    _drawCenteredText(
      canvas,
      'reports',
      Offset(cx, cy + 10),
      TextStyle(
        fontSize: 9,
        color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
      ),
    );
    final legendX = size.width * 0.62;
    const legendStartY = 20.0;
    const itemH = 26.0;
    final labelStyle = TextStyle(
      fontSize: 11,
      color: isDark ? const Color(0xFFD3D1C7) : const Color(0xFF444441),
    );
    final subStyle = TextStyle(
      fontSize: 10,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    for (int i = 0; i < values.length; i++) {
      final y = legendStartY + i * itemH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(legendX, y + 3, 9, 9),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i],
      );
      final pct = ((values[i] / safeTotal) * 100).toStringAsFixed(0);
      _drawText(
        canvas,
        labels[i],
        Offset(legendX + 14, y),
        labelStyle,
        maxWidth: size.width - legendX - 14,
      );
      _drawText(
        canvas,
        '$pct%  ·  ${values[i].toInt()}',
        Offset(legendX + 14, y + 13),
        subStyle,
        maxWidth: size.width - legendX - 14,
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset center,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 80,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.isDark != isDark;
}

// ─── CustomPainter: Stacked Bar Chart ────────────────────────────────────────
class _StackedBarPainter extends CustomPainter {
  final List<double> seriesA;
  final List<double> seriesB;
  final List<double> seriesC;
  final Color colorA;
  final Color colorB;
  final Color colorC;
  final List<String> labels;
  final bool isDark;
  const _StackedBarPainter({
    required this.seriesA,
    required this.seriesB,
    required this.seriesC,
    required this.colorA,
    required this.colorB,
    required this.colorC,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double padLeft = 36;
    const double padRight = 12;
    const double padTop = 10;
    const double padBottom = 30;
    final chartW = size.width - padLeft - padRight;
    final chartH = size.height - padTop - padBottom;
    final n = seriesA.length;
    double maxV = 0;
    for (int i = 0; i < n; i++) {
      maxV = math.max(maxV, seriesA[i] + seriesB[i] + seriesC[i]);
    }
    maxV = math.max(1.0, (maxV * 1.1).ceilToDouble());
    final barW = (chartW / n) * 0.55;
    final gap = (chartW / n) * 0.45;
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.06)
      ..strokeWidth = 0.5;
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    final nLab = labels.length;
    final double xStackFont = nLab > 10 ? 6.0 : (nLab > 7 ? 7.0 : 8.0);
    final xAxisLabelStyle = TextStyle(
      fontSize: xStackFont,
      height: 1.12,
      color: isDark ? const Color(0xFF888780) : const Color(0xFF888780),
    );
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padTop + chartH - (i / gridCount) * chartH;
      canvas.drawLine(
        Offset(padLeft, y),
        Offset(padLeft + chartW, y),
        gridPaint,
      );
      _drawText(
        canvas,
        ((i / gridCount) * maxV).toInt().toString(),
        Offset(0, y - 5),
        labelStyle,
        maxWidth: padLeft - 4,
        align: TextAlign.right,
      );
    }
    for (int i = 0; i < n; i++) {
      final x = padLeft + i * (chartW / n) + gap / 2;
      double currentY = padTop + chartH;
      void drawSegment(double val, Color color, {bool isTop = false}) {
        if (val <= 0) return;
        final segH = (val / maxV) * chartH;
        final top = currentY - segH;
        final rRect = isTop
            ? RRect.fromRectAndCorners(
                Rect.fromLTWH(x, top, barW, segH),
                topLeft: const Radius.circular(3),
                topRight: const Radius.circular(3),
              )
            : RRect.fromRectAndCorners(Rect.fromLTWH(x, top, barW, segH));
        canvas.drawRRect(rRect, Paint()..color = color);
        currentY = top;
      }

      drawSegment(seriesC[i], colorC);
      drawSegment(seriesB[i], colorB);
      drawSegment(seriesA[i], colorA, isTop: true);
      final barCenter = x + barW / 2;
      final text = labels[i];
      final slotW = n > 0 ? chartW / n : chartW;
      if (text == '—') {
        _drawText(
          canvas,
          text,
          Offset(barCenter - 4, size.height - padBottom + 4),
          xAxisLabelStyle,
          maxWidth: 16,
          align: TextAlign.center,
        );
      } else {
        final tp = TextPainter(
          text: TextSpan(text: text, style: xAxisLabelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout(maxWidth: math.max(32, slotW - 4));
        tp.paint(
          canvas,
          Offset(barCenter - tp.width / 2, size.height - padBottom + 4),
        );
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    double maxWidth = 60,
    TextAlign align = TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) =>
      old.seriesA != seriesA ||
      old.seriesB != seriesB ||
      old.seriesC != seriesC ||
      old.labels != labels ||
      old.isDark != isDark;
}

// ─── Recipe Rankings Card ─────────────────────────────────────────────────────
class _OverviewRecipeRankingsCard extends StatefulWidget {
  final ThemeData theme;
  final int refreshNonce;
  const _OverviewRecipeRankingsCard({
    required this.theme,
    required this.refreshNonce,
  });
  @override
  State<_OverviewRecipeRankingsCard> createState() =>
      _OverviewRecipeRankingsCardState();
}

class _OverviewRecipeRankingsCardState
    extends State<_OverviewRecipeRankingsCard> {
  List<RecipeRankingItem> _rows = [];
  bool _loading = true;
  String? _error;
  String _window = '7d';
  int _sortIndex = 0;
  bool _ascending = false;
  late final ScrollController _rankingsHScroll;
  late final ScrollController _rankingsVScroll;

  @override
  void initState() {
    super.initState();
    _rankingsHScroll = ScrollController();
    _rankingsVScroll = ScrollController();
    _load();
  }

  @override
  void dispose() {
    _rankingsHScroll.dispose();
    _rankingsVScroll.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_OverviewRecipeRankingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshNonce != widget.refreshNonce) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await RecipeService.instance.fetchRankings(
        window: _window,
        mode: 'combined',
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _sort<T>(int column, T Function(RecipeRankingItem r) key) {
    setState(() {
      if (_sortIndex == column) {
        _ascending = !_ascending;
      } else {
        _sortIndex = column;
        _ascending = false;
      }
      _rows.sort((a, b) {
        final cmp = Comparable.compare(
          key(a) as Comparable,
          key(b) as Comparable,
        );
        return _ascending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (_loading)
      return _SurfaceCard(
        theme: theme,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: CircularProgressIndicator(
              color: kPrimaryGreen,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    if (_error != null)
      return _SurfaceCard(
        theme: theme,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ),
      );

    return _SurfaceCard(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: _WindowTabs(
              current: _window,
              onChanged: (v) {
                setState(() => _window = v);
                _load();
              },
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: Scrollbar(
                  controller: _rankingsVScroll,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _rankingsVScroll,
                    child: Scrollbar(
                      controller: _rankingsHScroll,
                      notificationPredicate: (n) => n.depth == 1,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _rankingsHScroll,
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          sortColumnIndex: _sortIndex,
                          sortAscending: _ascending,
                          headingRowHeight: 38,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 48,
                          headingTextStyle: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          dataTextStyle: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface,
                          ),
                          dividerThickness: 0.5,
                          columns: [
                            const DataColumn(label: Text('#')),
                            DataColumn(
                              label: const Text('TITLE'),
                              onSort: (_, __) => _sort(1, (r) => r.title),
                            ),
                            DataColumn(
                              label: const Text('VIEWS'),
                              numeric: true,
                              onSort: (_, __) => _sort(2, (r) => r.viewsCount),
                            ),
                            DataColumn(
                              label: const Text('AVG RATING'),
                              numeric: true,
                              onSort: (_, __) =>
                                  _sort(3, (r) => r.averageRating),
                            ),
                            DataColumn(
                              label: const Text('RATINGS'),
                              numeric: true,
                              onSort: (_, __) =>
                                  _sort(4, (r) => r.ratingsCount),
                            ),
                            DataColumn(
                              label: const Text('SCORE'),
                              numeric: true,
                              onSort: (_, __) => _sort(5, (r) => r.score),
                            ),
                          ],
                          rows: List.generate(_rows.length, (i) {
                            final r = _rows[i];
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    r.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DataCell(Text('${r.viewsCount}')),
                                DataCell(
                                  Text(r.averageRating.toStringAsFixed(2)),
                                ),
                                DataCell(Text('${r.ratingsCount}')),
                                DataCell(
                                  Text(
                                    r.score.toStringAsFixed(3),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: kPrimaryGreen,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WindowTabs extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _WindowTabs({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      ('7d', 'Last 7 days'),
      ('30d', 'Last 30 days'),
      ('all', 'All time'),
    ];
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.$1 == current;
          return GestureDetector(
            onTap: () => onChanged(item.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF2A2A2A) : Colors.white)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                item.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Recent Logs List ─────────────────────────────────────────────────────────
class _RecentLogsList extends StatelessWidget {
  final ThemeData theme;
  final List<ActivityLog> logs;
  const _RecentLogsList({required this.theme, required this.logs});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      theme: theme,
      padding: EdgeInsets.zero,
      child: Column(
        children: logs.asMap().entries.map((e) {
          final log = e.value;
          final isLast = e.key == logs.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: kPrimaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: kPrimaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.description,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${log.actorName ?? 'System'} · ${log.category}',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatHumanDate(log.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 0.5,
                  indent: 16,
                  endIndent: 16,
                  color: theme.colorScheme.outline.withValues(alpha: 0.08),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Users Section ────────────────────────────────────────────────────────────
