// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/ZoneYearOffset.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Globalization/NodaCultureInfo.dart';
import '../LocalDate.dart';
import '../LocalInstant.dart';
import '../LocalTime.dart';
import '../NodaConstants.dart';
import '../Offset.dart';
import '../Utility/HashCodeHelper.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'TransitionMode.generated.dart';

/// Defines an offset within a year as an expression that can be used to reference multiple
/// years.
///
/// A year offset defines a way of determining an offset into a year based on certain criteria.
/// The most basic is the month of the year and the day of the month. If only these two are
/// supplied then the offset is always the same day of each year. The only exception is if the
/// day is February 29th, then it only refers to those years that have a February 29th.
///
/// If the day of the week is specified then the offset determined by the month and day are
/// adjusted to the nearest day that falls on the given day of the week. If the month and day
/// fall on that day of the week then nothing changes. Otherwise the offset is moved forward or
/// backward up to 6 days to make the day fall on the correct day of the week. The direction the
/// offset is moved is determined by the [AdvanceDayOfWeek] property.
///
/// Finally the [Mode] property determines whether the [TimeOfDay] value
/// is added to the calculated offset to generate an offset within the day.
///
/// Immutable, thread safe
@internal
final class ZoneYearOffset {
  final int _dayOfMonth;
  final int _dayOfWeek;
  final int _monthOfYear;
  final bool _addDay;

  /// Gets the method by which offsets are added to Instants to get LocalInstants.
  final TransitionMode Mode;

  /// Gets a value indicating whether [advance day of week].
  final bool AdvanceDayOfWeek;

  /// Gets the time of day when the rule takes effect.
  final LocalTime TimeOfDay;

