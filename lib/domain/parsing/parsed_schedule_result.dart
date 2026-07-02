class ParsedScheduleResult {
  final String title;
  final String? location;
  final DateTime startAt;
  final bool isAllDay;
  final List<String> warnings;

  const ParsedScheduleResult({
    required this.title,
    this.location,
    required this.startAt,
    required this.isAllDay,
    this.warnings = const [],
  });
}
