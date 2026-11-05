// Ported from NodaTime 3.3.0: src/NodaTime.Test/DateTimeZoneTest.cs (+ .GetZoneIntervals.cs, .Ids.cs,
// .LocalConversions.cs, .MapLocal.cs)
// Copyright 2010 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneProviders.Tzdb is the bundled `tzdb` provider, and its indexer is get(id). The C# collection
// initializers for MultiTransitionDateTimeZone.Builder are calls to add(). The internal constructor
// ZonedDateTime(OffsetDateTime, DateTimeZone) is ZonedDateTime.newOffsetDateTimeZone.

import { expect } from "vitest";
import {
  AmbiguousTimeError,
  ArgumentOutOfRangeError,
  DateTimeZone,
  Duration,
  Instant,
  Interval,
  IsoDayOfWeek,
  LocalDate,
  LocalDatePattern,
  LocalDateTime,
  LocalTime,
  MultiTransitionDateTimeZone,
  NodaConstants,
  Offset,
  Resolvers,
  SingleTransitionDateTimeZone,
  SkippedTimeError,
  ZonedDateTime,
  ZoneEqualityComparer,
  ZoneEqualityComparerOptions,
  type ZoneInterval,
  type ZoneLocalMapping,
} from "../../src/noda-js/internal.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/DateTimeZoneTest.generated.ts";

// #region DateTimeZoneTest.GetZoneIntervals.cs

const TestZone = new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), -3, +4);

// #endregion

// #region DateTimeZoneTest.LocalConversions.cs

// Sample time zones for DateTimeZone.AtStartOfDay etc. I didn't want to only test midnight transitions.
const LosAngeles = tzdb.Get("America/Los_Angeles");
const NewZealand = tzdb.Get("Pacific/Auckland");
const Paris = tzdb.Get("Europe/Paris");
const NewYork = tzdb.Get("America/New_York");
const Pacific = tzdb.Get("America/Los_Angeles");

/** Local midnight at the start of the transition (June 1st) becomes 1am. */
const TransitionForwardAtMidnightZone: DateTimeZone =
  new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 6, 1, 2, 0), Offset.FromHours(-2), Offset.FromHours(-1));

/** Local 1am at the start of the transition (June 1st) becomes midnight. */
const TransitionBackwardToMidnightZone: DateTimeZone =
  new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 6, 1, 3, 0), Offset.FromHours(-2), Offset.FromHours(-3));

/** Local 11.20pm at the start of the transition (May 30th) becomes 12.20am of June 1st. */
const TransitionForwardBeforeMidnightZone: DateTimeZone =
  new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 6, 1, 1, 20), Offset.FromHours(-2), Offset.FromHours(-1));

/** Local 12.20am at the start of the transition (June 1st) becomes 11.20pm of the previous day. */
const TransitionBackwardAfterMidnightZone: DateTimeZone =
  new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 6, 1, 2, 20), Offset.FromHours(-2), Offset.FromHours(-3));

const TransitionDate = new LocalDate(2000, 6, 1);

function assertImpossible(localTime: LocalDateTime, zone: DateTimeZone): void {
  const mapping = zone.MapLocal(localTime);
  expect(mapping.Count).toBe(0);
  let e = assertThrows(SkippedTimeError, () => mapping.Single());
  assertNodaEqual(e.LocalDateTime, localTime);
  assertNodaEqual(e.Zone, zone);
  expect(e.ParamName).toBeNull();
  expect(e.message).toContain(zone.Id);

  e = assertThrows(SkippedTimeError, () => mapping.First());
  assertNodaEqual(e.LocalDateTime, localTime);
  assertNodaEqual(e.Zone, zone);

  e = assertThrows(SkippedTimeError, () => mapping.Last());
  assertNodaEqual(e.LocalDateTime, localTime);
  assertNodaEqual(e.Zone, zone);
}

