// Ported from NodaTime 6e024dde: src/NodaTime/ZonedDateTime.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:meta/meta.dart';

import 'CalendarSystem.dart';
import 'Calendars/Era.dart' as nt show Era;
import 'DateTimeZone.dart';
import 'Duration.dart';
import 'Globalization/NodaCultureInfo.dart';
import 'IDateTimeZoneProvider.dart';
import 'Instant.dart';
import 'IsoDayOfWeek.generated.dart';
import 'LocalDate.dart';
import 'LocalDateTime.dart' as nt show LocalDateTime;
import 'LocalTime.dart';
import 'Offset.dart' as nt show Offset;
import 'OffsetDateTime.dart';
import 'Text/ZonedDateTimePattern.dart';
import 'TimeZones/ZoneInterval.dart';
import 'Utility/Comparers.dart';
import 'Utility/HashCodeHelper.dart';

// Do not nest type X.
// The rule is somewhat subjective, but more importantly these have been available
// publicly for a while, so we can't change them now anyway.

// noda_dart: new code (JSON).
/// The pattern NodaTime.Serialization.SystemTextJson uses for ZonedDateTime values.
const String _JsonPatternText = "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFFo<G> z";
final ZonedDateTimePattern _JsonFormatPattern = ZonedDateTimePattern.CreateWithInvariantCulture(_JsonPatternText, null);

// Note: documentation that refers to the LocalDateTime type within this class must use the fully-qualified
// reference to avoid being resolved to the LocalDateTime property instead.

