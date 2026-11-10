// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/RuleLine.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../TimeZones/ZoneRecurrence.dart';
import '../../Utility/HashCodeHelper.dart';
import 'ZoneLine.dart';

/// Defines one "Rule" line from the tz data. (This may be applied to multiple zones.)
///
/// Immutable, threadsafe.
@internal
class RuleLine {
  /// The string to replace "%s" with (if any) when formatting the zone name key.
  ///
  /// This is always used to replace %s, whether or not the recurrence
  /// actually includes savings; it is expected to be appropriate to the recurrence.
  final String? _daylightSavingsIndicator;

  /// The recurrence pattern for the rule.
  final ZoneRecurrence _recurrence;

  /// Returns the name of the rule set this rule belongs to.
  String get Name => _recurrence.Name;

  /// Initializes a new instance of the [RuleLine] class.
  ///
  /// [recurrence]: The recurrence definition of this rule.
  /// [daylightSavingsIndicator]: The daylight savings indicator letter for time zone names.
  RuleLine(ZoneRecurrence recurrence, String? daylightSavingsIndicator)
      : _recurrence = recurrence,
        _daylightSavingsIndicator = daylightSavingsIndicator;

  // #region IEquatable<RuleLine> Members
  /// Indicates whether the current object is equal to another object of the same type.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(RuleLine? other) =>
      other != null && _recurrence == other._recurrence && _daylightSavingsIndicator == other._daylightSavingsIndicator;
  // #endregion

  // #region Operator overloads
  /// Implements the operator ==.
  ///
  /// (Also NodaTime's `Equals(object)`; `!=` is Dart's.)
  @override
  bool operator ==(Object other) => other is RuleLine && Equals(other);
  // #endregion

  /// Retrieves the recurrence, after applying the specified name format.
  ///
  /// Multiple zones may apply the same set of rules as to when they change into/out of
  /// daylight saving time, but with different names.
  ///
  /// [zone]: The zone for which this rule is being considered.
  ZoneRecurrence GetRecurrence(ZoneLine zone) {
    final name = zone.FormatName(_recurrence.Savings, _daylightSavingsIndicator);
    return _recurrence.WithName(name);
  }

  // #region Object overrides
  // Equals(object) is operator == above.

  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode => HashCodeHelper.HashStatic(_recurrence, _daylightSavingsIndicator);

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() {
    final builder = StringBuffer();
    builder.write(_recurrence);
    if (_daylightSavingsIndicator != null) {
      builder
        ..write(' "')
        ..write(_daylightSavingsIndicator)
        ..write('"');
    }
    return builder.toString();
  }
  // #endregion Object overrides
}