function assertAmbiguous(localTime: LocalDateTime, zone: DateTimeZone): void {
  const earlier = zone.MapLocal(localTime).First();
  const later = zone.MapLocal(localTime).Last();
  assertNodaEqual(earlier.LocalDateTime, localTime);
  assertNodaEqual(later.LocalDateTime, localTime);
  expect(earlier.ToInstant().CompareTo(later.ToInstant())).toBeLessThan(0);

  const mapping = zone.MapLocal(localTime);
  expect(mapping.Count).toBe(2);
  const e = assertThrows(AmbiguousTimeError, () => mapping.Single());
  assertNodaEqual(e.LocalDateTime, localTime);
  assertNodaEqual(e.Zone, zone);
  assertNodaEqual(e.EarlierMapping, earlier);
  assertNodaEqual(e.LaterMapping, later);
  expect(e.ParamName).toBeNull();
  expect(e.message).toContain(zone.Id);

  assertNodaEqual(mapping.First(), earlier);
  assertNodaEqual(mapping.Last(), later);
}

function assertOffset(expectedHours: number, localTime: LocalDateTime, zone: DateTimeZone): void {
  const mapping = zone.MapLocal(localTime);
  expect(mapping.Count).toBe(1);
  const zoned = mapping.Single();
  assertNodaEqual(mapping.First(), zoned);
  assertNodaEqual(mapping.Last(), zoned);
  const actualHours = Math.trunc(zoned.Offset.Milliseconds / NodaConstants.MillisecondsPerHour);
  expect(actualHours).toBe(expectedHours);
}

// #endregion

// #region DateTimeZoneTest.MapLocal.cs

const Transition = Instant.FromUtc(2000, 1, 1, 0, 0);

const Minus5 = Offset.FromHours(-5);
const Plus10 = Offset.FromHours(10);

const NearStartOfTime = new LocalDateTime(-9998, 1, 5, 0, 0);
const NearEndOfTime = new LocalDateTime(9999, 12, 25, 0, 0);
const TransitionMinus5 = Transition.WithOffset(Minus5).LocalDateTime;
const TransitionPlus10 = Transition.WithOffset(Plus10).LocalDateTime;
const MidTransition = Transition.WithOffset(Offset.Zero).LocalDateTime;

const YearBeforeTransition = new LocalDateTime(1999, 1, 1, 0, 0);
const YearAfterTransition = new LocalDateTime(2001, 1, 1, 0, 0);

const ZoneWithGap = new SingleTransitionDateTimeZone(Transition, Minus5, Plus10);
const IntervalBeforeGap = ZoneWithGap.EarlyInterval;
const IntervalAfterGap = ZoneWithGap.LateInterval;

const ZoneWithAmbiguity = new SingleTransitionDateTimeZone(Transition, Plus10, Minus5);
const IntervalBeforeAmbiguity = ZoneWithAmbiguity.EarlyInterval;
const IntervalAfterAmbiguity = ZoneWithAmbiguity.LateInterval;

function checkMapping(mapping: ZoneLocalMapping, earlyInterval: ZoneInterval, lateInterval: ZoneInterval, count: number): void {
  assertNodaEqual(mapping.EarlyInterval, earlyInterval);
  assertNodaEqual(mapping.LateInterval, lateInterval);
  expect(mapping.Count).toBe(count);
}

// #endregion

/** The zone used by the GetZoneIntervals_WithOptions tests (a C# collection initializer). */
function buildWithOptionsZone(transition1: Instant, transition2: Instant, transition3: Instant, transition4: Instant): MultiTransitionDateTimeZone {
  const builder = new MultiTransitionDateTimeZone.Builder(0, "0+0");
  builder.Add(transition1, 1, 1, "1+1");
  builder.Add(transition2, 0, 2, "0+2");
  builder.Add(transition3, 0, 1, "0+1");
  builder.Add(transition4, 0, 0, "0+0");
  return builder.Build();
}