/// A `LocalDateTime` in a specific time zone and with a particular offset to distinguish
/// between otherwise-ambiguous instants. A [ZonedDateTime] is global, in that it maps to a single
/// [Instant].
///
/// Although [ZonedDateTime] includes both local and global concepts, it only supports
/// duration-based - and not calendar-based - arithmetic. This avoids ambiguities
/// and skipped date/time values becoming a problem within a series of calculations; instead,
/// these can be considered just once, at the point of conversion to a [ZonedDateTime].
///
/// `ZonedDateTime` does not implement ordered comparison operators, as there is no obvious natural ordering that works in all cases.
/// Equality is supported however, requiring equality of zone, calendar and date/time. If you want to sort `ZonedDateTime`
/// values, you should explicitly choose one of the orderings provided via the static properties in the
/// [ZonedDateTimeComparer] class (or implement your own comparison).
///
/// The default value of this type is 0001-01-01T00:00:00Z (midnight on January 1st, 1 C.E.) in the ISO calendar and the UTC time zone.
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class ZonedDateTime {
  final OffsetDateTime _offsetDateTime;
  final DateTimeZone _zone;

  /// Internal constructor from pre-validated values.
  @internal
  ZonedDateTime.NewOffsetDateTimeZone(OffsetDateTime offsetDateTime, DateTimeZone zone)
      : _offsetDateTime = offsetDateTime,
        _zone = zone;

  /// Initializes a new instance of the [ZonedDateTime] struct.
  ///
  /// Without [calendar], the ISO calendar is used.
  ///
  /// [instant]: The instant.
  /// [zone]: The time zone.
  /// [calendar]: The calendar system.
  ZonedDateTime(Instant instant, DateTimeZone zone, [CalendarSystem? calendar])
      // Dart: null safety checks zone.
      : _zone = zone,
        _offsetDateTime = calendar == null
            ? OffsetDateTime.NewInstantOffset(instant, zone.GetUtcOffset(instant))
            : OffsetDateTime.NewInstantOffsetCalendar(instant, zone.GetUtcOffset(instant), calendar);

  /// Initializes a new instance of the [ZonedDateTime] struct in the specified time zone
  /// from a given local time and offset. The offset is validated to be correct as part of initialization.
  /// In most cases a local time can only map to a single instant anyway, but the offset is included here for cases
  /// where the local time is ambiguous, usually due to daylight saving transitions.
  ///
  /// [localDateTime]: The local date and time.
  /// [zone]: The time zone.
  /// [offset]: The offset between UTC and local time at the desired instant.
  ///
  /// Throws [ArgumentError] if [offset] is not a valid offset at the given
  /// local date and time.
  factory ZonedDateTime.LocalDateTimeZoneOffset(nt.LocalDateTime localDateTime, DateTimeZone zone, nt.Offset offset) {
    // Dart: null safety checks zone.
    Instant candidateInstant = localDateTime.ToLocalInstant().Minus(offset);
    nt.Offset correctOffset = zone.GetUtcOffset(candidateInstant);
    // Not using Preconditions, to avoid building the string unnecessarily.
    if (correctOffset != offset) {
      throw ArgumentError('Offset $offset is invalid for local date and time $localDateTime in time zone ${zone.Id}', 'offset');
    }
    return ZonedDateTime.NewOffsetDateTimeZone(OffsetDateTime(localDateTime, offset), zone);
  }

  /// Gets the offset of the local representation of this value from UTC.
  nt.Offset get Offset => _offsetDateTime.Offset;

  /// Gets the time zone associated with this value.
  // noda_dart: C#'s `zone ?? DateTimeZone.Utc` is for default(ZonedDateTime); every Dart value has a zone.
  DateTimeZone get Zone => _zone;

  /// Gets the local date and time represented by this zoned date and time.
  ///
  /// The returned
  /// `LocalDateTime` will have the same calendar system and return the same values for
  /// each of the calendar properties (Year, MonthOfYear and so on), but will not be associated with any
  /// particular time zone.
  nt.LocalDateTime get LocalDateTime => _offsetDateTime.LocalDateTime;

  /// Gets the calendar system associated with this zoned date and time.
  CalendarSystem get Calendar => _offsetDateTime.Calendar;

  /// Gets the local date represented by this zoned date and time.
  ///
  /// The returned [LocalDate]
  /// will have the same calendar system and return the same values for each of the date-based calendar
  /// properties (Year, MonthOfYear and so on), but will not be associated with any particular time zone.
  LocalDate get Date => _offsetDateTime.Date;

  /// Gets the time portion of this zoned date and time.
  ///
  /// The returned [LocalTime] will
  /// return the same values for each of the time-based properties (Hour, Minute and so on), but
  /// will not be associated with any particular time zone.
  LocalTime get TimeOfDay => _offsetDateTime.TimeOfDay;

  /// Gets the era for this zoned date and time.
  nt.Era get Era => _offsetDateTime.Era;

  /// Gets the year of this zoned date and time.
  ///
  /// This returns the "absolute year", so, for the ISO calendar,
  /// a value of 0 means 1 BC, for example.
  int get Year => _offsetDateTime.Year;

  /// Gets the year of this zoned date and time within its era.
  int get YearOfEra => _offsetDateTime.YearOfEra;

  /// Gets the month of this zoned date and time within the year.
  int get Month => _offsetDateTime.Month;

  /// Gets the day of this zoned date and time within the year.
  int get DayOfYear => _offsetDateTime.DayOfYear;

  /// Gets the day of this zoned date and time within the month.
  int get Day => _offsetDateTime.Day;

  /// Gets the week day of this zoned date and time expressed as an [IsoDayOfWeek] value.
  IsoDayOfWeek get DayOfWeek => _offsetDateTime.DayOfWeek;

  /// Gets the hour of day of this zoned date and time, in the range 0 to 23 inclusive.
  int get Hour => _offsetDateTime.Hour;

  /// Gets the hour of the half-day of this zoned date and time, in the range 1 to 12 inclusive.
  int get ClockHourOfHalfDay => _offsetDateTime.ClockHourOfHalfDay;

  /// Gets the minute of this zoned date and time, in the range 0 to 59 inclusive.
  int get Minute => _offsetDateTime.Minute;

  /// Gets the second of this zoned date and time within the minute, in the range 0 to 59 inclusive.
  int get Second => _offsetDateTime.Second;

  /// Gets the millisecond of this zoned date and time within the second, in the range 0 to 999 inclusive.
  int get Millisecond => _offsetDateTime.Millisecond;

  /// Gets the tick of this zoned date and time within the second, in the range 0 to 9,999,999 inclusive.
  int get TickOfSecond => _offsetDateTime.TickOfSecond;

  /// Gets the tick of this zoned date and time within the day, in the range 0 to 863,999,999,999 inclusive.
  ///
  /// This is the TickOfDay portion of the contained [OffsetDateTime].
  /// On daylight saving time transition dates, it may not be the same as the number of ticks elapsed since the beginning of the day.
  int get TickOfDay => _offsetDateTime.TickOfDay;

  /// Gets the nanosecond of this zoned date and time within the second, in the range 0 to 999,999,999 inclusive.
  int get NanosecondOfSecond => _offsetDateTime.NanosecondOfSecond;

  /// Gets the nanosecond of this zoned date and time within the day, in the range 0 to 86,399,999,999,999 inclusive.
  ///
  /// This is the NanosecondOfDay portion of the contained [OffsetDateTime].
  /// On daylight saving time transition dates, it may not be the same as the number of nanoseconds elapsed since the beginning of the day.
  int get NanosecondOfDay => _offsetDateTime.NanosecondOfDay;

  /// Converts this value to the instant it represents on the time line.
  ///
  /// This is always an unambiguous conversion. Any difficulties due to daylight saving
  /// transitions or other changes in time zone are handled when converting from a
  /// `LocalDateTime` to a [ZonedDateTime]; the `ZonedDateTime` remembers
  /// the actual offset from UTC to local time, so it always knows the exact instant represented.
  ///
  /// Returns the instant corresponding to this value.
  Instant ToInstant() => _offsetDateTime.ToInstant();

  /// Creates a new [ZonedDateTime] representing the same instant in time, in the
  /// same calendar but a different time zone.
  ///
  /// [targetZone]: The target time zone to convert to.
  ///
  /// Returns a new value in the target time zone.
  ZonedDateTime WithZone(DateTimeZone targetZone) {
    // Dart: null safety checks targetZone.
    return ZonedDateTime(ToInstant(), targetZone, Calendar);
  }

  /// Creates a new ZonedDateTime representing the same physical date, time and offset, but in a different calendar.
  /// The returned ZonedDateTime is likely to have different date field values to this one.
  /// For example, January 1st 1970 in the Gregorian calendar was December 19th 1969 in the Julian calendar.
  ///
  /// [calendar]: The calendar system to convert this zoned date and time to.
  ///
  /// Returns the converted ZonedDateTime.
  ZonedDateTime WithCalendar(CalendarSystem calendar) {
    return ZonedDateTime.NewOffsetDateTimeZone(_offsetDateTime.WithCalendar(calendar), _zone);
  }

  // #region Equality
  /// Indicates whether the current object is equal to another object of the same type.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the specified value is the same instant in the same time zone; false otherwise.
  bool Equals(ZonedDateTime other) => _offsetDateTime == other._offsetDateTime && Zone == other.Zone;

  /// Indicates whether this instance and a specified object are equal.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: Another object to compare to.
  ///
  /// Returns true if the specified value is a [ZonedDateTime] representing the same instant in the same time zone; false otherwise.
  @override
  bool operator ==(Object other) => other is ZonedDateTime && Equals(other);

  /// Computes the hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a 32-bit signed integer that is the hash code for this instance.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_offsetDateTime, Zone);
  // #endregion

  // #region Operators
  // operator == / !=: see Equality above (Dart's `==`, and its `!=`).

  /// Adds a duration to a zoned date and time.
  ///
  /// This is an alternative way of calling `operator +`.
  ///
  /// [zonedDateTime]: The value to add the duration to.
  /// [duration]: The duration to add
  ///
  /// Returns a new value with the time advanced by the given duration, in the same calendar system and time zone.
  static ZonedDateTime Add(ZonedDateTime zonedDateTime, Duration duration) => zonedDateTime + duration;

  /// Returns the result of adding a duration to this zoned date and time.
  ///
  /// This is an alternative way of calling `operator +`.
  ///
  /// [duration]: The duration to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime Plus(Duration duration) => this + duration;

  /// Returns the result of adding a increment of hours to this zoned date and time
  ///
  /// [hours]: The number of hours to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusHours(int hours) => this + Duration.FromHours(hours);

  /// Returns the result of adding an increment of minutes to this zoned date and time
  ///
  /// [minutes]: The number of minutes to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusMinutes(int minutes) => this + Duration.FromMinutes(minutes);

  /// Returns the result of adding an increment of seconds to this zoned date and time
  ///
  /// [seconds]: The number of seconds to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusSeconds(int seconds) => this + Duration.FromSeconds(seconds);

  /// Returns the result of adding an increment of milliseconds to this zoned date and time
  ///
  /// [milliseconds]: The number of milliseconds to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusMilliseconds(int milliseconds) => this + Duration.FromMilliseconds(milliseconds);

  /// Returns the result of adding an increment of ticks to this zoned date and time
  ///
  /// [ticks]: The number of ticks to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusTicks(int ticks) => this + Duration.FromTicks(ticks);

  /// Returns the result of adding an increment of nanoseconds to this zoned date and time
  ///
  /// [nanoseconds]: The number of nanoseconds to add
  ///
  /// Returns a new [ZonedDateTime] representing the result of the addition.
  ZonedDateTime PlusNanoseconds(int nanoseconds) => this + Duration.FromNanoseconds(nanoseconds);

  /// Returns a new [ZonedDateTime] with the time advanced by the given duration. Note that
  /// due to daylight saving time changes this may not advance the local time by the same amount.
  ///
  /// The returned value retains the calendar system and time zone of this value.
  ///
  /// [duration]: The duration to add.
  ///
  /// Returns a new value with the time advanced by the given duration, in the same calendar system and time zone.
  ZonedDateTime operator +(Duration duration) => ZonedDateTime(ToInstant() + duration, Zone, Calendar);

  /// Subtracts a duration from a zoned date and time.
  ///
  /// This is an alternative way of calling `operator -`.
  ///
  /// [zonedDateTime]: The value to subtract the duration from.
  /// [duration]: The duration to subtract.
  ///
  /// Returns a new value with the time "rewound" by the given duration, in the same calendar system and time zone.
  static ZonedDateTime Subtract(ZonedDateTime zonedDateTime, Duration duration) => zonedDateTime - duration;

  /// Returns the result of subtracting a duration from this zoned date and time, for a fluent alternative to
  /// `operator -`
  ///
  /// [duration]: The duration to subtract
  ///
  /// Returns a new [ZonedDateTime] representing the result of the subtraction.
  ZonedDateTime Minus(Duration duration) => this - duration;

  /// Returns a new [ZonedDateTime] with the duration subtracted. Note that
  /// due to daylight saving time changes this may not change the local time by the same amount.
  ///
  /// The returned value retains the calendar system and time zone of this value.
  ///
  /// [duration]: The duration to subtract.
  ///
  /// Returns a new value with the time "rewound" by the given duration, in the same calendar system and time zone.
  ZonedDateTime operator -(Duration duration) => ZonedDateTime(ToInstant().MinusDuration(duration), Zone, Calendar);

  /// Subtracts one zoned date and time from another, returning an elapsed duration.
  ///
  /// This is an alternative way of calling [MinusZonedDateTime].
  ///
  /// [end]: The zoned date and time value to subtract from; if this is later than [start]
  /// then the result will be positive.
  /// [start]: The zoned date and time to subtract from [end].
  ///
  /// Returns the elapsed duration from [start] to [end].
  static Duration SubtractZonedDateTime(ZonedDateTime end, ZonedDateTime start) => end.MinusZonedDateTime(start);

  /// Returns the result of subtracting another zoned date and time from this one, resulting in the elapsed duration
  /// between the two instants represented in the values.
  ///
  /// This is equivalent to `end.ToInstant() - start.ToInstant()`; in particular:
  /// - The two values can use different calendar systems
  /// - The two values can be in different time zones
  /// - The two values can have different UTC offsets
  ///
  /// [other]: The zoned date and time to subtract from this one.
  ///
  /// Returns the elapsed duration from [other] to this value.
  Duration MinusZonedDateTime(ZonedDateTime other) => ToInstant() - other.ToInstant();
  // #endregion

  /// Returns the [ZoneInterval] containing this value, in the time zone this
  /// value refers to.
  ///
  /// This is simply a convenience method - it is logically equivalent to converting this
  /// value to an [Instant] and then asking the appropriate [DateTimeZone]
  /// for the `ZoneInterval` containing that instant.
  ///
  /// Returns the `ZoneInterval` containing this value.
  ZoneInterval GetZoneInterval() => Zone.GetZoneInterval(ToInstant());

  /// Indicates whether or not this [ZonedDateTime] is in daylight saving time
  /// for its time zone. This is determined by checking the [ZoneInterval.Savings] property
  /// of the zone interval containing this value.
  ///
  /// See also [GetZoneInterval].
  ///
  /// Returns `true` if the zone interval containing this value has a non-zero savings
  /// component; `false` otherwise.
  bool IsDaylightSavingTime() => GetZoneInterval().Savings != nt.Offset.Zero;

  // #region Formatting
  /// Returns a [String] that represents this instance.
  ///
  /// Returns the value of the current instance in the default format pattern ("G"), using the invariant
  /// culture. (NodaTime uses the current thread's culture.)
  @override
  String toString() => ZonedDateTimePatternPatterns.BclSupport.Format(this, null, NodaCultureInfo.InvariantCulture);

  /// Formats the value of the current instance using the specified pattern.
  ///
  /// [patternText]: The [String] specifying the pattern to use,
  /// or null to use the default format pattern ("G").
  /// [formatProvider]: The [IFormatProvider] to use when formatting the value,
  /// or null to use the invariant culture. (NodaTime uses the current thread's culture.)
  ///
  /// Returns a [String] containing the value of the current instance in the specified format.
  String ToStringPattern(String? patternText, [IFormatProvider? formatProvider]) =>
      ZonedDateTimePatternPatterns.BclSupport.Format(this, patternText, formatProvider ?? NodaCultureInfo.InvariantCulture);
  // #endregion Formatting

  // Not ported: ToDateTimeOffset() (no DateTimeOffset in Dart)

  // Not ported: FromDateTimeOffset(DateTimeOffset) (no DateTimeOffset in Dart)

  /// Constructs a [core.DateTime] from this [ZonedDateTime] which is UTC (`isUtc`, .NET's
  /// `DateTimeKind.Utc`) and represents the same instant of time as this value rather than the same local time.
  ///
  /// If the date and time is not on a microsecond boundary (the unit of granularity of Dart's DateTime) the value
  /// will be truncated towards the start of time.
  ///
  /// Throws [StateError] if the final date/time is outside the range of `DateTime`.
  ///
  /// Returns a [core.DateTime] representation of this value with a "universal" kind, with the same
  /// instant of time as this value.
  core.DateTime ToDateTimeUtc() => ToInstant().ToDateTimeUtc();

  /// Constructs a [core.DateTime] from this [ZonedDateTime] which has the same local time as
  /// this value rather than the same instant in time (.NET's `DateTimeKind.Unspecified`; see
  /// `LocalDateTime.ToDateTimeUnspecified`).
  ///
  /// If the date and time is not on a microsecond boundary (the unit of granularity of Dart's DateTime) the value
  /// will be truncated towards the start of time.
  ///
  /// `DateTime` uses the Gregorian calendar by definition, so the value is implicitly converted
  /// to the Gregorian calendar first. The result will be on the same physical date,
  /// but the values returned by the Year/Month/Day properties of the `DateTime` may not
  /// match the Year/Month/Day properties of this value.
  ///
  /// Throws [StateError] if the date/time is outside the range of `DateTime`.
  ///
  /// Returns a [core.DateTime] representation of this value with an "unspecified" kind, with the same
  /// local date and time as this value.
  core.DateTime ToDateTimeUnspecified() => LocalDateTime.ToDateTimeUnspecified();

  /// Constructs an [OffsetDateTime] with the same local date and time, and the same offset
  /// as this zoned date and time, effectively just "removing" the time zone itself.
  ///
  /// Returns an OffsetDateTime with the same local date/time and offset as this value.
  OffsetDateTime ToOffsetDateTime() => _offsetDateTime;

  /// Deconstruct this [ZonedDateTime] into its components: the `LocalDateTime`, the [DateTimeZone] and the
  /// `Offset` (`final (localDateTime, dateTimeZone, offset) = value.Deconstruct;`).
  (nt.LocalDateTime, DateTimeZone, nt.Offset) get Deconstruct => (LocalDateTime, Zone, Offset);

  // Comparers: see ZonedDateTimeComparer below.

  // Not ported: AddSchema, IXmlSerializable.GetSchema/ReadXml/WriteXml (XML serialization)

  // #region JSON
  // noda_dart: new code.
  /// Formats this value as NodaTime.Serialization.SystemTextJson does.
  String toJson() => _JsonFormatPattern.Format(this);

  /// Parses a value written by [toJson], with zones from [provider], in [calendar] (default ISO).
  ///
  /// Throws `UnparsableValueException` if the text could not be parsed.
  factory ZonedDateTime.fromJson(String json, IDateTimeZoneProvider provider, [CalendarSystem? calendar]) {
    final pattern = ZonedDateTimePattern.CreateWithInvariantCulture(_JsonPatternText, provider);
    return (calendar == null ? pattern : pattern.WithCalendar(calendar)).Parse(json).Value;
  }
  // #endregion
}

