// noda_dart: port of the parts of dotnet/runtime's System/DateTime.cs and TimeSpan.cs that TimeZoneInfo.dart uses.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).
//
// Days and tick of day are kept apart (dart2js ints can't hold every tick count); Unspecified kind only. A TimeSpan is
// an int of ticks. Shadows dart:core's DateTime where imported.

import 'package:meta/meta.dart';

/// TimeSpan.TicksPerMillisecond and friends.
@internal
abstract final class TimeSpanTicks {
  static const int PerMillisecond = 10000;
  static const int PerSecond = 10000000;
  static const int PerMinute = 600000000;
  static const int PerHour = 36000000000;
  static const int PerDay = 864000000000;
}

/// new TimeSpan(0, minutes, 0), as ticks.
@internal
int TimeSpanFromMinutes(int minutes) {
  return minutes * TimeSpanTicks.PerMinute;
}

const List<int> _DaysToMonth365 = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365];
const List<int> _DaysToMonth366 = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335, 366];

/// Days from 0001-01-01 to 10000-01-01.
const int _DaysTo10000 = 3652059;

bool _IsLeapYear(int year) {
  return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
}

/// Days from 0001-01-01 to the start of the given date.
int _DateToDays(int year, int month, int day) {
  final days = _IsLeapYear(year) ? _DaysToMonth366 : _DaysToMonth365;
  final y = year - 1;
  return y * 365 + y ~/ 4 - y ~/ 100 + y ~/ 400 + days[month - 1] + day - 1;
}

/// System.DateTime (Unspecified kind only), to tick precision.
@internal
final class DateTime {
  /// Whole days since 0001-01-01.
  final int Days;

  /// Ticks since the start of the day, [0, TicksPerDay).
  final int TickOfDay;

  const DateTime._(this.Days, this.TickOfDay);

  /// new DateTime(year, month, day[, hour, minute, second, millisecond]), validated as .NET does.
  static DateTime Create(int year, int month, int day,
      [int hour = 0, int minute = 0, int second = 0, int millisecond = 0]) {
    if (year < 1 || year > 9999 || month < 1 || month > 12) {
      throw RangeError('Year, Month, and Day parameters describe an un-representable DateTime.');
    }
    if (day < 1 || day > DateTime.DaysInMonth(year, month)) {
      throw RangeError('Year, Month, and Day parameters describe an un-representable DateTime.');
    }
    if (hour < 0 || hour >= 24 || minute < 0 || minute >= 60 || second < 0 || second >= 60) {
      throw RangeError('Hour, Minute, and Second parameters describe an un-representable DateTime.');
    }
    if (millisecond < 0 || millisecond >= 1000) {
      throw RangeError.value(millisecond, 'millisecond', 'Valid values are between 0 and 999, inclusive.');
    }
    final tickOfDay = hour * TimeSpanTicks.PerHour +
        minute * TimeSpanTicks.PerMinute +
        second * TimeSpanTicks.PerSecond +
        millisecond * TimeSpanTicks.PerMillisecond;
    return DateTime._(_DateToDays(year, month, day), tickOfDay);
  }

  /// DateTime.MinValue: 0001-01-01T00:00:00.
  static const DateTime MinValue = DateTime._(0, 0);

  /// DateTime.MaxValue: 9999-12-31T23:59:59.9999999.
  static const DateTime MaxValue = DateTime._(_DaysTo10000 - 1, TimeSpanTicks.PerDay - 1);

  static int DaysInMonth(int year, int month) {
    final days = _IsLeapYear(year) ? _DaysToMonth366 : _DaysToMonth365;
    return days[month] - days[month - 1];
  }

  /// The date part: midnight on the same day.
  DateTime get Date => DateTime._(Days, 0);

  /// The time of day, as TimeSpan ticks.
  int get TimeOfDay => TickOfDay;

  int get Year => _GetDatePart().$1;

  int get Month => _GetDatePart().$2;

  int get Day => _GetDatePart().$3;

  int get Hour => TickOfDay ~/ TimeSpanTicks.PerHour;

  int get Minute => (TickOfDay ~/ TimeSpanTicks.PerMinute) % 60;

