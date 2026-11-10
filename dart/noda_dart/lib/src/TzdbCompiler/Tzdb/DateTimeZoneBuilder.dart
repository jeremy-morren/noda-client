// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler/Tzdb/DateTimeZoneBuilder.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'package:meta/meta.dart';

import '../../DateTimeZone.dart';
import '../../Instant.dart';
import '../../Offset.dart';
import '../../TimeZones/FixedDateTimeZone.dart';
import '../../TimeZones/PrecalculatedDateTimeZone.dart';
import '../../TimeZones/StandardDaylightAlternatingMap.dart';
import '../../TimeZones/Transition.dart';
import '../../TimeZones/ZoneInterval.dart';
import '../../TimeZones/ZoneRecurrence.dart';
import '../../Utility/Preconditions.dart';
import 'ZoneRuleSet.dart';
import 'ZoneTransition.dart';

/// Mutable class with only a static entry point, which converts and ID + sequence of ZoneRuleSet
/// elements into a DateTimeZone.
@internal
final class DateTimeZoneBuilder {
  final List<ZoneInterval> _zoneIntervals;
  StandardDaylightAlternatingMap? _tailZone;

  DateTimeZoneBuilder._New() : _zoneIntervals = <ZoneInterval>[];

  /// Builds a time zone with the given ID from a sequence of rule sets.
  static DateTimeZone Build(String id, List<ZoneRuleSet> ruleSets) {
    Preconditions.CheckArgument(ruleSets.isNotEmpty, 'ruleSets', 'Cannot create a time zone without any Zone entries');
    final builder = DateTimeZoneBuilder._New();
    return builder._BuildZone(id, ruleSets);
  }

  DateTimeZone _BuildZone(String id, List<ZoneRuleSet> ruleSets) {
    // This does most of the work: for each rule set (corresponding to a zone line
    // in the original data) we add some zone intervals.
    for (final ruleSet in ruleSets) {
      _AddIntervals(ruleSet);
    }

    // Some of the abutting zone intervals from the rule set boundaries may have the
    // same offsets and name, in which case  they can be coalesced.
    _CoalesceIntervals();

    // Finally, construct the time zone itself. Usually, we'll end up with a
    // PrecalculatedDateTimeZone here.
    if (_zoneIntervals.length == 1 && _tailZone == null) {
      return FixedDateTimeZone.NewIdOffsetName(id, _zoneIntervals[0].WallOffset, _zoneIntervals[0].Name);
    } else {
      return PrecalculatedDateTimeZone.NewIdIntervalsTailZone(id, _zoneIntervals.toList(), _tailZone);
    }
  }