  /// Initializes a new instance of the [ZoneYearOffset] class.
  ///
  /// [mode]: The transition mode.
  /// [monthOfYear]: The month year offset.
  /// [dayOfMonth]: The day of month. Negatives count from end of month.
  /// [dayOfWeek]: The day of week. 0 means not set.
  /// [advance]: if set to `true` [advance].
  /// [timeOfDay]: The tick within the day.
  @internal
  ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDay(
      TransitionMode mode, int monthOfYear, int dayOfMonth, int dayOfWeek, bool advance, LocalTime timeOfDay)
      : this.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
            mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, false);

  /// Initializes a new instance of the [ZoneYearOffset] class.
  ///
  /// [mode]: The transition mode.
  /// [monthOfYear]: The month year offset.
  /// [dayOfMonth]: The day of month. Negatives count from end of month.
  /// [dayOfWeek]: The day of week. 0 means not set.
  /// [advance]: if set to `true` [advance].
  /// [timeOfDay]: The time of day at which the transition occurs.
  /// [addDay]: Whether to add an extra day (for 24:00 handling).
  @internal
  ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(TransitionMode mode, int monthOfYear,
      int dayOfMonth, int dayOfWeek, bool advance, LocalTime timeOfDay, bool addDay)
      // Dart: the fields are assigned in the initializer list, and checked in the body (C# checks first; assigning
      // them has no side effects).
      : Mode = mode,
        _monthOfYear = monthOfYear,
        _dayOfMonth = dayOfMonth,
        _dayOfWeek = dayOfWeek,
        AdvanceDayOfWeek = advance,
        TimeOfDay = timeOfDay,
        _addDay = addDay {
    _VerifyFieldValue(1, 12, 'monthOfYear', monthOfYear, false);
    _VerifyFieldValue(1, 31, 'dayOfMonth', dayOfMonth, true);
    if (dayOfWeek != 0) {
      _VerifyFieldValue(1, 7, 'dayOfWeek', dayOfWeek, false);
    }
  }

  /// Verifies the input value against the valid range of the calendar field.
  ///
  /// If this becomes more widely required, move to Preconditions.
  ///
  /// [minimum]: The minimum valid value.
  /// [maximum]: The maximum valid value (inclusive).
  /// [name]: The name of the field for the error message.
  /// [value]: The value to check.
  /// [allowNegated]: if set to `true` all the range of value to be the negative as well.
  ///
  /// Throws [RangeError] If the given value is not in the valid range of the given calendar field.
  static void _VerifyFieldValue(int minimum, int maximum, String name, int value, bool allowNegated) {
    bool failed = false;
    if (allowNegated && value < 0) {
      if (value < -maximum || -minimum < value) {
        failed = true;
      }
    } else {
      if (value < minimum || maximum < value) {
        failed = true;
      }
    }
    if (failed) {
      String range = allowNegated ? '[$minimum, $maximum] or [${-maximum}, ${-minimum}]' : '[$minimum, $maximum]';
      throw RangeError.value(value, name, '$name is not in the valid range: $range');
    }
  }

  // #region IEquatable<ZoneYearOffset> Members

  /// Indicates whether the current object is equal to another object of the same type.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter; otherwise, false.
  bool Equals(ZoneYearOffset? other) {
    if (other == null) {
      return false;
    }
    if (identical(this, other)) {
      return true;
    }
    return Mode == other.Mode &&
        _monthOfYear == other._monthOfYear &&
        _dayOfMonth == other._dayOfMonth &&
        _dayOfWeek == other._dayOfWeek &&
        AdvanceDayOfWeek == other.AdvanceDayOfWeek &&
        TimeOfDay == other.TimeOfDay &&
        _addDay == other._addDay;
  }

  // #endregion

  @override
  String toString() =>
      'ZoneYearOffset[mode:${Mode.Name} monthOfYear:$_monthOfYear dayOfMonth:$_dayOfMonth dayOfWeek:$_dayOfWeek '
      'advance:${AdvanceDayOfWeek ? 'True' : 'False'} '
      'timeOfDay:${TimeOfDay.ToStringPattern('r', NodaCultureInfo.InvariantCulture)} '
      'addDay:${_addDay ? 'True' : 'False'}]';

  /// Returns the occurrence of this rule within the given year, as a LocalInstant.
  ///
  /// LocalInstant is used here so that we can use the representation of "AfterMaxValue"
  /// for December 31st 9999 24:00.
  @internal
  LocalInstant GetOccurrenceForYear(int year) {
    // unchecked
    int actualDayOfMonth =
        _dayOfMonth > 0 ? _dayOfMonth : CalendarSystem.Iso.GetDaysInMonth(year, _monthOfYear) + _dayOfMonth + 1;
    if (_monthOfYear == 2 && _dayOfMonth == 29 && !CalendarSystem.Iso.IsLeapYear(year)) {
      // In zic.c, this would result in an error if dayOfWeek is 0 or AdvanceDayOfWeek is true.
      // However, it's very convenient to be able to ask any rule for its occurrence in any year.
      // We rely on genuine rules being well-written - and before releasing an nzd file we always
      // check that it's in line with zic anyway. Ignoring the brokenness is simpler than fixing
      // rules that are only in force for a single year.
      actualDayOfMonth = 28; // We'll now look backwards for the right day-of-week.
    }
    LocalDate date = LocalDate(year, _monthOfYear, actualDayOfMonth);
    if (_dayOfWeek != 0) {
      // Optimized "go to next or previous occurrence of day or week". Try to do as few comparisons
      // as possible, and only fetch DayOfWeek once. (If we call Next or Previous, it will work it out again.)
      int currentDayOfWeek = date.DayOfWeek.value;
      if (currentDayOfWeek != _dayOfWeek) {
        int diff = _dayOfWeek - currentDayOfWeek;
        if (diff > 0) {
          if (!AdvanceDayOfWeek) {
            diff -= 7;
          }
        } else if (AdvanceDayOfWeek) {
          diff += 7;
        }
        date = date.PlusDays(diff);
      }
    }
    if (_addDay) {
      // Adding a day to the last representable day will fail, but we can return an infinite value instead.
      if (year == 9999 && date.Month == 12 && date.Day == 31) {
        return LocalInstant.AfterMaxValue;
      }
      date = date.PlusDays(1);
    }
    // Dart: date + TimeOfDay (LocalDate's + operator is its first C# overload, LocalDate + Period).
    return date.At(TimeOfDay).ToLocalInstant();
  }

  /// Writes this object to the given [IDateTimeZoneWriter].
  ///
  /// [writer]: Where to send the output.
  @internal
  void Write(IDateTimeZoneWriter writer) {
    // Flags contains four pieces of information in a single byte:
    // 0MMDDDAP:
    // - MM is the mode (0-2)
    // - DDD is the day of week (0-7)
    // - A is the AdvanceDayOfWeek
    // - P is the "addDay" (24:00) flag
    int flags = (Mode.value << 5) |
        (_dayOfWeek << 2) |
        (AdvanceDayOfWeek ? 2 : 0) |
        (_addDay ? 1 : 0);
    writer.WriteByte(flags & 0xff);
    writer.WriteCount(_monthOfYear);
    writer.WriteSignedCount(_dayOfMonth);
    // The time of day is written as a number of milliseconds historical reasons.
    writer.WriteMilliseconds(TimeOfDay.TickOfDay ~/ NodaConstants.TicksPerMillisecond);
  }

  static ZoneYearOffset Read(IDateTimeZoneReader reader) {
    // Dart: null safety checks reader.
    int flags = reader.ReadByte();
    var mode = TransitionMode(flags >> 5);
    var dayOfWeek = (flags >> 2) & 7;
    var advance = (flags & 2) != 0;
    var addDay = (flags & 1) != 0;
    int monthOfYear = reader.ReadCount();
    int dayOfMonth = reader.ReadSignedCount();
    // The time of day is written as a number of milliseconds for historical reasons.
    var timeOfDay = LocalTime.FromMillisecondsSinceMidnight(reader.ReadMilliseconds());
    return ZoneYearOffset.NewModeMonthOfYearDayOfMonthDayOfWeekAdvanceTimeOfDayAddDay(
        mode, monthOfYear, dayOfMonth, dayOfWeek, advance, timeOfDay, addDay);
  }

  /// Returns the offset to use for this rule's [TransitionMode].
  /// The year/month/day/time for a rule is in a specific frame of reference:
  /// UTC, "wall" or "standard".
  ///
  /// [standardOffset]: The standard offset.
  /// [savings]: The daylight savings adjustment.
  ///
  /// Returns the base time offset as a [Duration].
  @internal
  Offset GetRuleOffset(Offset standardOffset, Offset savings) => switch (Mode) {
        TransitionMode.Wall => standardOffset + savings,
        TransitionMode.Standard => standardOffset,
        _ => Offset.Zero
      };

  // #region Object overrides

  /// Determines whether the specified [Object] is equal to this instance.
  ///
  /// [other]: The [Object] to compare with this instance.
  ///
  /// Returns `true` if the specified [Object] is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is ZoneYearOffset && Equals(other);

  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => HashCodeHelper.Initialize()
      .Hash(Mode)
      .Hash(_monthOfYear)
      .Hash(_dayOfMonth)
      .Hash(_dayOfWeek)
      .Hash(AdvanceDayOfWeek)
      .Hash(TimeOfDay)
      .Hash(_addDay)
      .Value;
  // #endregion
}
