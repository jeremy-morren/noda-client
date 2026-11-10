// Ported from NodaTime 6e024dde: src/NodaTime/Interval.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import 'Duration.dart' as nt show Duration;
import 'Instant.dart';
import 'Text/InstantPattern.dart';
import 'Utility/HashCodeHelper.dart';
import 'Utility/Preconditions.dart';

/// An interval between two instants in time (start and end).
///
/// Equality is defined in a component-wise fashion: two intervals are considered equal if their start instants are
/// equal to each other and their end instants are equal to each other. Ordering between intervals is not defined.
///
/// The interval includes the start instant and excludes the end instant. However, an interval
/// may be missing its start or end, in which case the interval is deemed to be infinite in that
/// direction.
///
/// The end may equal the start (resulting in an empty interval), but will not be before the start.
///
/// The default value of this type is an empty interval with a start and end of
/// [NodaConstants.UnixEpoch].
///
/// This type is an immutable value type. See the thread safety section of the user guide for more information.
final class Interval {
  /// The start of the interval.
  final Instant _start;

  /// The end of the interval. This will never be earlier than the start.
  final Instant _end;

  /// Initializes a new instance of the [Interval] struct from two nullable [Instant]
  /// values.
  ///
  /// (C#'s `Interval(Instant, Instant)` and `Interval(Instant?, Instant?)`.)
  ///
  /// The interval includes the [start] instant and excludes the
  /// [end] instant. The end may equal the start (resulting in an empty interval), but must not be before the start.
  ///
  /// If the start is null, the interval is deemed to stretch to the start of time. If the end is null,
  /// the interval is deemed to stretch to the end of time.
  ///
  /// Throws [RangeError] if [end] is earlier than [start],
  /// if they are both non-null.
  ///
  /// [start]: The start [Instant] or null.
  /// [end]: The end [Instant] or null.
  Interval(Instant? start, Instant? end)
      : _start = start ?? Instant.BeforeMinValue,
        _end = end ?? Instant.AfterMaxValue {
    if (start != null && end != null && end < start) {
      throw RangeError("The end parameter must be equal to or later than the start parameter (Parameter 'end')");
    }
  }

  /// Gets the start instant - the inclusive lower bound of the interval.
  ///
  /// This will never be later than [End], though it may be equal to it.
  ///
  /// Throws [StateError] if the interval extends to the start of time.
  ///
  /// See also [HasStart].
  Instant get Start {
    Preconditions.CheckState(_start.IsValid, 'Interval extends to start of time');
    return _start;
  }

  /// Returns `true` if this interval has a fixed start point, or `false` if it
  /// extends to the start of time.
  bool get HasStart => _start.IsValid;

  /// Gets the end instant - the exclusive upper bound of the interval.
  ///
  /// Throws [StateError] if the interval extends to the end of time.
  ///
  /// See also [HasEnd].
  Instant get End {
    Preconditions.CheckState(_end.IsValid, 'Interval extends to end of time');
    return _end;
  }

  /// Returns the raw end value of the interval: a normal instant or [Instant.AfterMaxValue].
  /// This value should never be exposed.
  @internal
  Instant get RawEnd => _end;

  /// Returns `true` if this interval has a fixed end point, or `false` if it
  /// extends to the end of time.
  bool get HasEnd => _end.IsValid;

  /// Returns the duration of the interval.
  ///
  /// This will always be a non-negative duration, though it may be zero.
  ///
  /// Throws [StateError] if the interval extends to the start or end of time.
  nt.Duration get Duration => End - Start;

  /// Returns whether or not this interval contains the given instant.
  ///
  /// [instant]: Instant to test.
  ///
  /// Returns true if this interval contains the given instant; false otherwise.
  bool Contains(Instant instant) => instant >= _start && instant < _end;

  /// Deconstruct this value into its components.
  ///
  /// (C#'s `Deconstruct(out Instant? start, out Instant? end)`: `final (start, end) = interval.Deconstruct;`.)
  ///
  /// Returns the start of the interval and the end of the interval.
  (Instant? start, Instant? end) get Deconstruct {
    var start = _start.IsValid ? Start : null;
    var end = _end.IsValid ? End : null;
    return (start, end);
  }

  // #region Implementation of IEquatable<Interval>
  /// Indicates whether the value of this interval is equal to the value of the specified interval.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The value to compare with this instance.
  ///
  /// Returns true if the value of this instant is equal to the value of the [other] parameter;
  /// otherwise, false.
  bool Equals(Interval other) => _start == other._start && _end == other._end;
  // #endregion

  // #region object overrides

  /// Determines whether the specified object is equal to this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// [other]: The object to compare with this instance.
  ///
  /// Returns `true` if the specified object is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is Interval && Equals(other);

  /// Returns the hash code for this instance.
  /// See the type documentation for a description of equality semantics.
  ///
  /// Returns a 32-bit signed integer that is the hash code for this instance.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_start, _end);

  /// Returns a string representation of this interval, in extended ISO-8601 format: the format
  /// is "start/end" where each instant uses a format of "uuuu'-'MM'-'dd'T'HH':'mm':'ss;FFFFFFFFF'Z'".
  /// If the start or end is infinite, the relevant part uses "StartOfTime" or "EndOfTime" to
  /// represent this.
  ///
  /// Returns a string representation of this interval.
  @override
  String toString() {
    var pattern = InstantPattern.ExtendedIso;
    return '${pattern.Format(_start)}/${pattern.Format(_end)}';
  }
  // #endregion

  // #region Operators
  // C#'s operator == and != are Dart's == (object overrides, above) and Equals.
  // #endregion

  // #region XML serialization
  // Not ported: AddSchema, IXmlSerializable members (XML serialization)
  // #endregion

  // #region JSON (noda_dart)
  /// Returns `{"start", "end"}` (each omitted when unbounded), as NodaTime.Serialization.SystemTextJson does.
  Map<String, String> toJson() {
    var pattern = InstantPattern.ExtendedIso;
    return {
      if (HasStart) 'start': pattern.Format(_start),
      if (HasEnd) 'end': pattern.Format(_end),
    };
  }

  /// Parses a value written by [toJson] (property names ignoring case).
  ///
  /// Throws [UnparsableValueException] if an instant could not be parsed.
  factory Interval.fromJson(Map<String, Object?> json) {
    var pattern = InstantPattern.ExtendedIso;
    Instant? start;
    Instant? end;
    for (final MapEntry(:key, :value) in json.entries) {
      final lowerKey = key.toLowerCase();
      if (lowerKey != 'start' && lowerKey != 'end') {
        continue;
      }
      if (value is! String) {
        throw ArgumentError.value(value, 'json', 'Expected the $key property to be a string');
      }
      if (lowerKey == 'start') {
        start = pattern.Parse(value).Value;
      } else {
        end = pattern.Parse(value).Value;
      }
    }
    return Interval(start, end);
  }
  // #endregion
}
