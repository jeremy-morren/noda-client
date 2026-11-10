// Ported from NodaTime 6e024dde: src/NodaTime/TimeZones/ZoneRecurrence.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../CalendarSystem.dart';
import '../Calendars/GregorianYearMonthDayCalculator.dart';
import '../Instant.dart';
import '../LocalInstant.dart';
import '../Offset.dart';
import '../Utility/HashCodeHelper.dart';
import '../Utility/Int64.dart';
import '../Utility/Preconditions.dart';
import 'IO/DateTimeZoneWriter.dart';
import 'IO/IDateTimeZoneReader.dart';
import 'IO/IDateTimeZoneWriter.dart';
import 'Transition.dart';
import 'ZoneYearOffset.dart';

/// Extends [ZoneYearOffset] with a name and savings.
///
/// This represents a recurring transition from or to a daylight savings time. The name is the
/// name of the time zone during this period (e.g. PST or PDT). The savings is usually 0 or the
/// daylight offset. This is also used to support some of the tricky transitions that occurred
/// before the time zones were normalized (i.e. when they were still tightly longitude-based,
/// with multiple towns in the same country observing different times).
///
/// Immutable, thread safe.
@internal
final class ZoneRecurrence {
  late final LocalInstant _maxLocalInstant;
  late final LocalInstant _minLocalInstant;

  final String Name;
  final Offset Savings;
  final ZoneYearOffset YearOffset;
  final int FromYear;
  final int ToYear;
  bool get IsInfinite => ToYear == Int64.Int32MaxValue;

  /// Initializes a new instance of the [ZoneRecurrence] class.
  ///
  /// [name]: The name of the time zone period e.g. PST.
  /// [savings]: The savings for this period.
  /// [yearOffset]: The year offset of when this period starts in a year.
  /// [fromYear]: The first year in which this recurrence is valid
  /// [toYear]: The last year in which this recurrence is valid
  ZoneRecurrence(String name, Offset savings, ZoneYearOffset yearOffset, int fromYear, int toYear)
      // Dart: the fields are assigned in the initializer list (C# checks the arguments first; assigning them has no
      // side effects), and the local instants in the body, after the checks, as in C#.
      : Name = name,
        Savings = savings,
        YearOffset = yearOffset,
        FromYear = fromYear,
        ToYear = toYear {
    // Dart: null safety checks name and yearOffset.

    Preconditions.CheckArgument(fromYear == Int64.Int32MinValue || (fromYear >= -9998 && fromYear <= 9999), 'fromYear',
        'fromYear must be in the range [-9998, 9999] or Int32.MinValue');
    Preconditions.CheckArgument(toYear == Int64.Int32MaxValue || (toYear >= -9998 && toYear <= 9999), 'toYear',
        'toYear must be in the range [-9998, 9999] or Int32.MaxValue');
    _minLocalInstant =
        fromYear == Int64.Int32MinValue ? LocalInstant.BeforeMinValue : yearOffset.GetOccurrenceForYear(fromYear);
    _maxLocalInstant =
        toYear == Int64.Int32MaxValue ? LocalInstant.AfterMaxValue : yearOffset.GetOccurrenceForYear(toYear);
  }

  /// Returns a new recurrence which has the same values as this, but a different name.
  @internal
  ZoneRecurrence WithName(String name) => ZoneRecurrence(name, Savings, YearOffset, FromYear, ToYear);

  /// Returns a new recurrence with the same values as this, but just for a single year.
  @internal
  ZoneRecurrence ForSingleYear(int year) {
    return ZoneRecurrence(Name, Savings, YearOffset, year, year);
  }

