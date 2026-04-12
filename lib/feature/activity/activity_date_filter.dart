import 'package:otraku/extension/date_time_extension.dart';

sealed class ActivityDateFilter {
  const ActivityDateFilter();

  String get label;
  Map<String, dynamic> toGraphQlVariables();

  static String _fmt(DateTime d) => '${d.day} ${DateTimeExtension.monthName(d.month)}';
}

class ActivityDateNone extends ActivityDateFilter {
  const ActivityDateNone();

  @override
  String get label => 'All';

  @override
  Map<String, dynamic> toGraphQlVariables() => {};
}

class ActivityDateSingle extends ActivityDateFilter {
  const ActivityDateSingle(this.date);

  final DateTime date;

  @override
  String get label => ActivityDateFilter._fmt(date);

  @override
  Map<String, dynamic> toGraphQlVariables() => {
    'createdAfter': DateTime(date.year, date.month, date.day).secondsSinceEpoch,
    'createdBefore': DateTime(date.year, date.month, date.day, 23, 59, 59).secondsSinceEpoch,
  };
}

class ActivityDateRange extends ActivityDateFilter {
  const ActivityDateRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  @override
  String get label => '${ActivityDateFilter._fmt(from)} -${ActivityDateFilter._fmt(to)}';

  @override
  Map<String, dynamic> toGraphQlVariables() {
    final start = from.isBefore(to) ? from : to;
    final end = from.isBefore(to) ? to : from;

    return {
      'createdAfter': DateTime(start.year, start.month, start.day).secondsSinceEpoch,
      'createdBefore': DateTime(end.year, end.month, end.day, 23, 59, 59).secondsSinceEpoch,
    };
  }
}

class ActivityDateBefore extends ActivityDateFilter {
  const ActivityDateBefore(this.date);

  final DateTime date;

  @override
  String get label => 'Before ${ActivityDateFilter._fmt(date)}';

  @override
  Map<String, dynamic> toGraphQlVariables() => {
    'createdBefore': DateTime(date.year, date.month, date.day, 23, 59, 59).secondsSinceEpoch,
  };
}

class ActivityDateAfter extends ActivityDateFilter {
  const ActivityDateAfter(this.date);

  final DateTime date;

  @override
  String get label => 'After ${ActivityDateFilter._fmt(date)}';

  @override
  Map<String, dynamic> toGraphQlVariables() => {
    'createdAfter': DateTime(date.year, date.month, date.day).secondsSinceEpoch,
  };
}