// #region Comparers
/// Base class for [ZonedDateTime] comparers (C#'s nested `ZonedDateTime.Comparer`).
///
/// Use the static properties of this class to obtain instances. This type is exposed so that the
/// same value can be used for both equality and ordering comparisons.
abstract class ZonedDateTimeComparer implements IComparer<ZonedDateTime>, IEqualityComparer<ZonedDateTime> {
  // TODO(feature): A comparer which compares instants, but in a calendar-sensitive manner?

  /// Gets a comparer which compares [ZonedDateTime] values by their local date/time, without reference to
  /// the time zone or offset. Comparisons between two values of different calendar systems will fail with [ArgumentError].
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00 (Europe/London) to be later than
  /// 2013-03-04T19:21:00 (America/Los_Angeles) even though the second value represents a later instant in time.
  ///
  /// This property will return a reference to the same instance every time it is called.
  static ZonedDateTimeComparer get Local => _ZonedDateTimeLocalComparer.Instance;

  /// Gets a comparer which compares [ZonedDateTime] values by the instants obtained by applying the offset to
  /// the local date/time, ignoring the calendar system.
  ///
  /// For example, this comparer considers 2013-03-04T20:21:00 (Europe/London) to be earlier than
  /// 2013-03-04T19:21:00 (America/Los_Angeles) even though the second value has a local time which is earlier; the time zones
  /// mean that the first value occurred earlier in the universal time line.
  ///
  /// This property will return a reference to the same instance every time it is called.
  static ZonedDateTimeComparer get Instant => _ZonedDateTimeInstantComparer.Instance;