port(fixture, {
  // #region DateTimeZoneTest.cs

  // The current implementation caches every half hour, -12 to +15.
  ForOffset_UncachedExample_NotOnHalfHour() {
    const offset = Offset.FromSeconds(123);
    const zone1 = DateTimeZone.ForOffset(offset);
    const zone2 = DateTimeZone.ForOffset(offset);

    expect(zone1).not.toBe(zone2);
    expect(zone1.IsFixed).toBe(true);
    assertNodaEqual(zone1.MaxOffset, offset);
    assertNodaEqual(zone1.MinOffset, offset);
  },

  ForOffset_UncachedExample_OutsideCacheRange() {
    const offset = Offset.FromHours(-14);
    const zone1 = DateTimeZone.ForOffset(offset);
    const zone2 = DateTimeZone.ForOffset(offset);

    expect(zone1).not.toBe(zone2);
    expect(zone1.IsFixed).toBe(true);
    assertNodaEqual(zone1.MaxOffset, offset);
    assertNodaEqual(zone1.MinOffset, offset);
  },

  ForOffset_CachedExample() {
    const offset = Offset.FromHours(2);
    const zone1 = DateTimeZone.ForOffset(offset);
    const zone2 = DateTimeZone.ForOffset(offset);
    // Caching check...
    expect(zone1).toBe(zone2);

    expect(zone1.IsFixed).toBe(true);
    assertNodaEqual(zone1.MaxOffset, offset);
    assertNodaEqual(zone1.MinOffset, offset);
  },

  ForOffset_Zero_SameAsUtc() {
    expect(DateTimeZone.ForOffset(Offset.Zero)).toBe(DateTimeZone.Utc);
  },

  // #endregion

  // #region DateTimeZoneTest.GetZoneIntervals.cs

  GetZoneIntervals_EndBeforeStart() {
    assertThrows(ArgumentOutOfRangeError, () => DateTimeZone.Utc.GetZoneIntervals(Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(99)));
  },

  GetZoneIntervals_EndEqualToStart() {
    expect([...DateTimeZone.Utc.GetZoneIntervals(Instant.FromUnixTimeTicks(100), Instant.FromUnixTimeTicks(100))]).toEqual([]);
  },

  GetZoneIntervals_InvalidOptions() {
    const zone = DateTimeZone.Utc;
    const interval = new Interval(Instant.FromUtc(2000, 1, 1, 0, 0), Instant.FromUtc(2001, 1, 1, 0, 0));
    assertThrows(ArgumentOutOfRangeError, () => zone.GetZoneIntervals(interval, 1234567 as ZoneEqualityComparerOptions));
  },

  GetZoneIntervals_FixedZone() {
    const zone = DateTimeZone.ForOffset(Offset.FromHours(3));
    const expected = [zone.GetZoneInterval(Instant.MinValue)];
    // Give a reasonably wide interval...
    const actual = zone.GetZoneIntervals(Instant.FromUtc(1900, 1, 1, 0, 0), Instant.FromUtc(2100, 1, 1, 0, 0));
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_SingleTransitionZone_IntervalCoversTransition() {
    const start = TestZone.Transition.Minus(Duration.FromDays(5));
    const end = TestZone.Transition.Plus(Duration.FromDays(5));
    const expected = [TestZone.EarlyInterval, TestZone.LateInterval];
    const actual = TestZone.GetZoneIntervals(start, end);
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_SingleTransitionZone_IntervalDoesNotCoverTransition() {
    const start = TestZone.Transition.Minus(Duration.FromDays(10));
    const end = TestZone.Transition.Minus(Duration.FromDays(5));
    const expected = [TestZone.EarlyInterval];
    const actual = TestZone.GetZoneIntervals(start, end);
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_IncludesStart() {
    const start = TestZone.Transition.Minus(Duration.Epsilon);
    const end = TestZone.Transition.Plus(Duration.FromDays(5));
    const expected = [TestZone.EarlyInterval, TestZone.LateInterval];
    const actual = TestZone.GetZoneIntervals(start, end);
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_ExcludesEnd() {
    const start = TestZone.Transition.Minus(Duration.FromDays(10));
    const end = TestZone.Transition;
    const expected = [TestZone.EarlyInterval];
    const actual = TestZone.GetZoneIntervals(start, end);
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_Complex() {
    const london = tzdb.Get("Europe/London");
    // Transitions are always Spring/Autumn, so June and January should be clear.
    const expected = [
      london.GetZoneInterval(Instant.FromUtc(1999, 6, 1, 0, 0)),
      london.GetZoneInterval(Instant.FromUtc(2000, 1, 1, 0, 0)),
      london.GetZoneInterval(Instant.FromUtc(2000, 6, 1, 0, 0)),
      london.GetZoneInterval(Instant.FromUtc(2001, 1, 1, 0, 0)),
      london.GetZoneInterval(Instant.FromUtc(2001, 6, 1, 0, 0)),
      london.GetZoneInterval(Instant.FromUtc(2002, 1, 1, 0, 0)),
    ];
    // After the instant we used to fetch the expected zone interval, but that's fine:
    // it'll be the same one, as there's no transition within June.
    const start = Instant.FromUtc(1999, 6, 19, 0, 0);
    const end = Instant.FromUtc(2002, 2, 4, 0, 0);
    let actual = london.GetZoneIntervals(start, end);
    assertNodaEqual([...actual], expected);
    // Just to exercise the other overload
    actual = london.GetZoneIntervals(new Interval(start, end));
    assertNodaEqual([...actual], expected);
  },

  GetZoneIntervals_WithOptions_NoCoalescing() {
    // We'll ask for 1999-2003, so there are three transitions within that.
    const transition1 = Instant.FromUtc(2000, 1, 1, 0, 0);
    const transition2 = Instant.FromUtc(2001, 1, 1, 0, 0);
    const transition3 = Instant.FromUtc(2002, 1, 1, 0, 0);
    // And one transition afterwards.
    const transition4 = Instant.FromUtc(2004, 1, 1, 0, 0);
    const zone = buildWithOptionsZone(transition1, transition2, transition3, transition4);
    const interval = new Interval(
      Instant.FromUtc(1999, 1, 1, 0, 0),
      Instant.FromUtc(2003, 1, 1, 0, 0));
    // No coalescing required, as the names are different.
    const zoneIntervals = [...zone.GetZoneIntervals(interval, ZoneEqualityComparer.Options.MatchNames)];
    expect(zoneIntervals.length).toBe(4);
    assertNodaEqual(zoneIntervals.map(zi => zi.End), [transition1, transition2, transition3, transition4]);
  },

  GetZoneIntervals_WithOptions_Coalescing() {
    // We'll ask for 1999-2003, so there are three transitions within that.
    const transition1 = Instant.FromUtc(2000, 1, 1, 0, 0);
    const transition2 = Instant.FromUtc(2001, 1, 1, 0, 0);
    const transition3 = Instant.FromUtc(2002, 1, 1, 0, 0);
    // And one transition afterwards.
    const transition4 = Instant.FromUtc(2004, 1, 1, 0, 0);
    const zone = buildWithOptionsZone(transition1, transition2, transition3, transition4);
    const interval = new Interval(
      Instant.FromUtc(1999, 1, 1, 0, 0),
      Instant.FromUtc(2003, 1, 1, 0, 0));
    // The zone intervals abutting at transition2 are coalesced,
    // because that only changes the name and standard/daylight split.
    const zoneIntervals = [...zone.GetZoneIntervals(interval, ZoneEqualityComparer.Options.OnlyMatchWallOffset)];
    expect(zoneIntervals.length).toBe(3);
    assertNodaEqual(zoneIntervals.map(zi => zi.End), [transition1, transition3, transition4]);
    assertNodaEqual(zoneIntervals.map(zi => zi.RawStart), [Instant.BeforeMinValue, transition1, transition3]);
    assertNodaEqual(zoneIntervals.map(zi => zi.Name), ["0+0", "1+1", "0+1"]);
  },

  // #endregion

  // #region DateTimeZoneTest.Ids.cs

  UtcIsNotNull() {
    expect(DateTimeZone.Utc).not.toBeNull();
    expect(DateTimeZone.Utc).toBeDefined();
  },

  // #endregion

  // #region DateTimeZoneTest.LocalConversions.cs

  AmbiguousStartOfDay_TransitionAtMidnight() {
    // Occurrence before transition
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2000, 6, 1, 0, 0).WithOffset(Offset.FromHours(-2)),
      TransitionBackwardToMidnightZone);
    const actual = TransitionBackwardToMidnightZone.AtStartOfDay(TransitionDate);
    assertNodaEqual(actual, expected);
    assertNodaEqual(TransitionDate.AtStartOfDayInZone(TransitionBackwardToMidnightZone), expected);
  },

  AmbiguousStartOfDay_TransitionAfterMidnight() {
    // Occurrence before transition
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2000, 6, 1, 0, 0).WithOffset(Offset.FromHours(-2)),
      TransitionBackwardAfterMidnightZone);
    const actual = TransitionBackwardAfterMidnightZone.AtStartOfDay(TransitionDate);
    assertNodaEqual(actual, expected);
    assertNodaEqual(TransitionDate.AtStartOfDayInZone(TransitionBackwardAfterMidnightZone), expected);
  },

  SkippedStartOfDay_TransitionAtMidnight() {
    // 1am because of the skip
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2000, 6, 1, 1, 0).WithOffset(Offset.FromHours(-1)),
      TransitionForwardAtMidnightZone);
    const actual = TransitionForwardAtMidnightZone.AtStartOfDay(TransitionDate);
    assertNodaEqual(actual, expected);
    assertNodaEqual(TransitionDate.AtStartOfDayInZone(TransitionForwardAtMidnightZone), expected);
  },

  SkippedStartOfDay_TransitionBeforeMidnight() {
    // 12.20am because of the skip
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2000, 6, 1, 0, 20).WithOffset(Offset.FromHours(-1)),
      TransitionForwardBeforeMidnightZone);
    const actual = TransitionForwardBeforeMidnightZone.AtStartOfDay(TransitionDate);
    assertNodaEqual(actual, expected);
    assertNodaEqual(TransitionDate.AtStartOfDayInZone(TransitionForwardBeforeMidnightZone), expected);
  },

  UnambiguousStartOfDay() {
    // Just a simple midnight in March.
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2000, 3, 1, 0, 0).WithOffset(Offset.FromHours(-2)),
      TransitionForwardAtMidnightZone);
    const actual = TransitionForwardAtMidnightZone.AtStartOfDay(new LocalDate(2000, 3, 1));
    assertNodaEqual(actual, expected);
    assertNodaEqual(new LocalDate(2000, 3, 1).AtStartOfDayInZone(TransitionForwardAtMidnightZone), expected);
  },

  // Los Angeles goes from -7 to -8 on November 7th 2010 at 2am wall time
  GetOffsetFromLocal_LosAngelesFallTransition() {
    const before = new LocalDateTime(2010, 11, 7, 0, 30);
    const atTransition = new LocalDateTime(2010, 11, 7, 1, 0);
    const ambiguous = new LocalDateTime(2010, 11, 7, 1, 30);
    const after = new LocalDateTime(2010, 11, 7, 2, 30);
    assertOffset(-7, before, LosAngeles);
    assertAmbiguous(atTransition, LosAngeles);
    assertAmbiguous(ambiguous, LosAngeles);
    assertOffset(-8, after, LosAngeles);
  },

  GetOffsetFromLocal_LosAngelesSpringTransition() {
    const before = new LocalDateTime(2010, 3, 14, 1, 30);
    const impossible = new LocalDateTime(2010, 3, 14, 2, 30);
    const atTransition = new LocalDateTime(2010, 3, 14, 3, 0);
    const after = new LocalDateTime(2010, 3, 14, 3, 30);
    assertOffset(-8, before, LosAngeles);
    assertImpossible(impossible, LosAngeles);
    assertOffset(-7, atTransition, LosAngeles);
    assertOffset(-7, after, LosAngeles);
  },

  // New Zealand goes from +13 to +12 on April 4th 2010 at 3am wall time
  GetOffsetFromLocal_NewZealandFallTransition() {
    const before = new LocalDateTime(2010, 4, 4, 1, 30);
    const atTransition = new LocalDateTime(2010, 4, 4, 2, 0);
    const ambiguous = new LocalDateTime(2010, 4, 4, 2, 30);
    const after = new LocalDateTime(2010, 4, 4, 3, 30);
    assertOffset(+13, before, NewZealand);
    assertAmbiguous(atTransition, NewZealand);
    assertAmbiguous(ambiguous, NewZealand);
    assertOffset(+12, after, NewZealand);
  },

  // New Zealand goes from +12 to +13 on September 26th 2010 at 2am wall time
  GetOffsetFromLocal_NewZealandSpringTransition() {
    const before = new LocalDateTime(2010, 9, 26, 1, 30);
    const impossible = new LocalDateTime(2010, 9, 26, 2, 30);
    const atTransition = new LocalDateTime(2010, 9, 26, 3, 0);
    const after = new LocalDateTime(2010, 9, 26, 3, 30);
    assertOffset(+12, before, NewZealand);
    assertImpossible(impossible, NewZealand);
    assertOffset(+13, atTransition, NewZealand);
    assertOffset(+13, after, NewZealand);
  },

  // Paris goes from +1 to +2 on March 28th 2010 at 2am wall time
  GetOffsetFromLocal_ParisFallTransition() {
    const before = new LocalDateTime(2010, 10, 31, 1, 30);
    const atTransition = new LocalDateTime(2010, 10, 31, 2, 0);
    const ambiguous = new LocalDateTime(2010, 10, 31, 2, 30);
    const after = new LocalDateTime(2010, 10, 31, 3, 30);
    assertOffset(2, before, Paris);
    assertAmbiguous(ambiguous, Paris);
    assertAmbiguous(atTransition, Paris);
    assertOffset(1, after, Paris);
  },

  GetOffsetFromLocal_ParisSpringTransition() {
    const before = new LocalDateTime(2010, 3, 28, 1, 30);
    const impossible = new LocalDateTime(2010, 3, 28, 2, 30);
    const atTransition = new LocalDateTime(2010, 3, 28, 3, 0);
    const after = new LocalDateTime(2010, 3, 28, 3, 30);
    assertOffset(1, before, Paris);
    assertImpossible(impossible, Paris);
    assertOffset(2, atTransition, Paris);
    assertOffset(2, after, Paris);
  },

  MapLocalDateTime_UnambiguousDateReturnsUnambiguousMapping() {
    //2011-11-09 01:30:00 - not ambiguous in America/New York timezone
    const unambiguousTime = new LocalDateTime(2011, 11, 9, 1, 30);
    const mapping = NewYork.MapLocal(unambiguousTime);
    expect(mapping.Count).toBe(1);
  },

  MapLocalDateTime_AmbiguousDateReturnsAmbiguousMapping() {
    //2011-11-06 01:30:00 - falls during DST - EST conversion in America/New York timezone
    const ambiguousTime = new LocalDateTime(2011, 11, 6, 1, 30);
    const mapping = NewYork.MapLocal(ambiguousTime);
    expect(mapping.Count).toBe(2);
  },

  MapLocalDateTime_SkippedDateReturnsSkippedMapping() {
    //2011-03-13 02:30:00 - falls during EST - DST conversion in America/New York timezone
    const skippedTime = new LocalDateTime(2011, 3, 13, 2, 30);
    const mapping = NewYork.MapLocal(skippedTime);
    expect(mapping.Count).toBe(0);
  },

  // Some zones skipped dates by changing from UTC-lots to UTC+lots. For example, Samoa (Pacific/Apia)
  // skipped December 30th 2011, going from  23:59:59 December 29th local time UTC-10
  // to 00:00:00 December 31st local time UTC+14
  AtStartOfDay_DayDoesntExist(zoneId: string, localDate: string) {
    const badDate = LocalDatePattern.Iso.Parse(localDate).Value;
    const zone = tzdb.Get(zoneId);
    const exception = assertThrows(SkippedTimeError, () => zone.AtStartOfDay(badDate));
    assertNodaEqual(exception.LocalDateTime, LocalDate.Add(badDate, LocalTime.Midnight));
  },

  AtStrictly_InWinter() {
    const when = Pacific.AtStrictly(new LocalDateTime(2009, 12, 22, 21, 39, 30));

    expect(when.Year).toBe(2009);
    expect(when.Month).toBe(12);
    expect(when.Day).toBe(22);
    expect(when.DayOfWeek).toBe(IsoDayOfWeek.Tuesday);
    expect(when.Hour).toBe(21);
    expect(when.Minute).toBe(39);
    expect(when.Second).toBe(30);
    assertNodaEqual(when.Offset, Offset.FromHours(-8));
  },

  AtStrictly_InSummer() {
    const when = Pacific.AtStrictly(new LocalDateTime(2009, 6, 22, 21, 39, 30));

    expect(when.Year).toBe(2009);
    expect(when.Month).toBe(6);
    expect(when.Day).toBe(22);
    expect(when.Hour).toBe(21);
    expect(when.Minute).toBe(39);
    expect(when.Second).toBe(30);
    assertNodaEqual(when.Offset, Offset.FromHours(-7));
  },

  /**
   * Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
   * so 2am became 1am.
   */
  AtStrictly_ThrowsWhenAmbiguous() {
    assertThrows(AmbiguousTimeError, () => Pacific.AtStrictly(new LocalDateTime(2009, 11, 1, 1, 30, 0)));
  },

  /**
   * Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
   * so 2am became 3am. This means that 2.30am doesn't exist on that day.
   */
  AtStrictly_ThrowsWhenSkipped() {
    assertThrows(SkippedTimeError, () => Pacific.AtStrictly(new LocalDateTime(2009, 3, 8, 2, 30, 0)));
  },

  /**
   * Pacific time changed from -7 to -8 at 2am wall time on November 2nd 2009,
   * so 2am became 1am. We'll return the earlier result, i.e. with the offset of -7
   */
  AtLeniently_AmbiguousTime_ReturnsEarlierMapping() {
    const local = new LocalDateTime(2009, 11, 1, 1, 30, 0);
    const zoned = Pacific.AtLeniently(local);
    assertNodaEqual(zoned.LocalDateTime, local);
    assertNodaEqual(zoned.Offset, Offset.FromHours(-7));
  },

  /**
   * Pacific time changed from -8 to -7 at 2am wall time on March 8th 2009,
   * so 2am became 3am. This means that 2:30am doesn't exist on that day.
   * We'll return 3:30am, the forward-shifted value.
   */
  AtLeniently_ReturnsForwardShiftedValue() {
    const local = new LocalDateTime(2009, 3, 8, 2, 30, 0);
    const zoned = Pacific.AtLeniently(local);
    assertNodaEqual(zoned.LocalDateTime, new LocalDateTime(2009, 3, 8, 3, 30, 0));
    assertNodaEqual(zoned.Offset, Offset.FromHours(-7));
  },

  ResolveLocal() {
    // Don't need much for this - it only delegates.
    const ambiguous = new LocalDateTime(2009, 11, 1, 1, 30, 0);
    const skipped = new LocalDateTime(2009, 3, 8, 2, 30, 0);
    assertNodaEqual(Pacific.ResolveLocal(ambiguous, Resolvers.LenientResolver), Pacific.AtLeniently(ambiguous));
    assertNodaEqual(Pacific.ResolveLocal(skipped, Resolvers.LenientResolver), Pacific.AtLeniently(skipped));
  },

  // #endregion

  // #region DateTimeZoneTest.MapLocal.cs

  // Time zone with an ambiguity
  ZoneWithAmbiguity_NearStartOfTime() {
    const mapping = ZoneWithAmbiguity.MapLocal(new LocalDateTime(-9998, 1, 5, 0, 0));
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
  },

  ZoneWithAmbiguity_NearEndOfTime() {
    const mapping = ZoneWithAmbiguity.MapLocal(NearEndOfTime);
    checkMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
  },

  ZoneWithAmbiguity_WellBeforeTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(YearBeforeTransition);
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
  },

  ZoneWithAmbiguity_WellAfterTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(YearAfterTransition);
    checkMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
  },

  ZoneWithAmbiguity_JustBeforeAmbiguity() {
    const mapping = ZoneWithAmbiguity.MapLocal(TransitionMinus5.PlusNanoseconds(-1));
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalBeforeAmbiguity, 1);
  },

  ZoneWithAmbiguity_JustAfterTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10.PlusNanoseconds(1));
    checkMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
  },

  ZoneWithAmbiguity_StartOfTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(TransitionMinus5);
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
  },

  ZoneWithAmbiguity_MidTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(MidTransition);
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
  },

  ZoneWithAmbiguity_LastTickOfTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10.PlusNanoseconds(-1));
    checkMapping(mapping, IntervalBeforeAmbiguity, IntervalAfterAmbiguity, 2);
  },

  ZoneWithAmbiguity_FirstTickAfterTransition() {
    const mapping = ZoneWithAmbiguity.MapLocal(TransitionPlus10);
    checkMapping(mapping, IntervalAfterAmbiguity, IntervalAfterAmbiguity, 1);
  },

  // Time zone with a gap
  ZoneWithGap_NearStartOfTime() {
    const mapping = ZoneWithGap.MapLocal(NearStartOfTime);
    checkMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
  },

  ZoneWithGap_NearEndOfTime() {
    const mapping = ZoneWithGap.MapLocal(NearEndOfTime);
    checkMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
  },

  ZoneWithGap_WellBeforeTransition() {
    const mapping = ZoneWithGap.MapLocal(YearBeforeTransition);
    checkMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
  },

  ZoneWithGap_WellAfterTransition() {
    const mapping = ZoneWithGap.MapLocal(YearAfterTransition);
    checkMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
  },

  ZoneWithGap_JustBeforeGap() {
    const mapping = ZoneWithGap.MapLocal(TransitionMinus5.PlusNanoseconds(-1));
    checkMapping(mapping, IntervalBeforeGap, IntervalBeforeGap, 1);
  },

  ZoneWithGap_JustAfterTransition() {
    const mapping = ZoneWithGap.MapLocal(TransitionPlus10.PlusNanoseconds(1));
    checkMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
  },

  ZoneWithGap_StartOfTransition() {
    const mapping = ZoneWithGap.MapLocal(TransitionMinus5);
    checkMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
  },

  ZoneWithGap_MidTransition() {
    const mapping = ZoneWithGap.MapLocal(MidTransition);
    checkMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
  },

  ZoneWithGap_LastTickOfTransition() {
    const mapping = ZoneWithGap.MapLocal(TransitionPlus10.PlusNanoseconds(-1));
    checkMapping(mapping, IntervalBeforeGap, IntervalAfterGap, 0);
  },

  ZoneWithGap_FirstTickAfterTransition() {
    const mapping = ZoneWithGap.MapLocal(TransitionPlus10);
    checkMapping(mapping, IntervalAfterGap, IntervalAfterGap, 1);
  },

  /**
   * Case added to cover everything: we want our initial guess to hit the
   * *later* zone, which doesn't actually include the local instant. However,
   * we want the *earlier* zone to include it. So, we want a zone with two
   * positive offsets.
   */
  TrickyCase() {
    // 1am occurs unambiguously in the early zone.
    const zone = new SingleTransitionDateTimeZone(Transition, Offset.FromHours(3), Offset.FromHours(5));
    const mapping = zone.MapLocal(new LocalDateTime(2000, 1, 1, 1, 0));
    checkMapping(mapping, zone.EarlyInterval, zone.EarlyInterval, 1);
  },

  // #endregion
});
