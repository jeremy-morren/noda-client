// noda_dart: port of dotnet/runtime's System/TimeZoneInfo.AdjustmentRule.cs.
// Copyright (c) .NET Foundation and Contributors. Licensed under the MIT license (see NOTICE.txt).

import 'package:meta/meta.dart';

import 'DateTime.dart';
import 'TimeZoneInfo.TransitionTime.dart';

const int _DaylightDeltaAdjustment = 24 * TimeSpanTicks.PerHour;
const int _MaxDaylightDelta = 12 * TimeSpanTicks.PerHour;

/// .NET's TimeZoneInfo.AdjustmentRule: a zone's rules over a range of days. The Unix-only NoDaylightTransitions kind
/// isn't ported.
final class TimeZoneInfoAdjustmentRule {
  final DateTime _dateStart;
  final DateTime _dateEnd;

  /// TimeSpan ticks.
  final int _daylightDelta;
  final TimeZoneInfoTransitionTime _daylightTransitionStart;
  final TimeZoneInfoTransitionTime _daylightTransitionEnd;

  /// TimeSpan ticks: delta from the default Utc offset (utcOffset = defaultUtcOffset + _baseUtcOffsetDelta).
  final int _baseUtcOffsetDelta;

  TimeZoneInfoAdjustmentRule._(this._dateStart, this._dateEnd, this._daylightDelta, this._daylightTransitionStart,
      this._daylightTransitionEnd, this._baseUtcOffsetDelta) {
    _ValidateAdjustmentRule(_dateStart, _dateEnd, _daylightDelta, _daylightTransitionStart, _daylightTransitionEnd);
  }

  /// The first day of the rule.
  @internal
  DateTime get DateStart => _dateStart;

  /// The last day of the rule.
  @internal
  DateTime get DateEnd => _dateEnd;

  /// The daylight saving, as TimeSpan ticks.
  @internal
  int get DaylightDelta => _daylightDelta;

  /// When daylight saving time starts each year.
  TimeZoneInfoTransitionTime get DaylightTransitionStart => _daylightTransitionStart;

  /// When daylight saving time ends each year.
  TimeZoneInfoTransitionTime get DaylightTransitionEnd => _daylightTransitionEnd;

  /// The rule's standard offset relative to the zone's base offset, as TimeSpan ticks.
  @internal
  int get BaseUtcOffsetDelta => _baseUtcOffsetDelta;

  @internal
  bool get NoDaylightTransitions => false;

  @internal
  bool get HasDaylightSaving {
    return DaylightDelta != 0 ||
        (!DaylightTransitionStart.Equals(TimeZoneInfoTransitionTime.Default) &&
            !DaylightTransitionStart.TimeOfDay.Equals(DateTime.MinValue)) ||
        (!DaylightTransitionEnd.Equals(TimeZoneInfoTransitionTime.Default) &&
            !DaylightTransitionEnd.TimeOfDay.Equals(DateTime.MinValue.AddMilliseconds(1)));
  }

  /// Whether this rule is the same as another.
  bool Equals(TimeZoneInfoAdjustmentRule? other) {
    return other != null &&
        _dateStart.Equals(other._dateStart) &&
        _dateEnd.Equals(other._dateEnd) &&
        _daylightDelta == other._daylightDelta &&
        _baseUtcOffsetDelta == other._baseUtcOffsetDelta &&
        _daylightTransitionEnd.Equals(other._daylightTransitionEnd) &&
        _daylightTransitionStart.Equals(other._daylightTransitionStart);
  }

  @override
  bool operator ==(Object other) => other is TimeZoneInfoAdjustmentRule && Equals(other);

  @override
  int get hashCode => _dateStart.hashCode;

  /// AdjustmentRule.CreateAdjustmentRule (internal overload: daylight deltas beyond ±12h go to the base offset delta).
  @internal
  static TimeZoneInfoAdjustmentRule CreateAdjustmentRule(
      DateTime dateStart,
      DateTime dateEnd,
      int daylightDelta,
      TimeZoneInfoTransitionTime daylightTransitionStart,
      TimeZoneInfoTransitionTime daylightTransitionEnd,
      [int baseUtcOffsetDelta = 0]) {
    (daylightDelta, baseUtcOffsetDelta) = _AdjustDaylightDeltaToExpectedRange(daylightDelta, baseUtcOffsetDelta);
    return TimeZoneInfoAdjustmentRule._(
        dateStart, dateEnd, daylightDelta, daylightTransitionStart, daylightTransitionEnd, baseUtcOffsetDelta);
  }