  // #region IEquatable<ZoneRecurrence> Members
  /// Indicates whether the current object is equal to another object of the same type.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(ZoneRecurrence? other) {
    if (other == null) {
      return false;
    }
    if (identical(this, other)) {
      return true;
    }
    return Savings == other.Savings &&
        FromYear == other.FromYear &&
        ToYear == other.ToYear &&
        Name == other.Name &&
        YearOffset.Equals(other.YearOffset);
  }
  // #endregion

  /// Returns the first transition which occurs strictly after the given instant.
  ///
  /// If the given instant is before the starting year, the year of the given instant is
  /// adjusted to the beginning of the starting year. The first transition after the
  /// adjusted instant is determined. If the next adjustment is after the ending year, this
  /// method returns null; otherwise the next transition is returned.
  ///
  /// [instant]: The [Instant] lower bound for the next transition.
  /// [standardOffset]: The [Offset] standard offset.
  /// [previousSavings]: The [Offset] savings adjustment at the given Instant.
  ///
  /// Returns the next transition, or null if there is no next transition. The transition may be
  /// infinite, i.e. after the end of representable time.
  @internal
  Transition? Next(Instant instant, Offset standardOffset, Offset previousSavings) {
    Offset ruleOffset = YearOffset.GetRuleOffset(standardOffset, previousSavings);
    Offset newOffset = standardOffset + Savings;

    LocalInstant safeLocal = instant.SafePlus(ruleOffset);
    int targetYear;
    if (safeLocal < _minLocalInstant) {
      // Asked for a transition after some point before the first transition: crop to first year (so we get the first transition)
      targetYear = FromYear;
    } else if (safeLocal >= _maxLocalInstant) {
      // Asked for a transition after our final transition... or both are beyond the end of time (in which case
      // we can return an infinite transition). This branch will always be taken for transitions beyond the end
      // of time.
      return _maxLocalInstant == LocalInstant.AfterMaxValue
          ? Transition.NewInstantNewOffset(Instant.AfterMaxValue, newOffset)
          : null;
    } else if (safeLocal == LocalInstant.BeforeMinValue) {
      // We've been asked to find the next transition after some point which is a valid instant, but is before the
      // start of valid local time after applying the rule offset. For example, passing Instant.MinValue for a rule which says
      // "transition uses wall time, which is UTC-5". Proceed as if we'd been asked for something in -9998.
      // I *think* that works...
      targetYear = GregorianYearMonthDayCalculator.MinGregorianYear;
    } else {
      // Simple case: we were asked for a "normal" value in the range of years for which this recurrence is valid.
      // (Dart: GetYear's out parameter, zeroBasedDayOfYear, is the record's second value, ignored.)
      targetYear = CalendarSystem.Iso.YearMonthDayCalculator.GetYear(safeLocal.DaysSinceEpoch).$1;
    }

    LocalInstant transition = YearOffset.GetOccurrenceForYear(targetYear);

    Instant safeTransition = transition.SafeMinus(ruleOffset);
    if (safeTransition > instant) {
      return Transition.NewInstantNewOffset(safeTransition, newOffset);
    }

    // We've got a transition earlier than we were asked for. Try next year.
    // Note that this will still be within the FromYear/ToYear range, otherwise
    // safeLocal >= maxLocalInstant would have been triggered earlier.
    targetYear++;
    // Handle infinite transitions
    if (targetYear > GregorianYearMonthDayCalculator.MaxGregorianYear) {
      return Transition.NewInstantNewOffset(Instant.AfterMaxValue, newOffset);
    }
    // It's fine for this to be "end of time", and it can't be "start of time" because we're at least finding a transition in -9997.
    safeTransition = YearOffset.GetOccurrenceForYear(targetYear).SafeMinus(ruleOffset);
    return Transition.NewInstantNewOffset(safeTransition, newOffset);
  }

  /// Returns the last transition which occurs before or on the given instant.
  ///
  /// [instant]: The [Instant] lower bound for the next transition.
  /// [standardOffset]: The [Offset] standard offset.
  /// [previousSavings]: The [Offset] savings adjustment at the given Instant.
  ///
  /// Returns the previous transition, or null if there is no previous transition. The transition may be
  /// infinite, i.e. before the start of representable time.
  @internal
  Transition? PreviousOrSame(Instant instant, Offset standardOffset, Offset previousSavings) {
    Offset ruleOffset = YearOffset.GetRuleOffset(standardOffset, previousSavings);
    Offset newOffset = standardOffset + Savings;

    LocalInstant safeLocal = instant.SafePlus(ruleOffset);
    int targetYear;
    if (safeLocal > _maxLocalInstant) {
      // Asked for a transition before some point after our last year: crop to last year.
      targetYear = ToYear;
    }
    // Deliberately < here; "previous or same" means if safeLocal==minLocalInstant, we should compute it for this year.
    else if (safeLocal < _minLocalInstant) {
      // Asked for a transition before our first one
      return null;
    } else if (!safeLocal.IsValid) {
      if (safeLocal == LocalInstant.BeforeMinValue) {
        // We've been asked to find the next transition before some point which is a valid instant, but is before the
        // start of valid local time after applying the rule offset.  It's possible that the next transition *would*
        // be representable as an instant (e.g. 1pm Dec 31st -9999 with an offset of -5) but it's reasonable to
        // just return an infinite transition.
        return Transition.NewInstantNewOffset(Instant.BeforeMinValue, newOffset);
      } else {
        // We've been asked to find the next transition before some point which is a valid instant, but is after the
        // end of valid local time after applying the rule offset. For example, passing Instant.MaxValue for a rule which says
        // "transition uses wall time, which is UTC+5". Proceed as if we'd been asked for something in 9999.
        // I *think* that works...
        targetYear = GregorianYearMonthDayCalculator.MaxGregorianYear;
      }
    } else {
      // Simple case: we were asked for a "normal" value in the range of years for which this recurrence is valid.
      // (Dart: GetYear's out parameter, zeroBasedDayOfYear, is the record's second value, ignored.)
      targetYear = CalendarSystem.Iso.YearMonthDayCalculator.GetYear(safeLocal.DaysSinceEpoch).$1;
    }

    LocalInstant transition = YearOffset.GetOccurrenceForYear(targetYear);

    Instant safeTransition = transition.SafeMinus(ruleOffset);
    if (safeTransition <= instant) {
      return Transition.NewInstantNewOffset(safeTransition, newOffset);
    }

    // We've got a transition later than we were asked for. Try next year.
    // Note that this will still be within the FromYear/ToYear range, otherwise
    // safeLocal < minLocalInstant would have been triggered earlier.
    targetYear--;
    // Handle infinite transitions
    if (targetYear < GregorianYearMonthDayCalculator.MinGregorianYear) {
      return Transition.NewInstantNewOffset(Instant.BeforeMinValue, newOffset);
    }
    // It's fine for this to be "start of time", and it can't be "end of time" because we're at latest finding a transition in 9998.
    safeTransition = YearOffset.GetOccurrenceForYear(targetYear).SafeMinus(ruleOffset);
    return Transition.NewInstantNewOffset(safeTransition, newOffset);
  }

  /// Piggy-backs onto Next, but fails with an InvalidOperationException if there's no such transition.
  @internal
  Transition NextOrFail(Instant instant, Offset standardOffset, Offset previousSavings) {
    Transition? next = Next(instant, standardOffset, previousSavings);
    if (next == null) {
      throw StateError(
          'Noda Time bug or bad data: Expected a transition later than $instant; standard offset = $standardOffset; previousSavings = $previousSavings; recurrence = $this');
    }
    return next;
  }

  /// Piggy-backs onto PreviousOrSame, but fails with a descriptive InvalidOperationException if there's no such transition.
  @internal
  Transition PreviousOrSameOrFail(Instant instant, Offset standardOffset, Offset previousSavings) {
    Transition? previous = PreviousOrSame(instant, standardOffset, previousSavings);
    if (previous == null) {
      throw StateError(
          'Noda Time bug or bad data: Expected a transition earlier than $instant; standard offset = $standardOffset; previousSavings = $previousSavings; recurrence = $this');
    }
    return previous;
  }

  /// Writes this object to the given [DateTimeZoneWriter].
  ///
  /// [writer]: Where to send the output.
  @internal
  void Write(IDateTimeZoneWriter writer) {
    writer.WriteString(Name);
    writer.WriteOffset(Savings);
    YearOffset.Write(writer);
    // We'll never have time zones with recurrences between the beginning of time and 0AD,
    // so we can treat anything negative as 0, and go to the beginning of time when reading.
    writer.WriteCount(math.max(FromYear, 0));
    writer.WriteCount(ToYear);
  }

  /// Reads a recurrence from the specified reader.
  ///
  /// [reader]: The reader.
  ///
  /// Returns the recurrence read from the reader.
  static ZoneRecurrence Read(IDateTimeZoneReader reader) {
    // Dart: null safety checks reader.
    String name = reader.ReadString();
    Offset savings = reader.ReadOffset();
    ZoneYearOffset yearOffset = ZoneYearOffset.Read(reader);
    int fromYear = reader.ReadCount();
    if (fromYear == 0) {
      fromYear = Int64.Int32MinValue;
    }
    int toYear = reader.ReadCount();
    return ZoneRecurrence(name, savings, yearOffset, fromYear, toYear);
  }

  // #region Object overrides
  /// Determines whether the specified [Object] is equal to this instance.
  ///
  /// [other]: The [Object] to compare with this instance.
  ///
  /// Returns `true` if the specified [Object] is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is ZoneRecurrence && Equals(other);

  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => HashCodeHelper.HashStatic(Savings, Name, YearOffset);

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() => '$Name $Savings $YearOffset [$FromYear-$ToYear]';

  // #endregion // Object overrides

  /// Returns either "this" (if this zone recurrence already has a from year of int.MinValue)
  /// or a new zone recurrence which is identical but with a from year of int.MinValue.
  @internal
  ZoneRecurrence ToStartOfTime() =>
      FromYear == Int64.Int32MinValue ? this : ZoneRecurrence(Name, Savings, YearOffset, Int64.Int32MinValue, ToYear);
}