  /// Internal constructor to prevent external classes from deriving from this.
  /// (That means we can add more abstract members in the future.)
  @internal
  ZonedDateTimeComparer.New();

  /// Compares two [ZonedDateTime] values and returns a value indicating whether one is less than, equal to, or greater than the other.
  ///
  /// [x]: The first value to compare.
  /// [y]: The second value to compare.
  ///
  /// Returns a signed integer that indicates the relative values of [x] and [y]: less than zero if [x] is less
  /// than [y]; zero if [x] equals [y]; greater than zero if [x] is greater than [y].
  @override
  int Compare(ZonedDateTime x, ZonedDateTime y);

  /// Determines whether the specified `ZonedDateTime` values are equal.
  ///
  /// [x]: The first `ZonedDateTime` to compare.
  /// [y]: The second `ZonedDateTime` to compare.
  ///
  /// Returns `true` if the specified objects are equal; otherwise, `false`.
  @override
  bool Equals(ZonedDateTime x, ZonedDateTime y);

  /// Returns a hash code for the specified `ZonedDateTime`.
  ///
  /// [obj]: The `ZonedDateTime` for which a hash code is to be returned.
  ///
  /// Returns a hash code for the specified value.
  @override
  int GetHashCode(ZonedDateTime obj);
}

/// Implementation for [ZonedDateTimeComparer.Local].
final class _ZonedDateTimeLocalComparer extends ZonedDateTimeComparer {
  static final ZonedDateTimeComparer Instance = _ZonedDateTimeLocalComparer._New();

