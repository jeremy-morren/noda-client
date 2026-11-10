// Ported from NodaTime 6e024dde: src/NodaTime/YearMonthDay.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'CalendarOrdinal.generated.dart';
import 'CalendarSystem.dart';
import 'YearMonthDayCalendar.dart';

/// A compact representation of a year, month and day in a single 32-bit integer.
///
/// See [YearMonthDayCalendar] for the number of bits per component,
/// but this doesn't have the calendar component, so bit 0 is part of the day value.
/// This type is naive: comparisons are performed assuming that a larger month number
/// always comes after a smaller month number, etc.
/// This is suitable for most, but not all, calendar systems.
///
/// The internal representation actually uses 0 for 1 (etc) for each component.
/// That means the default value is 0001-01-01, which is reasonable for all
/// supported calendars.
@internal
final class YearMonthDay implements Comparable<YearMonthDay> {
  static const int _DayMask = (1 << YearMonthDayCalendar.DayBits) - 1;
  static const int _MonthMask = ((1 << YearMonthDayCalendar.MonthBits) - 1) << YearMonthDayCalendar.DayBits;

  final int _value;

  YearMonthDay.NewRawValue(int rawValue) : _value = rawValue;

  /// Constructs a new value for the given year, month and day. No validation is performed.
  YearMonthDay.NewYearMonthDay(int year, int month, int day)
      // unchecked: C#'s int arithmetic, wrapped to 32 bits (so the value is the same on every platform).
      : _value = (((year - 1) << (YearMonthDayCalendar.DayBits + YearMonthDayCalendar.MonthBits)) |
                ((month - 1) << YearMonthDayCalendar.DayBits) |
                (day - 1))
            .toSigned(32);

  // noda_dart: toSigned(32) after >>, as dart2js's >> gives an unsigned 32-bit result for a negative value.
  int get Year => (_value >> (YearMonthDayCalendar.DayBits + YearMonthDayCalendar.MonthBits)).toSigned(32) + 1;
  int get Month => ((_value & _MonthMask) >> YearMonthDayCalendar.DayBits) + 1;
  int get Day => (_value & _DayMask) + 1;

  // Just for testing purposes... note that this does not perform clean validation.
  static YearMonthDay Parse(String text) {
    // Handle a leading - to negate the year
    if (text[0] == '-') {
      var ymd = Parse(text.substring(1));
      return YearMonthDay.NewYearMonthDay(-ymd.Year, ymd.Month, ymd.Day);
    }

    List<String> bits = text.split('-');
    return YearMonthDay.NewYearMonthDay(
        int.parse(bits[0]),
        int.parse(bits[1]),
        int.parse(bits[2]));
  }

  @override
  String toString() => '${_FormatPadded(Year, 4)}-${_FormatPadded(Month, 2)}-${_FormatPadded(Day, 2)}';

  YearMonthDayCalendar WithCalendar(CalendarSystem? calendar) =>
      YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(_value, calendar?.Ordinal ?? CalendarOrdinal(0));

  YearMonthDayCalendar WithCalendarOrdinal(CalendarOrdinal calendarOrdinal) =>
      YearMonthDayCalendar.NewYearMonthDayCalendarOrdinal(_value, calendarOrdinal);

  @override
  int compareTo(YearMonthDay other) => _value.compareTo(other._value);

  bool Equals(YearMonthDay other) {
    return _value == other._value;
  }

  @override
  bool operator ==(Object other) => other is YearMonthDay && Equals(other);

  @override
  int get hashCode => _value;

  bool operator <(YearMonthDay rhs) => _value < rhs._value;

  bool operator <=(YearMonthDay rhs) => _value <= rhs._value;

  bool operator >(YearMonthDay rhs) => _value > rhs._value;

  bool operator >=(YearMonthDay rhs) => _value >= rhs._value;
}

// noda_dart: new code. .NET's "0000" format.
String _FormatPadded(int value, int width) => (value < 0 ? '-' : '') + value.abs().toString().padLeft(width, '0');
