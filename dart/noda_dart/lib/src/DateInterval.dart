// Ported from NodaTime 6e024dde: src/NodaTime/DateInterval.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'CalendarSystem.dart';
import 'LocalDate.dart';
import 'Period.dart';
import 'Text/LocalDatePattern.dart';
import 'Text/UnparsableValueException.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Preconditions.dart';

/// An interval between two dates.
///
/// Equality is defined in a component-wise fashion: two date intervals are considered equal if their start dates are
/// equal to each other and their end dates are equal to each other. Ordering between date intervals is not defined.
///
/// The two dates must be in the same calendar, and the end date must not be earlier than the start date.
///
/// The end date is deemed to be part of the range, as this matches many real life uses of
/// date ranges. For example, if someone says "I'm going to be on holiday from Monday to Friday," they
/// usually mean that Friday is part of their holiday.
///
/// Thread safety: This type is immutable reference type. See the thread safety section of the user guide for more information.
// [Immutable]
// noda_dart: C#'s IEnumerable<LocalDate>; Iterable's length and contains iterate, unlike Length and Contains.
final class DateInterval extends Iterable<LocalDate> {
  /// Gets the start date of the interval.
  final LocalDate Start;

  /// Gets the end date of the interval.
  final LocalDate End;

  /// Constructs a date interval from a start date and an end date, both of which are included
  /// in the interval.
  ///
  /// [start]: Start date of the interval
  /// [end]: End date of the interval
  ///
  /// Throws [ArgumentError] if [end] is earlier than [start]
  /// or the two dates are in different calendars.
  ///
  /// Returns a date interval between the specified dates.
  factory DateInterval(LocalDate start, LocalDate end) {
    Preconditions.CheckArgument(start.Calendar == end.Calendar, 'end',
        'Calendars of start and end dates must be the same.');
    Preconditions.CheckArgument(!(end < start), 'end', 'End date must not be earlier than the start date');
    return DateInterval._NewStartEnd(start, end);
  }

  // noda_dart: the property assignments of NodaTime's constructor (Dart's factory constructor calls this).
  DateInterval._NewStartEnd(this.Start, this.End);

  /// Returns the hash code for this interval, consistent with [Equals].
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns the hash code for this interval.
  @override
  int get hashCode =>
      HashCodeHelper.Initialize()
          .Hash(Start)
          .Hash(End)
          .Value;

  /// Compares two [DateInterval] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns true if the two date intervals have the same properties; false otherwise.
  // noda_dart: C#'s operator ==(DateInterval?, DateInterval?) and Equals(object); `!=` is Dart's.
  @override
  bool operator ==(Object other) => other is DateInterval && Equals(other);

  /// Compares the given date interval for equality with this one.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The date interval to compare this one with.
  ///
  /// Returns true if this date interval has the same same start and end date as the one specified.
  bool Equals(DateInterval? other) {
    if (identical(this, other)) {
      return true;
    }
    if (other == null) {
      return false;
    }
    return Start == other.Start && End == other.End;
  }

  // noda_dart: C#'s Equals(object) is operator ==, above.

  /// Checks whether the given date is within this date interval. This requires
  /// that the date is not earlier than the start date, and not later than the end
  /// date.
  ///
  /// [date]: The date to check for containment within this interval.
  ///
  /// Throws [ArgumentError] if [date] is not in the same
  /// calendar as the start and end date of this interval.
  ///
  /// Returns `true` if [date] is within this interval; `false` otherwise.
  bool Contains(LocalDate date) {
    Preconditions.CheckArgument(date.Calendar == Start.Calendar, 'date',
        'The date to check must be in the same calendar as the start and end dates');
    return Start <= date && date <= End;
  }

  /// Checks whether the given interval is within this interval. This requires that the start date of the specified
  /// interval is not earlier than the start date of this interval, and the end date of the specified interval is not
  /// later than the end date of this interval.
  ///
  /// An interval contains another interval with same start and end dates, or itself.
  ///
  /// [interval]: The interval to check for containment within this interval.
  ///
  /// Throws [ArgumentError] if [interval] uses a different
  /// calendar to this date interval.
  ///
  /// Returns `true` if [interval] is within this interval; `false` otherwise.
  // noda_dart: C#'s Contains(DateInterval interval).
  bool ContainsDateInterval(DateInterval interval) {
    _ValidateInterval(interval);
    return Start <= interval.Start && interval.End <= End;
  }

  /// Gets the length of this date interval in days. This will always be at least 1.
  int get Length =>
      // Period.InternalDaysBetween will give us the exclusive result, so we need to add 1
      // to include the end date.
      Period.InternalDaysBetween(Start, End) + 1;

  /// Gets the calendar system of the dates in this interval.
  CalendarSystem get Calendar => Start.Calendar;