  int get Second => (TickOfDay ~/ TimeSpanTicks.PerSecond) % 60;

  int get Millisecond => (TickOfDay ~/ TimeSpanTicks.PerMillisecond) % 1000;

  /// The ticks within the millisecond, [0, 10000).
  int get SubMillisecondTicks => TickOfDay % TimeSpanTicks.PerMillisecond;

  /// System.DayOfWeek: 0 (Sunday) to 6 (Saturday). 0001-01-01 was a Monday.
  int get DayOfWeek => (Days + 1) % 7;

  /// dateTime + timeSpan, or AddTicks; throws [RangeError] (ArgumentOutOfRangeException) outside [MinValue, MaxValue].
  DateTime AddTicks(int ticks) {
    final total = TickOfDay + ticks;
    // (Dart's % is Euclidean, so this is the floor division .NET's long arithmetic gives through the tick count.)
    final dayDelta = (total - total % TimeSpanTicks.PerDay) ~/ TimeSpanTicks.PerDay;
    final days = Days + dayDelta;
    if (days < 0 || days >= _DaysTo10000) {
      throw RangeError.value(ticks, 'value', 'The added or subtracted value results in an un-representable DateTime.');
    }
    return DateTime._(days, total - dayDelta * TimeSpanTicks.PerDay);
  }

  DateTime AddMilliseconds(int milliseconds) {
    return AddTicks(milliseconds * TimeSpanTicks.PerMillisecond);
  }

  DateTime AddDays(int days) {
    return AddTicks(days * TimeSpanTicks.PerDay);
  }

  /// DateTime.AddYears: the same month and day (the 28th for 29 February in a common year), and time of day.
  DateTime AddYears(int years) {
    final (Year, Month, Day) = _GetDatePart();
    final year = Year + years;
    if (year < 1 || year > 9999) {
      throw RangeError.value(years, 'years', 'The added or subtracted value results in an un-representable DateTime.');
    }
    final day = Day < DateTime.DaysInMonth(year, Month) ? Day : DateTime.DaysInMonth(year, Month);
    return DateTime._(_DateToDays(year, Month, day), TickOfDay);
  }

  /// Compares two values: negative, zero or positive.
  int CompareTo(DateTime other) {
    return Days != other.Days ? Days - other.Days : TickOfDay - other.TickOfDay;
  }

  bool Equals(DateTime other) {
    return Days == other.Days && TickOfDay == other.TickOfDay;
  }

  @override
  bool operator ==(Object other) => other is DateTime && Equals(other);

  @override
  int get hashCode => Object.hash(Days, TickOfDay);

  /// "yyyy-MM-ddTHH:mm:ss.fffffff", for messages and tests.
  @override
  String toString() {
    final (Year, Month, Day) = _GetDatePart();
    String pad(int value, int length) => value.toString().padLeft(length, '0');
    return '${pad(Year, 4)}-${pad(Month, 2)}-${pad(Day, 2)}T${pad(Hour, 2)}:${pad(Minute, 2)}:${pad(Second, 2)}.'
        '${pad(TickOfDay % TimeSpanTicks.PerSecond, 7)}';
  }

  /// (Year, Month, Day).
  (int, int, int) _GetDatePart() {
    // DateTime.GetDate: 400-, 100-, 4- and 1-year cycles.
    var n = Days;
    final y400 = n ~/ 146097;
    n -= y400 * 146097;
    var y100 = n ~/ 36524;
    if (y100 == 4) {
      y100 = 3;
    }
    n -= y100 * 36524;
    final y4 = n ~/ 1461;
    n -= y4 * 1461;
    var y1 = n ~/ 365;
    if (y1 == 4) {
      y1 = 3;
    }
    n -= y1 * 365;
    final year = y400 * 400 + y100 * 100 + y4 * 4 + y1 + 1;
    final days = _IsLeapYear(year) ? _DaysToMonth366 : _DaysToMonth365;
    var month = 1;
    while (n >= days[month]) {
      month++;
    }
    return (year, month, n - days[month - 1] + 1);
  }
}
