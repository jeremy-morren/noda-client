// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/ZoneLine.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Offset.dart';
import '../../Text/OffsetPattern.dart';
import '../../TimeZones/ZoneYearOffset.dart';
import '../../Utility/HashCodeHelper.dart';
import '../../Utility/Int64.dart';
import 'ParserHelper.dart';
import 'RuleLine.dart';
import 'ZoneRuleSet.dart';

/// Contains the parsed information from one "Zone" line of the TZDB zone database.
///
/// Immutable, thread-safe
@internal
class ZoneLine {
  static final OffsetPattern _PercentZPattern = OffsetPattern.CreateWithInvariantCulture('i');

  /// Initializes a new instance of the [ZoneLine] class.
  ZoneLine(String name, Offset offset, String? rules, String format, int untilYear, ZoneYearOffset untilYearOffset)
      : Name = name,
        StandardOffset = offset,
        Rules = rules,
        Format = format,
        UntilYear = untilYear,
        UntilYearOffset = untilYearOffset;

  final ZoneYearOffset UntilYearOffset;

  final int UntilYear;

  /// Returns the format for generating the label for this time zone. May contain "%s" to
  /// be replaced by a daylight savings indicator, or "%z" to be replaced by an offset indicator.
  ///
  /// The format string.
  final String Format;

  /// Returns the name of the time zone.
  ///
  /// The time zone name.
  final String Name;

  /// Returns the offset to add to UTC for this time zone's standard time.
  ///
  /// The offset from UTC.
  final Offset StandardOffset;

  /// The name of the set of rules applicable to this zone line, or
  /// null for just standard time, or an offset for a "fixed savings" rule.
  ///
  /// The name of the rules to apply for this zone line.
  final String? Rules;

  // #region IEquatable<Zone> Members
  /// Indicates whether the current object is equal to another object of the same type.
  ///
  /// [other]: An object to compare with this object.
  ///
  /// Returns true if the current object is equal to the [other] parameter;
  /// otherwise, false.
  bool Equals(ZoneLine? other) {
    if (other == null) {
      return false;
    }
    if (identical(this, other)) {
      return true;
    }
    var result = Name == other.Name &&
        StandardOffset == other.StandardOffset &&
        Rules == other.Rules &&
        Format == other.Format &&
        UntilYear == other.UntilYear;
    if (UntilYear != Int64.Int32MaxValue) {
      result = result && UntilYearOffset.Equals(other.UntilYearOffset);
    }
    return result;
  }
  // #endregion

  /// Determines whether the specified [Object] is equal to this instance.
  ///
  /// [other]: The [Object] to compare with this instance.
  ///
  /// Returns `true` if the specified [Object] is equal to this instance;
  /// otherwise, `false`.
  @override
  bool operator ==(Object other) => other is ZoneLine && Equals(other);

  /// Returns a hash code for this instance.
  ///
  /// Returns a hash code for this instance, suitable for use in hashing algorithms and data
  /// structures like a hash table.
  @override
  int get hashCode {
    var hash = HashCodeHelper.Initialize().Hash(Name).Hash(StandardOffset).Hash(Rules).Hash(Format).Hash(UntilYear);
    if (UntilYear != Int64.Int32MaxValue) {
      hash = hash.Hash(UntilYearOffset.hashCode);
    }

    return hash.Value;
  }

  /// Returns a [String] that represents this instance.
  ///
  /// Returns a [String] that represents this instance.
  @override
  String toString() {
    final builder = StringBuffer();
    builder
      ..write(Name)
      ..write(' ');
    builder
      ..write(StandardOffset)
      ..write(' ');
    builder
      ..write(ParserHelper.FormatOptional(Rules))
      ..write(' ');
    builder.write(Format);
    if (UntilYear != Int64.Int32MaxValue) {
      // UntilYear.ToString("D4", CultureInfo.InvariantCulture)
      final year = UntilYear < 0 ? '-${(-UntilYear).toString().padLeft(4, '0')}' : UntilYear.toString().padLeft(4, '0');
      builder
        ..write(' ')
        ..write(year)
        ..write(' ')
        ..write(UntilYearOffset);
    }
    return builder.toString();
  }

  ZoneRuleSet ResolveRules(Map<String, List<RuleLine>> allRules) {
    if (Rules == null) {
      final name = FormatName(Offset.Zero, '');
      return ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
          name, StandardOffset, Offset.Zero, UntilYear, UntilYearOffset);
    }
    final ruleSet = allRules[Rules];
    if (ruleSet != null) {
      final rules = ruleSet.map((x) => x.GetRecurrence(this));
      return ZoneRuleSet.NewRulesStandardOffsetUpperYearUpperYearOffset(
          rules.toList(), StandardOffset, UntilYear, UntilYearOffset);
    } else {
      try {
        // Check if Rules actually just refers to a savings.
        final savings = ParserHelper.ParseOffset(Rules!);
        final name = FormatName(savings, '');
        return ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
            name, StandardOffset, savings, UntilYear, UntilYearOffset);
      } on FormatException {
        throw ArgumentError(
            "Daylight savings rule name '$Rules' for zone $Name is neither a known ruleset nor a fixed offset");
      }
    }
  }

  String FormatName(Offset savings, String? daylightSavingsIndicator) {
    var index = Format.indexOf('/');
    if (index >= 0) {
      return savings == Offset.Zero ? Format.substring(0, index) : Format.substring(index + 1);
    }
    index = Format.indexOf('%s');
    if (index >= 0) {
      final left = Format.substring(0, index);
      final right = Format.substring(index + 2);
      // C# string concatenation treats null as "".
      return left + (daylightSavingsIndicator ?? '') + right;
    }
    index = Format.indexOf('%z');
    if (index >= 0) {
      final left = Format.substring(0, index);
      final right = Format.substring(index + 2);
      return left + _PercentZPattern.Format(StandardOffset + savings) + right;
    }
    return Format;
  }
}
