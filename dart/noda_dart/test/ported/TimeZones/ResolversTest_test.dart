// Ported from NodaTime 6e024dde: src/NodaTime.Test/TimeZones/ResolversTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda_dart: Assert.Fail returns Never, so C#'s unreachable `return default(ZonedDateTime);` is left out.

// C#'s delegate-typed locals stay variables, as in the C#.
// ignore_for_file: prefer_function_declarations_over_variables

import 'package:noda_dart/src/AmbiguousTimeException.dart';
import 'package:noda_dart/src/Duration.dart';
import 'package:noda_dart/src/Instant.dart';
import 'package:noda_dart/src/LocalDateTime.dart';
import 'package:noda_dart/src/SkippedTimeException.dart';
import 'package:noda_dart/src/Testing/TimeZones/SingleTransitionDateTimeZone.dart';
import 'package:noda_dart/src/TimeZones/Delegates.dart';
import 'package:noda_dart/src/TimeZones/Resolvers.dart';
import 'package:noda_dart/src/ZonedDateTime.dart';

import '../../helpers/Assertions.dart';
import '../../helpers/Scenarios.dart';
import '../../scenarios/TimeZones/ResolversTest.generated.dart' as scenarios;

/// Zone where the clocks go back at 1am at the start of the year 2000, back to midnight.
final SingleTransitionDateTimeZone AmbiguousZone = SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), 1, 0);

/// Zone where the clocks go forward at midnight at the start of the year 2000, to 1am.
final SingleTransitionDateTimeZone GapZone = SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), 0, 1);

/// Local time which is either skipped or ambiguous, depending on the zones above.
final LocalDateTime TimeInTransition = LocalDateTime(2000, 1, 1, 0, 20);

void main() {
  port(scenarios.fixture, {
    'ReturnEarlier': (args) {
      var mapping = AmbiguousZone.MapLocal(TimeInTransition);
      Assert.AreEqual(2, mapping.Count);
      var resolved = Resolvers.ReturnEarlier(mapping.First(), mapping.Last());
      Assert.AreEqual(mapping.First(), resolved);
    },

    'ReturnLater': (args) {
      var mapping = AmbiguousZone.MapLocal(TimeInTransition);
      Assert.AreEqual(2, mapping.Count);
      var resolved = Resolvers.ReturnLater(mapping.First(), mapping.Last());
      Assert.AreEqual(mapping.Last(), resolved);
    },

    'ThrowWhenAmbiguous': (args) {
      var mapping = AmbiguousZone.MapLocal(TimeInTransition);
      Assert.AreEqual(2, mapping.Count);
      Assert.Throws<AmbiguousTimeException>(() => Resolvers.ThrowWhenAmbiguous(mapping.First(), mapping.Last()));
    },

    'ReturnEndOfIntervalBefore': (args) {
      var mapping = GapZone.MapLocal(TimeInTransition);
      Assert.AreEqual(0, mapping.Count);
      var resolved = Resolvers.ReturnEndOfIntervalBefore(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);
      Assert.AreEqual(GapZone.EarlyInterval.End.MinusDuration(Duration.Epsilon), resolved.ToInstant());
      Assert.AreEqual(GapZone, resolved.Zone);
    },

    'ReturnStartOfIntervalAfter': (args) {
      var mapping = GapZone.MapLocal(TimeInTransition);
      Assert.AreEqual(0, mapping.Count);
      var resolved = Resolvers.ReturnStartOfIntervalAfter(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);
      Assert.AreEqual(GapZone.LateInterval.Start, resolved.ToInstant());
      Assert.AreEqual(GapZone, resolved.Zone);
    },

    'ReturnForwardShifted': (args) {
      var mapping = GapZone.MapLocal(TimeInTransition);
      Assert.AreEqual(0, mapping.Count);
      var resolved = Resolvers.ReturnForwardShifted(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);

      var gap = mapping.LateInterval.WallOffset.Ticks - mapping.EarlyInterval.WallOffset.Ticks;
      var expected = TimeInTransition.ToLocalInstant().Minus(mapping.LateInterval.WallOffset).PlusTicks(gap);
      Assert.AreEqual(expected, resolved.ToInstant());
      Assert.AreEqual(mapping.LateInterval.WallOffset, resolved.Offset);
      Assert.AreEqual(GapZone, resolved.Zone);
    },

    'ThrowWhenSkipped': (args) {
      var mapping = GapZone.MapLocal(TimeInTransition);
      Assert.AreEqual(0, mapping.Count);
      Assert.Throws<SkippedTimeException>(() => Resolvers.ThrowWhenSkipped(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval));
    },

    'CreateResolver_Unambiguous': (args) {
      AmbiguousTimeResolver ambiguityResolver = (earlier, later) { Assert.Fail("Shouldn't be called"); };
      SkippedTimeResolver skippedTimeResolver = (local, zone, before, after) { Assert.Fail("Shouldn't be called"); };
      var resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

      LocalDateTime localTime = LocalDateTime(1900, 1, 1, 0, 0);
      var resolved = resolver(GapZone.MapLocal(localTime));
      Assert.AreEqual(ZonedDateTime.NewOffsetDateTimeZone(localTime.WithOffset(GapZone.EarlyInterval.WallOffset), GapZone), resolved);
    },

    'CreateResolver_Ambiguous': (args) {
      ZonedDateTime zoned = ZonedDateTime.NewOffsetDateTimeZone(TimeInTransition.PlusDays(1).WithOffset(GapZone.EarlyInterval.WallOffset), GapZone);
      AmbiguousTimeResolver ambiguityResolver = (earlier, later) => zoned;
      SkippedTimeResolver skippedTimeResolver = (local, zone, before, after) { Assert.Fail("Shouldn't be called"); };
      var resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

      var resolved = resolver(AmbiguousZone.MapLocal(TimeInTransition));
      Assert.AreEqual(zoned, resolved);
    },

    'CreateResolver_Skipped': (args) {
      ZonedDateTime zoned = ZonedDateTime.NewOffsetDateTimeZone(TimeInTransition.PlusDays(1).WithOffset(GapZone.EarlyInterval.WallOffset), GapZone);
      AmbiguousTimeResolver ambiguityResolver = (earlier, later) { Assert.Fail("Shouldn't be called"); };
      SkippedTimeResolver skippedTimeResolver = (local, zone, before, after) => zoned;
      var resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

      var resolved = resolver(GapZone.MapLocal(TimeInTransition));
      Assert.AreEqual(zoned, resolved);
    },
  });
}
