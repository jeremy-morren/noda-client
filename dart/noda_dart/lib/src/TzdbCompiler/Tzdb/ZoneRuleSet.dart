// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/ZoneRuleSet.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../Instant.dart';
import '../../Offset.dart';
import '../../TimeZones/ZoneInterval.dart';
import '../../TimeZones/ZoneRecurrence.dart';
import '../../TimeZones/ZoneYearOffset.dart';
import '../../Utility/Int64.dart';
import '../../Utility/Preconditions.dart';

/// A rule set associated with a single Zone line, after any rules
/// associated with it have been resolved to a collection of ZoneRecurrences.
/// It may have an upper bound, or extend to infinity: lower bounds aren't known.
/// Likewise it may have rules associated with it, or just a fixed offset and savings.
@internal
final class ZoneRuleSet {
  // Either rules or name+fixedSavings is specified.
  final List<ZoneRecurrence> _rules;
  final String? _name;
  final Offset _fixedSavings;
  final int _upperYear;
  final ZoneYearOffset? _upperYearOffset;
  final Offset StandardOffset;

  // noda_dart: NodaTime's private constructor, with the fields the internal constructors set as extra parameters.
  ZoneRuleSet._NewStandardOffsetUpperYearUpperYearOffset(Offset standardOffset, int upperYear,
      ZoneYearOffset? upperYearOffset, List<ZoneRecurrence> rules, String? name, Offset fixedSavings)
      : StandardOffset = standardOffset,
        _upperYear = upperYear,
        _upperYearOffset = upperYearOffset,
        _rules = rules,
        _name = name,
        _fixedSavings = fixedSavings {
    Preconditions.CheckArgument(upperYear == Int64.Int32MaxValue || upperYearOffset != null, 'upperYearOffset',
        'Must specify an upperYearOffset unless creating an infinite rule');
  }

  ZoneRuleSet.NewRulesStandardOffsetUpperYearUpperYearOffset(
      List<ZoneRecurrence> rules, Offset standardOffset, int upperYear, ZoneYearOffset? upperYearOffset)
      : this._NewStandardOffsetUpperYearUpperYearOffset(
            standardOffset, upperYear, upperYearOffset, rules, null, Offset.Zero);

  ZoneRuleSet.NewNameStandardOffsetSavingsUpperYearUpperYearOffset(
      String name, Offset standardOffset, Offset savings, int upperYear, ZoneYearOffset? upperYearOffset)
      : this._NewStandardOffsetUpperYearUpperYearOffset(
            standardOffset, upperYear, upperYearOffset, <ZoneRecurrence>[], name, savings);

  /// Returns `true` if this rule set extends to the end of time, or
  /// `false` if it has a finite end point.
  bool get IsInfinite => _upperYear == Int64.Int32MaxValue;

  bool get IsFixed => _name != null;

  Iterable<ZoneRecurrence> get Rules => _rules;

  ZoneInterval CreateFixedInterval(Instant start) {
    Preconditions.CheckState(IsFixed, 'Rule set is not fixed');
    final limit = GetUpperLimit(_fixedSavings);
    return ZoneInterval.NewNameStartEndWallOffsetSavings(
        _name!, start, limit, StandardOffset + _fixedSavings, _fixedSavings);
  }

  /// Gets the inclusive upper limit of time that this rule set applies to.
  ///
  /// [savings]: The daylight savings value during the final zone interval.
  ///
  /// Returns the `LocalInstant` of the upper limit for this rule set.
  Instant GetUpperLimit(Offset savings) {
    if (IsInfinite) {
      return Instant.AfterMaxValue;
    }
    final localInstant = _upperYearOffset!.GetOccurrenceForYear(_upperYear);
    final offset = _upperYearOffset.GetRuleOffset(StandardOffset, savings);
    return localInstant.SafeMinus(offset);
  }
}
