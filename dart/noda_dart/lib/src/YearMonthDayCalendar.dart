// Ported from NodaTime 6e024dde: src/NodaTime/YearMonthDayCalendar.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'CalendarOrdinal.generated.dart' as nt show CalendarOrdinal;
import 'YearMonthDay.dart';

/// A compact representation of a year, month and day and calendar ordinal (integer ID) in a single 32-bit integer.
///
/// The calendar is represented in bits 0-5.
/// The day is represented in bits 6-11.
/// The month is represented in bits 12-16.
/// The year is represented in bits 17-31. (It's convenient to put this at the top as it can be negative.)
///
/// This type does not implement IComparable[YearMonthDayCalendar] as it turns out it doesn't need to:
/// comparisons are always done through the calendar system, which uses YearMonthDay instead. We could potentially
/// optimize by bypassing the calendar and embedding knowledge of calendars which have "odd" month numberings
/// in here, but it would be a bit of a design smell.
///
/// Equality is easily tested, however, as it can check for calendar equality.
///
/// The internal representation actually uses 0 for 1 (etc) for each component.
/// That means the default value is 0001-01-01, which is reasonable for all
/// supported calendars.
@internal
final class YearMonthDayCalendar {
  // These constants are internal so they can be used in YearMonthDay
  static const int CalendarBits = 6; // Up to 64 calendars.
  static const int DayBits = 6; // Up to 64 days in a month.
  static const int MonthBits = 5; // Up to 32 months per year.
  static const int YearBits = 15; // 32K range; only need -10K to +10K.

  // Just handy constants to use for shifting and masking.
  static const int _CalendarDayBits = CalendarBits + DayBits;
  static const int _CalendarDayMonthBits = _CalendarDayBits + MonthBits;

  static const int _CalendarMask = (1 << CalendarBits) - 1;
  static const int _DayMask = ((1 << DayBits) - 1) << CalendarBits;
  static const int _MonthMask = ((1 << MonthBits) - 1) << _CalendarDayBits;
  // noda_dart: positive here (C#'s is negative), so Year applies toSigned(32) before shifting.
  static const int _YearMask = ((1 << YearBits) - 1) << _CalendarDayMonthBits;

  final int _value;

  YearMonthDayCalendar._(this._value);

  /// C#'s two internal constructors, told apart by the number of arguments: (yearMonthDay, calendarOrdinal) or
  /// (year, month, day, calendarOrdinal). No validation is performed.
  factory YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(int yearOrYearMonthDay, Object monthOrCalendarOrdinal,
      [int? day, nt.CalendarOrdinal? calendarOrdinal]) {
    if (day == null) {
      int yearMonthDay = yearOrYearMonthDay;
      var calendarOrdinal = monthOrCalendarOrdinal as nt.CalendarOrdinal;
      return YearMonthDayCalendar._(((yearMonthDay << CalendarBits) | calendarOrdinal.value).toSigned(32));
    }
    int year = yearOrYearMonthDay;
    var month = monthOrCalendarOrdinal as int;
    // unchecked: C#'s int arithmetic, wrapped to 32 bits (so the value is the same on every platform).
    return YearMonthDayCalendar._((((year - 1) << _CalendarDayMonthBits) |
            ((month - 1) << _CalendarDayBits) |
            ((day - 1) << CalendarBits) |
            calendarOrdinal!.value)
        .toSigned(32));
  }

  nt.CalendarOrdinal get CalendarOrdinal => nt.CalendarOrdinal(_value & _CalendarMask);
  // noda_dart: toSigned(32) after >>, as dart2js's >> gives an unsigned 32-bit result for a negative value.
  int get Year => ((_value & _YearMask).toSigned(32) >> _CalendarDayMonthBits).toSigned(32) + 1;
  int get Month => ((_value & _MonthMask) >> _CalendarDayBits) + 1;
  int get Day => ((_value & _DayMask) >> CalendarBits) + 1;

  // Just for testing purposes... note that this does not perform clean validation.
  @visibleForTesting
  static YearMonthDayCalendar Parse(String text) {
    // Handle a leading - to negate the year
    if (text[0] == '-') {
      var ymdc = Parse(text.substring(1));
      return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(-ymdc.Year, ymdc.Month, ymdc.Day, ymdc.CalendarOrdinal);
    }

    List<String> bits = text.split('-');
    return YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(
        int.parse(bits[0]),
        int.parse(bits[1]),
        int.parse(bits[2]),
        _ParseCalendarOrdinal(bits[3]));
  }

  // noda_dart: new code. C#'s Enum.Parse(typeof(CalendarOrdinal), text, false).
  static nt.CalendarOrdinal _ParseCalendarOrdinal(String text) {
    for (int i = 0; i <= nt.CalendarOrdinal.Size.value; i++) {
      if (nt.CalendarOrdinal(i).Name == text) {
        return nt.CalendarOrdinal(i);
      }
    }
    throw ArgumentError("Requested value '$text' was not found.");
  }

  // noda_dart: toSigned(32) after >>, as dart2js's >> gives an unsigned 32-bit result for a negative value.
  YearMonthDay ToYearMonthDay() => YearMonthDay.NewRawValue((_value >> CalendarBits).toSigned(32));

  @override
  String toString() => '${_FormatPadded(Year, 4)}-${_FormatPadded(Month, 2)}-${_FormatPadded(Day, 2)}-${CalendarOrdinal.Name}';

  bool Equals(YearMonthDayCalendar other) => _value == other._value;

  @override
  bool operator ==(Object other) => other is YearMonthDayCalendar && Equals(other);

  @override
  int get hashCode => _value;
}

// noda_dart: new code. .NET's "0000" format.
String _FormatPadded(int value, int width) => (value < 0 ? '-' : '') + value.abs().toString().padLeft(width, '0');
