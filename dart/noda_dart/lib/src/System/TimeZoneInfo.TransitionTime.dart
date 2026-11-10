// noda_dart: port of dotnet/runtime's System/TimeZoneInfo.TransitionTime.cs.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).

import 'package:meta/meta.dart';

import 'DateTime.dart';

/// .NET's TimeZoneInfo.TransitionTime: a fixed ("1 January") or floating ("last Sunday in October") DST transition.
final class TimeZoneInfoTransitionTime {
  final DateTime _timeOfDay;
  final int _month;
  final int _week;
  final int _day;
  final int _dayOfWeek;
  final bool _isFixedDateRule;

  const TimeZoneInfoTransitionTime._(
      this._timeOfDay, this._month, this._week, this._day, this._dayOfWeek, this._isFixedDateRule);

  /// The time of day of the transition: a DateTime on 0001-01-01.
  @internal
  DateTime get TimeOfDay => _timeOfDay;

  /// The month of the transition, 1-12 (0 for the default value).
  int get Month => _month;

  /// For a floating rule, the week of the month, 1-5 (5: the last).
  int get Week => _week;

  /// For a fixed rule, the day of the month.
  int get Day => _day;

  /// For a floating rule, the day of the week (System.DayOfWeek: 0 for Sunday to 6 for Saturday).
  int get DayOfWeek => _dayOfWeek;

  /// Whether the transition is on a fixed date (rather than a floating one).
  bool get IsFixedDateRule => _isFixedDateRule;

  /// default(TransitionTime): every field zero.
  @internal
  static const TimeZoneInfoTransitionTime Default = TimeZoneInfoTransitionTime._(DateTime.MinValue, 0, 0, 0, 0, false);

  /// Whether this is the same transition as another.
  bool Equals(TimeZoneInfoTransitionTime other) {
    return _isFixedDateRule == other._isFixedDateRule &&
        _timeOfDay.Equals(other._timeOfDay) &&
        _month == other._month &&
        (other._isFixedDateRule
            ? _day == other._day
            : _week == other._week && _dayOfWeek == other._dayOfWeek);
  }

  @override
  bool operator ==(Object other) => other is TimeZoneInfoTransitionTime && Equals(other);

  @override
  int get hashCode => _month ^ _week << 8;

  /// TransitionTime.CreateFixedDateRule.
  @internal
  static TimeZoneInfoTransitionTime CreateFixedDateRule(DateTime timeOfDay, int month, int day) {
    return _Create(timeOfDay, month, 1, day, 0, true);
  }

  /// TransitionTime.CreateFloatingDateRule.
  @internal
  static TimeZoneInfoTransitionTime CreateFloatingDateRule(DateTime timeOfDay, int month, int week, int dayOfWeek) {
    return _Create(timeOfDay, month, week, 1, dayOfWeek, false);
  }

  static TimeZoneInfoTransitionTime _Create(
      DateTime timeOfDay, int month, int week, int day, int dayOfWeek, bool isFixedDateRule) {
    _ValidateTransitionTime(timeOfDay, month, week, day, dayOfWeek);
    return TimeZoneInfoTransitionTime._(timeOfDay, month, week, day, dayOfWeek, isFixedDateRule);
  }

  static void _ValidateTransitionTime(DateTime timeOfDay, int month, int week, int day, int dayOfWeek) {
    // Not ported: the DateTimeKind check (every DateTime here is Unspecified).

    // Month range 1-12
    if (month < 1 || month > 12) {
      throw RangeError.value(month, 'month', 'Month must be between one and twelve.');
    }

    // Day range 1-31
    if (day < 1 || day > 31) {
      throw RangeError.value(day, 'day', 'Day must be between 1 and 31.');
    }

    // Week range 1-5
    if (week < 1 || week > 5) {
      throw RangeError.value(week, 'week', 'The Week parameter must be in the range 1 through 5.');
    }

    // DayOfWeek range 0-6
    if (dayOfWeek < 0 || dayOfWeek > 6) {
      throw RangeError.value(dayOfWeek, 'dayOfWeek', 'The DayOfWeek enumeration must be in the range 0 through 6.');
    }

    if (timeOfDay.Days != 0 || timeOfDay.TickOfDay % TimeSpanTicks.PerMillisecond != 0) {
      throw ArgumentError(
          'The supplied DateTime must have the Year, Month, and Day properties set to 1.  The time cannot be specified more precisely than whole milliseconds.',
          'timeOfDay');
    }
  }
}
