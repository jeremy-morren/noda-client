// Ported from NodaTime 6e024dde: src/NodaTime/OffsetTime.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Globalization/NodaCultureInfo.dart';
import 'LocalDate.dart';
import 'LocalTime.dart';
import 'NodaConstants.generated.dart';
import 'Offset.dart' as nt show Offset;
import 'OffsetDateTime.dart';
import 'Text/OffsetTimePattern.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Preconditions.dart';

/// A combination of a [LocalTime] and an [Offset], to represent
/// a time-of-day at a specific offset from UTC but without any date information.
///
/// Equality is defined in a component-wise fashion: two values are the same if they represent equal time-of-day values
/// and equal offsets from UTC. Ordering between offset time values is not defined.
///
/// The default value of this type is midnight with a UTC offset of zero.
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class OffsetTime {
  // noda_dart: two fields instead of C#'s packed long, as dart2js's bitwise operators are 32-bit.
  //
  // private const int NanosecondsBits = 47;
  // private const long NanosecondsMask = (1L << NanosecondsBits) - 1;
  //
  // Bottom NanosecondsBits bits are the nanosecond-of-day; top 17 bits are the offset (in seconds). This has a slight
  // execution-time cost (masking for each component) but the logical benefit of saving 4 bytes per
  // value actually ends up being 8 bytes per value on a 64-bit CLR due to alignment.
  final int _nanosecondOfDay;
  final int _offsetSeconds;

  // Constructor only used in specialist cases where we know the offset will be 0.
  @internal
  OffsetTime.NewNanosecondOfDayZeroOffset(int nanosecondOfDayZeroOffset)
      : _nanosecondOfDay = nanosecondOfDayZeroOffset,
        _offsetSeconds = 0 {
    // noda_dart: (nanosecondOfDayZeroOffset & ~NanosecondsMask) == 0, without 64-bit bitwise operators.
    Preconditions.DebugCheckArgument(nanosecondOfDayZeroOffset >= 0 && nanosecondOfDayZeroOffset < 140737488355328 /* 2^47 */,
        'nanosecondsAndOffset', 'Constructor with zero offset called with non-zero offset');
  }

  @internal
  OffsetTime.NewNanosecondOfDayOffsetSeconds(int nanosecondOfDay, int offsetSeconds)
      : _nanosecondOfDay = nanosecondOfDay,
        _offsetSeconds = offsetSeconds;

  /// Constructs an instance of the specified time and offset.
  ///
  /// [time]: The time part of the value.
  /// [offset]: The offset part of the value.
  OffsetTime(LocalTime time, nt.Offset offset) : this.NewNanosecondOfDayOffsetSeconds(time.NanosecondOfDay, offset.Seconds);

  /// Gets the time-of-day represented by this value.
  LocalTime get TimeOfDay => LocalTime.NewNanoseconds(NanosecondOfDay);

  /// Gets the offset from UTC of this value.
  nt.Offset get Offset => nt.Offset.NewSeconds(_offsetSeconds);

  /// Returns the number of seconds in the offset, without going via an Offset.
  @internal
  int get OffsetSeconds => _offsetSeconds;

  /// Returns the number of nanoseconds in the offset, without going via an Offset.
  @internal
  int get OffsetNanoseconds => _offsetSeconds * NanosecondsPerSecond;

  /// Gets the hour of day of this offset time, in the range 0 to 23 inclusive.
  int get Hour =>
      // Effectively nanoseconds / NanosecondsPerHour, but apparently rather more efficient.
      // noda_dart: divides directly, as dart2js's shifts are 32-bit.
      NanosecondOfDay ~/ NanosecondsPerHour;

  /// Gets the hour of the half-day of this offset time, in the range 1 to 12 inclusive.
  int get ClockHourOfHalfDay {
    int hourOfHalfDay = Hour.remainder(12);
    return hourOfHalfDay == 0 ? 12 : hourOfHalfDay;
  }

  /// Gets the minute of this offset time, in the range 0 to 59 inclusive.
  int get Minute {
    // Effectively NanosecondOfDay / NanosecondsPerMinute, but apparently rather more efficient.
    // noda_dart: divides directly, as dart2js's shifts are 32-bit.
    int minuteOfDay = NanosecondOfDay ~/ NanosecondsPerMinute;
    return minuteOfDay.remainder(MinutesPerHour);
  }

  /// Gets the second of this offset time within the minute, in the range 0 to 59 inclusive.
  int get Second {
    int secondOfDay = NanosecondOfDay ~/ NanosecondsPerSecond;
    return secondOfDay.remainder(SecondsPerMinute);
  }

  /// Gets the millisecond of this offset time within the second, in the range 0 to 999 inclusive.
  int get Millisecond {
    int milliSecondOfDay = NanosecondOfDay ~/ NanosecondsPerMillisecond;
    return milliSecondOfDay.remainder(MillisecondsPerSecond);
  }

  /// Gets the tick of this offset time within the second, in the range 0 to 9,999,999 inclusive.
  int get TickOfSecond => TickOfDay.remainder(TicksPerSecond);

  /// Gets the tick of this offset time within the day, in the range 0 to 863,999,999,999 inclusive.
  ///
  /// If the value does not fall on a tick boundary, it will be truncated towards zero.
  int get TickOfDay => NanosecondOfDay ~/ NanosecondsPerTick;

  /// Gets the nanosecond of this offset time within the second, in the range 0 to 999,999,999 inclusive.
  int get NanosecondOfSecond => NanosecondOfDay.remainder(NanosecondsPerSecond);

  /// Gets the nanosecond of this offset time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  int get NanosecondOfDay => _nanosecondOfDay;

  /// Creates a new [OffsetTime] for the same time-of-day, but with the specified UTC offset.
  ///
  /// [offset]: The new UTC offset.
  ///
  /// Returns a new `OffsetTime` for the same date, but with the specified UTC offset.
  OffsetTime WithOffset(nt.Offset offset) => OffsetTime(TimeOfDay, offset); // TODO: Consider using bitmasking for nanos instead.

  /// Returns this offset time-of-day, with the given date adjuster applied to it, maintaining the existing offset.
  ///
  /// If the adjuster attempts to construct an invalid time-of-day, any exception thrown by
  /// that construction attempt will be propagated through this method.
  ///
  /// [adjuster]: The adjuster to apply.
  ///
  /// Returns the adjusted offset date.
  OffsetTime With(LocalTime Function(LocalTime) adjuster) =>
      OffsetTime(TimeOfDay.With(adjuster), Offset);

  /// Combines this [OffsetTime] with the given [LocalDate]
  /// into an [OffsetDateTime].
  ///
  /// [date]: The date to combine with this time-of-day.
  ///
  /// Returns the [OffsetDateTime] representation of this time-of-day on the given date.
  OffsetDateTime On(LocalDate date) => OffsetDateTime(date.At(TimeOfDay), Offset);

  /// Returns a hash code for this offset time.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a hash code for this offset time.
  @override
  int get hashCode => HashCodeHelper.HashStatic(TimeOfDay, Offset);

  /// Compares two [OffsetTime] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare this offset time with.
  ///
  /// Returns true if the given value is another offset time equal to this one; false otherwise.
  @override
  bool operator ==(Object other) => other is OffsetTime && Equals(other);

  /// Compares two [OffsetTime] values for equality.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare this offset time with.
  ///
  /// Returns true if the given value is another offset time equal to this one; false otherwise.
  bool Equals(OffsetTime other) => TimeOfDay == other.TimeOfDay && Offset == other.Offset;

  // operator == and != (static): Dart's == above, and its !=.

  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant culture
  /// (NodaTime uses the current thread's culture).
  @override
  String toString() => OffsetTimePatternPatterns.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// (NodaTime's `ToString(string?, IFormatProvider?)`.)
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("G").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the current thread's culture to obtain a format provider.
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      OffsetTimePatternPatterns.BclSupport.Format(this, patternText, formatProvider);

  /// Deconstruct this value into its components: the [LocalTime] component and the [Offset] component.
  ///
  /// (NodaTime's `Deconstruct(out LocalTime localTime, out Offset offset)`.)
  (LocalTime, nt.Offset) get Deconstruct => (TimeOfDay, Offset);

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)
  // #endregion

  // #region JSON (noda_dart)

  /// Formats this value with [OffsetTimePattern.ExtendedIso], as NodaTime.Serialization.SystemTextJson does.
  String toJson() => OffsetTimePattern.ExtendedIso.Format(this);

  /// Parses a value written by [toJson].
  ///
  /// Throws [UnparsableValueException] if the text could not be parsed.
  factory OffsetTime.fromJson(String json) => OffsetTimePattern.ExtendedIso.Parse(json).Value;
  // #endregion
}