  //
  // When Windows sets the daylight transition start Jan 1st at 12:00 AM, it means the year starts with the daylight saving on.
  // We have to special case this value and not adjust it when checking if any date is in the daylight saving period.
  //
  @internal
  bool IsStartDateMarkerForBeginningOfYear() {
    return !NoDaylightTransitions &&
        DaylightTransitionStart.Month == 1 &&
        DaylightTransitionStart.Day == 1 &&
        DaylightTransitionStart.TimeOfDay.TimeOfDay < TimeSpanTicks.PerSecond; // < 12:00:01 AM
  }

  //
  // When Windows sets the daylight transition end Jan 1st at 12:00 AM, it means the year ends with the daylight saving on.
  // We have to special case this value and not adjust it when checking if any date is in the daylight saving period.
  //
  @internal
  bool IsEndDateMarkerForEndOfYear() {
    return !NoDaylightTransitions &&
        DaylightTransitionEnd.Month == 1 &&
        DaylightTransitionEnd.Day == 1 &&
        DaylightTransitionEnd.TimeOfDay.TimeOfDay < TimeSpanTicks.PerSecond; // < 12:00:01 AM
  }

  static void _ValidateAdjustmentRule(
      DateTime dateStart,
      DateTime dateEnd,
      int daylightDelta,
      TimeZoneInfoTransitionTime daylightTransitionStart,
      TimeZoneInfoTransitionTime daylightTransitionEnd) {
    // Not ported: the DateTimeKind checks (every DateTime here is Unspecified).

    if (daylightTransitionStart.Equals(daylightTransitionEnd)) {
      throw ArgumentError(
          'The DateTime parameters for the TransitionTime objects must not be identical.', 'daylightTransitionEnd');
    }

    if (dateStart.CompareTo(dateEnd) > 0) {
      throw ArgumentError('The DateStart property must come before the DateEnd property.', 'dateStart');
    }

    // This cannot use UtcOffsetOutOfRange to account for the scenario where Samoa moved across the International Date Line,
    // which caused their current BaseUtcOffset to be +13. But on the other side of the line it was UTC-11 (+1 for daylight).
    // So when trying to describe DaylightDeltas for those times, the DaylightDelta needs
    // to be -23 (what it takes to go from UTC+13 to UTC-10)
    if (daylightDelta < -23 * TimeSpanTicks.PerHour || daylightDelta > 14 * TimeSpanTicks.PerHour) {
      throw RangeError.value(
          daylightDelta, 'daylightDelta', 'The TimeSpan parameter must be within plus or minus 14.0 hours.');
    }

    if (daylightDelta.remainder(TimeSpanTicks.PerMinute) != 0) {
      throw ArgumentError(
          'The TimeSpan parameter cannot be specified more precisely than whole minutes.', 'daylightDelta');
    }

    if (!dateStart.Equals(DateTime.MinValue) && dateStart.TimeOfDay != 0) {
      throw ArgumentError('The supplied DateTime includes a TimeOfDay setting.   This is not supported.', 'dateStart');
    }

    if (!dateEnd.Equals(DateTime.MaxValue) && dateEnd.TimeOfDay != 0) {
      throw ArgumentError('The supplied DateTime includes a TimeOfDay setting.   This is not supported.', 'dateEnd');
    }
  }

  static (int, int) _AdjustDaylightDeltaToExpectedRange(int daylightDelta, int baseUtcOffsetDelta) {
    if (daylightDelta > _MaxDaylightDelta) {
      daylightDelta -= _DaylightDeltaAdjustment;
      baseUtcOffsetDelta += _DaylightDeltaAdjustment;
    } else if (daylightDelta < -_MaxDaylightDelta) {
      daylightDelta += _DaylightDeltaAdjustment;
      baseUtcOffsetDelta -= _DaylightDeltaAdjustment;
    }
    return (daylightDelta, baseUtcOffsetDelta);
  }
}