  _ZonedDateTimeLocalComparer._New() : super.New();

  @override
  int Compare(ZonedDateTime x, ZonedDateTime y) => OffsetDateTimeComparer.Local.Compare(x._offsetDateTime, y._offsetDateTime);

  @override
  bool Equals(ZonedDateTime x, ZonedDateTime y) => OffsetDateTimeComparer.Local.Equals(x._offsetDateTime, y._offsetDateTime);

  @override
  int GetHashCode(ZonedDateTime obj) => OffsetDateTimeComparer.Local.GetHashCode(obj._offsetDateTime);
}

/// Implementation for [ZonedDateTimeComparer.Instant].
final class _ZonedDateTimeInstantComparer extends ZonedDateTimeComparer {
  static final ZonedDateTimeComparer Instance = _ZonedDateTimeInstantComparer._New();

  _ZonedDateTimeInstantComparer._New() : super.New();

  @override
  int Compare(ZonedDateTime x, ZonedDateTime y) => OffsetDateTimeComparer.Instant.Compare(x._offsetDateTime, y._offsetDateTime);

  @override
  bool Equals(ZonedDateTime x, ZonedDateTime y) => OffsetDateTimeComparer.Instant.Equals(x._offsetDateTime, y._offsetDateTime);

  @override
  int GetHashCode(ZonedDateTime obj) => OffsetDateTimeComparer.Instant.GetHashCode(obj._offsetDateTime);
}
// #endregion
