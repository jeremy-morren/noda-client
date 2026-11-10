// noda_dart: new code. Types of the generated golden vectors (as ts/test/golden/types.ts).

import '../scenarios/types.dart';

final class FormattingGolden {
  const FormattingGolden({required this.culture, required this.cases});

  final String culture;

  final List<FormattingCase> cases;
}

final class FormattingCase {
  const FormattingCase({required this.type, required this.pattern, required this.value, this.text, this.roundTrips, this.error});

  /// Value type, e.g. "LocalDate" (the pattern class is `${type}Pattern`).
  final String type;

  final String pattern;

  final EncodedValue value;

  /// Absent if formatting threw.
  final String? text;

  final bool? roundTrips;

  final String? error;
}

final class CompareGolden {
  const CompareGolden({required this.culture, required this.cases});

  final String culture;

  /// (text, candidate, equal): CompareInfo.Compare(text, candidate, CompareOptions.IgnoreCase) == 0.
  final List<(String, String, bool)> cases;
}

/// NodaTime.Serialization.SystemTextJson's output; JSON doesn't record the calendar, so it's given.
final class JsonGolden {
  const JsonGolden({required this.calendar, required this.json, required this.properties});

  final String calendar;

  final String json;

  final List<JsonGoldenProperty> properties;
}

final class JsonGoldenProperty {
  const JsonGoldenProperty({required this.name, required this.type, required this.value});

  final String name;

  final String type;

  final EncodedValue value;
}

/// One calendar's year shapes: `years[i]` indexes [yearTypes] for year `minYear + i`.
final class CalendarGolden {
  const CalendarGolden({
    required this.id,
    required this.minYear,
    required this.maxYear,
    required this.minDays,
    required this.maxDays,
    required this.yearTypes,
    required this.years,
  });

  final String id;

  final int minYear;
  final int maxYear;

  /// Days since 1970-01-01 ISO.
  final int minDays;

  /// Days since 1970-01-01 ISO.
  final int maxDays;

  final List<CalendarYearType> yearTypes;
  final List<int> years;
}

final class CalendarYearType {
  const CalendarYearType({required this.leap, required this.days, required this.monthLengths, required this.monthStarts});

  final bool leap;

  final int days;

  final List<int> monthLengths;

  /// Not always increasing: the Hebrew scriptural year starts at month 7.
  final List<int> monthStarts;
}