  /// Returns a string representation of this interval.
  ///
  /// Returns a string representation of this interval, as `[start, end]`,
  /// where "start" and "end" are the dates formatted using an ISO-8601 compatible pattern.
  @override
  String toString() {
    var pattern = LocalDatePattern.Iso;
    return '[${pattern.Format(Start)}, ${pattern.Format(End)}]';
  }

  /// Deconstruct this date interval into its components: the [LocalDate] representing the start of the interval and
  /// the [LocalDate] representing the end of the interval.
  ///
  /// `final (start, end) = interval.Deconstruct;`
  // noda_dart: C#'s Deconstruct(out LocalDate start, out LocalDate end).
  (LocalDate start, LocalDate end) get Deconstruct => (Start, End);

  /// Returns the intersection between the given interval and this interval.
  ///
  /// [interval]: The specified interval to intersect with this one.
  ///
  /// Returns a [DateInterval] corresponding to the intersection between the given interval and the current
  /// instance. If there is no intersection, null is returned.
  ///
  /// Throws [ArgumentError] if [interval] uses a different
  /// calendar to this date interval.
  DateInterval? Intersection(DateInterval interval) =>
      ContainsDateInterval(interval) ? interval
          : interval.ContainsDateInterval(this) ? this
          : interval.Contains(Start) ? DateInterval(Start, interval.End)
          : interval.Contains(End) ? DateInterval(interval.Start, End)
          : null;

  /// Returns the union between the given interval and this interval, as long as they're overlapping or contiguous.
  ///
  /// [interval]: The specified interval from which to generate the union interval.
  ///
  /// Returns a [DateInterval] corresponding to the union between the given interval and the current
  /// instance, in the case the intervals overlap or are contiguous; null otherwise.
  ///
  /// Throws [ArgumentError] if [interval] uses a different calendar to this date interval.
  DateInterval? Union(DateInterval interval) {
    _ValidateInterval(interval);

    var start = LocalDate.Min(Start, interval.Start);
    var end = LocalDate.Max(End, interval.End);

    // Check whether the length of the interval we *would* construct is greater
    // than the sum of the lengths - if it is, there's a day in that candidate union
    // that isn't in either interval. Note the absence of "+ 1" and the use of >=
    // - it's equivalent to Period.InternalDaysBetween(...) + 1 > Length + interval.Length,
    // but with fewer operations.
    return Period.InternalDaysBetween(start, end) >= Length + interval.Length
        ? null
        : DateInterval(start, end);
  }

  void _ValidateInterval(DateInterval interval) {
    // Dart: null safety checks interval.
    Preconditions.CheckArgument(interval.Calendar == Start.Calendar, 'interval',
        'The specified interval uses a different calendar system to this one');
  }

  /// Returns an iterator for the dates in the interval, including both [Start] and [End].
  ///
  /// Returns an iterator for the interval.
  // noda_dart: C#'s GetEnumerator().
  @override
  Iterator<LocalDate> get iterator => _GetEnumerator().iterator;

  // noda_dart: the iterator block of C#'s GetEnumerator().
  Iterable<LocalDate> _GetEnumerator() sync* {
    // Stop when we know we've reach End, and then yield that.
    // We can't use a <= condition, as otherwise we'd try to create a date past End, which may be invalid.
    // We could use < but that's significantly less efficient than !=
    // We know that adding a day at a time we'll eventually reach End (because they're validated to be in the same calendar
    // system, with Start <= End), so that's the simplest way to go.
    for (var date = Start; date != End; date = date.PlusDays(1)) {
      yield date;
    }
    yield End;
  }

  // noda_dart: C#'s explicit IEnumerable.GetEnumerator() is covered by iterator, above.

  // #region JSON (noda_dart)
  /// Returns `{"start", "end"}` with ISO dates, as NodaTime.Serialization.SystemTextJson does.
  Map<String, Object?> toJson() => {'start': Start.toJson(), 'end': End.toJson()};

  /// Parses a value written by [toJson] (property names ignoring case), in [calendar] (default ISO).
  ///
  /// Throws [UnparsableValueException] if the value can't be parsed.
  factory DateInterval.fromJson(Map<String, Object?> json, [CalendarSystem? calendar]) {
    LocalDate? start;
    LocalDate? end;
    for (final entry in json.entries) {
      final value = entry.value;
      final lowerKey = entry.key.toLowerCase();
      if (lowerKey == 'start' && value is String) {
        start = LocalDate.fromJson(value, calendar);
      } else if (lowerKey == 'end' && value is String) {
        end = LocalDate.fromJson(value, calendar);
      }
    }
    if (start == null || end == null) {
      throw UnparsableValueException.MessageInnerException('Expected a date interval object with start and end properties.');
    }
    return DateInterval(start, end);
  }
  // #endregion
}