  /// Adds the intervals from the given rule set to the end of the zone
  /// being built. The rule is deemed to take effect from the end of the previous
  /// zone interval, or the start of time if this is the first rule set (which must
  /// be a fixed one). Intervals are added until the rule set expires, or
  /// until we determine that the rule set continues to the end of time,
  /// possibly with a tail zone - a pair of standard/daylight rules which repeat
  /// forever.
  void _AddIntervals(ZoneRuleSet ruleSet) {
    // We use the last zone interval computed so far (if there is one) to work out where to start.
    final lastZoneInterval = _zoneIntervals.isEmpty ? null : _zoneIntervals.last;
    final start = lastZoneInterval?.End ?? Instant.BeforeMinValue;

    // Simple case: a zone line with fixed savings (or - for 0)
    // instead of a rule name. Just a single interval.
    if (ruleSet.IsFixed) {
      _zoneIntervals.add(ruleSet.CreateFixedInterval(start));
      return;
    }

    // Work on a copy of the rule set. We eliminate rules from it as they expire,
    // so that we can tell when we're down to an infinite pair which can be represented
    // as a tail zone.
    final activeRules = List<ZoneRecurrence>.of(ruleSet.Rules);

    // Surprisingly tricky bit to work out: how to handle the transition from
    // one rule set to another. We know the instant at which the new rule set
    // come in, but not what offsets/name to use from that point onwards: which
    // of the new rules is in force. We find out which rule would have taken
    // effect most recently before or on the transition instant - but using
    // the offsets from the final interval before the transition, instead
    // of the offsets which would have been in force if the new rule set were
    // actually extended backwards forever.
    //
    // It's possible that the most recent transition we find would actually
    // have started before that final interval anyway - but this appears to
    // match what zic produces.
    //
    // If we don't have a zone interval at all, we're starting at the start of
    // time, so there definitely aren't any preceding rules.
    ZoneRecurrence? firstRule;
    if (lastZoneInterval != null) {
      // noda_dart: LINQ's Select/Where/OrderBy/Select/LastOrDefault (ties ordered by index, as List.sort isn't stable).
      final pairs = <({ZoneRecurrence rule, int index, Transition prev})>[];
      for (var index = 0; index < activeRules.length; index++) {
        final rule = activeRules[index];
        final prev = rule.PreviousOrSame(start, lastZoneInterval.StandardOffset, lastZoneInterval.Savings);
        if (prev != null) {
          pairs.add((rule: rule, index: index, prev: prev));
        }
      }
      pairs.sort((x, y) {
        final comparison = x.prev.Instant.compareTo(y.prev.Instant);
        return comparison != 0 ? comparison : x.index - y.index;
      });
      firstRule = pairs.isEmpty ? null : pairs.last.rule;
    }

    // Every transition in this rule set will use the same standard offset.
    final standardOffset = ruleSet.StandardOffset;

    // previousTransition here is ongoing as we loop through the transitions. It's not like
    // lastZoneInterval, lastStandard and lastSavings, which refer to the last aspects of the
    // previous rule set. When we set it up, this is effectively the *first* transition leading
    // into the period in which the new rule set is
    ZoneTransition previousTransition;
    if (firstRule != null) {
      previousTransition =
          ZoneTransition.NewInstantNameStandardOffsetSavings(start, firstRule.Name, standardOffset, firstRule.Savings);
    } else {
      // None of the rules in the current set have *any* transitions in the past, apparently.
      // For an example of this, see Europe/Prague (in 2015e, anyway). A zone line with the
      // Czech rule takes effect in 1944, but all the rules are from 1945 onwards.
      // Use standard time until the first transition, regardless of the previous savings,
      // and take the name for this first interval from the first standard time rule.
      // (activeRules.First(rule => rule.Savings == Offset.Zero), which throws InvalidOperationException if there's no
      // such rule.)
      final standardRules = activeRules.where((rule) => rule.Savings == Offset.Zero);
      if (standardRules.isEmpty) {
        throw StateError('Sequence contains no matching element');
      }
      final name = standardRules.first.Name;
      previousTransition = ZoneTransition.NewInstantNameStandardOffsetSavings(start, name, standardOffset, Offset.Zero);
    }

    // Main loop - we keep going round until we run out of rules or hit infinity, each of which
    // corresponds with a return statement in the loop.
    while (true) {
      ZoneTransition? bestTransition;
      for (var i = 0; i < activeRules.length; i++) {
        final rule = activeRules[i];
        final nextTransition = rule.Next(previousTransition.Instant, standardOffset, previousTransition.Savings);
        // Once a rule is no longer active, remove it from the list. That way we can tell
        // when we can create a tail zone.
        if (nextTransition == null) {
          activeRules.removeAt(i);
          i--;
          continue;
        }
        final zoneTransition =
            ZoneTransition.NewInstantNameStandardOffsetSavings(nextTransition.Instant, rule.Name, standardOffset, rule.Savings);
        if (!zoneTransition.IsTransitionFrom(previousTransition)) {
          continue;
        }
        if (bestTransition == null || zoneTransition.Instant <= bestTransition.Instant) {
          bestTransition = zoneTransition;
        }
      }
      final currentUpperBound = ruleSet.GetUpperLimit(previousTransition.Savings);
      if (bestTransition == null || bestTransition.Instant >= currentUpperBound) {
        // No more transitions to find. (We may have run out of rules, or they may be beyond where this rule set expires.)
        // Add a final interval leading up to the upper bound of the rule set, unless the previous transition took us up to
        // this current bound anyway.
        // (This is very rare, but can happen if changing rule brings the upper bound down to the time
        // that the transition occurred. Example: 2008d, Europe/Sofia, April 1945.)
        if (currentUpperBound > previousTransition.Instant) {
          _zoneIntervals.add(previousTransition.ToZoneInterval(currentUpperBound));
        }
        return;
      }

      // We have a non-final transition. so add an interval from the previous transition to
      // this one.
      _zoneIntervals.add(previousTransition.ToZoneInterval(bestTransition.Instant));
      previousTransition = bestTransition;

      // Tail zone handling.
      // The final rule set must extend to infinity. There are potentially three ways
      // this can happen:
      // - All rules expire, leaving us with the final real transition, and an upper
      //   bound of infinity. This is handled above.
      // - 1 rule is left, but it cannot create more than one transition in a row,
      //   so again we end up with no transitions to record, and we bail out with
      //   a final infinite interval.
      // - 2 rules are left which would alternate infinitely. This is represented
      //   using a DaylightSavingZone as the tail zone.
      //
      // The code here caters for that last option, but needs to do it in stages.
      // When we first realize we will have a tail zone (an infinite rule set,
      // two rules left, both of which are themselves infinite) we can create the
      // tail zone, but we don't yet know that we're into its regular tick/tock.
      // It's possible that one rule only starts years after our current transition,
      // so we need to hit the first transition of that rule before we can create a
      // "seam" from the list of precomputed zone intervals to the calculated-on-demand
      // part of history.
      // For an example of why this is necessary, see Asia/Amman in 2013e: in late 2011
      // we hit "two rules left" but the final rule only starts in 2013 - we don't want
      // to see a bogus transition into that rule in 2012.
      // We could potentially record fewer zone intervals by keeping track of which
      // rules have created at least one transition, but this approach is simpler.
      if (ruleSet.IsInfinite && activeRules.length == 2) {
        if (_tailZone != null) {
          // Phase two: both rules must now be active, so we're done.
          return;
        }
        final startRule = activeRules[0];
        final endRule = activeRules[1];
        if (startRule.IsInfinite && endRule.IsInfinite) {
          // Phase one: build the zone, so we can go round once again and then return.
          _tailZone =
              StandardDaylightAlternatingMap.NewStandardOffsetStartRecurrenceEndRecurrence(standardOffset, startRule, endRule);
        }
      }
    }
  }

  /// Potentially join some abutting zone intervals, usually created
  /// due to the interval at the end of one rule set having the same name and offsets
  /// as the interval at the start of the next rule set.
  void _CoalesceIntervals() {
    for (var i = 0; i < _zoneIntervals.length - 1; i++) {
      final current = _zoneIntervals[i];
      final next = _zoneIntervals[i + 1];
      if (current.Name == next.Name &&
          current.WallOffset == next.WallOffset &&
          current.StandardOffset == next.StandardOffset) {
        _zoneIntervals[i] = current.WithEnd(next.RawEnd);
        _zoneIntervals.removeAt(i + 1);
        i--; // We may need to coalesce the next one, too.
      }
    }
  }
}
