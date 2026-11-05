// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/ResolversTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal constructor ZonedDateTime(OffsetDateTime, DateTimeZone) is ZonedDateTime.NewOffsetDateTimeZone.
// In the resolvers that "shouldn't be called", expect.fail throws, so the C# `return default(ZonedDateTime)` is
// unreachable and omitted.

import { expect } from "vitest";
import {
  AmbiguousTimeException,
  Duration,
  Instant,
  LocalDateTime,
  Resolvers,
  SingleTransitionDateTimeZone,
  SkippedTimeException,
  ZonedDateTime,
  type AmbiguousTimeResolver,
  type SkippedTimeResolver,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TimeZones/ResolversTest.generated.ts";

/** Zone where the clocks go back at 1am at the start of the year 2000, back to midnight. */
const AmbiguousZone = new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), 1, 0);

/** Zone where the clocks go forward at midnight at the start of the year 2000, to 1am. */
const GapZone = new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), 0, 1);

/** Local time which is either skipped or ambiguous, depending on the zones above. */
const TimeInTransition = new LocalDateTime(2000, 1, 1, 0, 20);

port(fixture, {
  ReturnEarlier() {
    const mapping = AmbiguousZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(2);
    const resolved = Resolvers.ReturnEarlier(mapping.First(), mapping.Last());
    assertNodaEqual(resolved, mapping.First());
  },

  ReturnLater() {
    const mapping = AmbiguousZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(2);
    const resolved = Resolvers.ReturnLater(mapping.First(), mapping.Last());
    assertNodaEqual(resolved, mapping.Last());
  },

  ThrowWhenAmbiguous() {
    const mapping = AmbiguousZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(2);
    assertThrows(AmbiguousTimeException, () => Resolvers.ThrowWhenAmbiguous(mapping.First(), mapping.Last()));
  },

  ReturnEndOfIntervalBefore() {
    const mapping = GapZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(0);
    const resolved = Resolvers.ReturnEndOfIntervalBefore(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);
    assertNodaEqual(resolved.ToInstant(), GapZone.EarlyInterval.End.Minus(Duration.Epsilon));
    assertNodaEqual(resolved.Zone, GapZone);
  },

  ReturnStartOfIntervalAfter() {
    const mapping = GapZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(0);
    const resolved = Resolvers.ReturnStartOfIntervalAfter(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);
    assertNodaEqual(resolved.ToInstant(), GapZone.LateInterval.Start);
    assertNodaEqual(resolved.Zone, GapZone);
  },

  ReturnForwardShifted() {
    const mapping = GapZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(0);
    const resolved = Resolvers.ReturnForwardShifted(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval);

    const gap = mapping.LateInterval.WallOffset.Ticks - mapping.EarlyInterval.WallOffset.Ticks;
    const expected = TimeInTransition.ToLocalInstant().Minus(mapping.LateInterval.WallOffset).PlusTicks(gap);
    assertNodaEqual(resolved.ToInstant(), expected);
    assertNodaEqual(resolved.Offset, mapping.LateInterval.WallOffset);
    assertNodaEqual(resolved.Zone, GapZone);
  },

  ThrowWhenSkipped() {
    const mapping = GapZone.MapLocal(TimeInTransition);
    expect(mapping.Count).toBe(0);
    assertThrows(SkippedTimeException, () => Resolvers.ThrowWhenSkipped(TimeInTransition, GapZone, mapping.EarlyInterval, mapping.LateInterval));
  },

  CreateResolver_Unambiguous() {
    const ambiguityResolver: AmbiguousTimeResolver = () => expect.fail("Shouldn't be called");
    const skippedTimeResolver: SkippedTimeResolver = () => expect.fail("Shouldn't be called");
    const resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

    const localTime = new LocalDateTime(1900, 1, 1, 0, 0);
    const resolved = resolver(GapZone.MapLocal(localTime));
    assertNodaEqual(resolved, ZonedDateTime.NewOffsetDateTimeZone(localTime.WithOffset(GapZone.EarlyInterval.WallOffset), GapZone));
  },

  CreateResolver_Ambiguous() {
    const zoned = ZonedDateTime.NewOffsetDateTimeZone(TimeInTransition.PlusDays(1).WithOffset(GapZone.EarlyInterval.WallOffset), GapZone);
    const ambiguityResolver: AmbiguousTimeResolver = () => zoned;
    const skippedTimeResolver: SkippedTimeResolver = () => expect.fail("Shouldn't be called");
    const resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

    const resolved = resolver(AmbiguousZone.MapLocal(TimeInTransition));
    assertNodaEqual(resolved, zoned);
  },

  CreateResolver_Skipped() {
    const zoned = ZonedDateTime.NewOffsetDateTimeZone(TimeInTransition.PlusDays(1).WithOffset(GapZone.EarlyInterval.WallOffset), GapZone);
    const ambiguityResolver: AmbiguousTimeResolver = () => expect.fail("Shouldn't be called");
    const skippedTimeResolver: SkippedTimeResolver = () => zoned;
    const resolver = Resolvers.CreateMappingResolver(ambiguityResolver, skippedTimeResolver);

    const resolved = resolver(GapZone.MapLocal(TimeInTransition));
    assertNodaEqual(resolved, zoned);
  },
});
