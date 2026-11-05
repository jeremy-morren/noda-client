// Ported from NodaTime 3.3.0: src/NodaTime.Test/ZonedDateTimeTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators map to ZonedDateTime.add / subtract. DateTimeZoneProviders.Tzdb is `tzdb` from the bundled
// tzdb entry point. The internal constructor ZonedDateTime(OffsetDateTime, DateTimeZone) is
// ZonedDateTime.newOffsetDateTimeZone.

import { expect } from "vitest";
import {
  ArgumentError,
  ArgumentNullError,
  CalendarSystem,
  NodaCultureInfo,
  DateTimeZone,
  Duration,
  Era,
  Instant,
  IsoDayOfWeek,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  Resolvers,
  SingleTransitionDateTimeZone,
  ZonedDateTime,
} from "../../src/noda-js/internal.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/ZonedDateTimeTest.generated.ts";

/** Changes from UTC+3 to UTC+4 at 1am local time on June 13th 2011. */
const SampleZone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 3, 4);

/** NUnit's Assert.AreNotEqual for noda-js values. */
function assertNotEqual(actual: { Equals(other: unknown): boolean }, notExpected: unknown): void {
  expect(actual.Equals(notExpected), `expected ${String(actual)} not to equal ${String(notExpected)}`).toBe(false);
}

port(fixture, {
  SimpleProperties() {
    const value = SampleZone.AtStrictly(new LocalDateTime(2012, 2, 10, 8, 9, 10).PlusNanoseconds(123456789));
    assertNodaEqual(value.Date, new LocalDate(2012, 2, 10));
    assertNodaEqual(value.TimeOfDay, LocalTime.FromHourMinuteSecondNanosecond(8, 9, 10, 123456789));
    assertNodaEqual(value.Era, Era.Common);
    assertNodaEqual(value.Year, 2012);
    assertNodaEqual(value.YearOfEra, 2012);
    assertNodaEqual(value.Month, 2);
    assertNodaEqual(value.Day, 10);
    assertNodaEqual(value.DayOfWeek, IsoDayOfWeek.Friday);
    assertNodaEqual(value.DayOfYear, 41);
    assertNodaEqual(value.ClockHourOfHalfDay, 8);
    assertNodaEqual(value.Hour, 8);
    assertNodaEqual(value.Minute, 9);
    assertNodaEqual(value.Second, 10);
    assertNodaEqual(value.Millisecond, 123);
    assertNodaEqual(value.TickOfSecond, 1234567);
    assertNodaEqual(value.TickOfDay,
      8 * NodaConstants.TicksPerHour +
      9 * NodaConstants.TicksPerMinute +
      10 * NodaConstants.TicksPerSecond +
      1234567);
    assertNodaEqual(value.NanosecondOfDay,
      8 * NodaConstants.NanosecondsPerHour +
      9 * NodaConstants.NanosecondsPerMinute +
      10 * NodaConstants.NanosecondsPerSecond +
      123456789);
  },

  Add_AroundTimeZoneTransition() {
    // Before the transition at 3pm...
    const before = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 12, 15, 0));
    // 24 hours elapsed, and it's 4pm
    const afterExpected = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 13, 16, 0));
    const afterAdd = ZonedDateTime.Add(before, Duration.OneDay);
    const afterOperator = ZonedDateTime.Add(before, Duration.OneDay);

    assertNodaEqual(afterAdd, afterExpected);
    assertNodaEqual(afterOperator, afterExpected);
  },

  Add_MethodEquivalents() {
    const minutes = 23;
    const hours = 3;
    const milliseconds = 40000;
    const seconds = 321;
    const nanoseconds = 12345;
    const ticks = 5432112345;

    const before = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 12, 15, 0));
    assertNodaEqual(ZonedDateTime.Add(before, Duration.OneDay), ZonedDateTime.Add(before, Duration.OneDay));
    assertNodaEqual(before.Plus(Duration.OneDay), ZonedDateTime.Add(before, Duration.OneDay));

    assertNodaEqual(before.PlusHours(hours), ZonedDateTime.Add(before, Duration.FromHours(hours)));
    assertNodaEqual(before.PlusHours(-hours), ZonedDateTime.Add(before, Duration.FromHours(-hours)));

    assertNodaEqual(before.PlusMinutes(minutes), ZonedDateTime.Add(before, Duration.FromMinutes(minutes)));
    assertNodaEqual(before.PlusMinutes(-minutes), ZonedDateTime.Add(before, Duration.FromMinutes(-minutes)));

    assertNodaEqual(before.PlusSeconds(seconds), ZonedDateTime.Add(before, Duration.FromSeconds(seconds)));
    assertNodaEqual(before.PlusSeconds(-seconds), ZonedDateTime.Add(before, Duration.FromSeconds(-seconds)));

    assertNodaEqual(before.PlusMilliseconds(milliseconds), ZonedDateTime.Add(before, Duration.FromMilliseconds(milliseconds)));
    assertNodaEqual(before.PlusMilliseconds(-milliseconds), ZonedDateTime.Add(before, Duration.FromMilliseconds(-milliseconds)));

    assertNodaEqual(before.PlusTicks(ticks), ZonedDateTime.Add(before, Duration.FromTicks(ticks)));
    assertNodaEqual(before.PlusTicks(-ticks), ZonedDateTime.Add(before, Duration.FromTicks(-ticks)));

    assertNodaEqual(before.PlusNanoseconds(nanoseconds), ZonedDateTime.Add(before, Duration.FromNanoseconds(nanoseconds)));
    assertNodaEqual(before.PlusNanoseconds(-nanoseconds), ZonedDateTime.Add(before, Duration.FromNanoseconds(-nanoseconds)));
  },

  Subtract_AroundTimeZoneTransition() {
    // After the transition at 4pm...
    const after = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 13, 16, 0));
    // 24 hours earlier, and it's 3pm
    const beforeExpected = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 12, 15, 0));
    const beforeSubtract = ZonedDateTime.Subtract(after, Duration.OneDay);
    const beforeOperator = ZonedDateTime.Subtract(after, Duration.OneDay);

    assertNodaEqual(beforeSubtract, beforeExpected);
    assertNodaEqual(beforeOperator, beforeExpected);
  },

  SubtractDuration_MethodEquivalents() {
    const after = SampleZone.AtStrictly(new LocalDateTime(2011, 6, 13, 16, 0));
    assertNodaEqual(ZonedDateTime.Subtract(after, Duration.OneDay), ZonedDateTime.Subtract(after, Duration.OneDay));
    assertNodaEqual(after.Minus(Duration.OneDay), ZonedDateTime.Subtract(after, Duration.OneDay));
  },

  Subtraction_ZonedDateTime() {
    // Test all three approaches... not bothering to check a different calendar,
    // but we'll use two different time zones.
    const start = new LocalDateTime(2014, 8, 14, 5, 51).InUtc();
    // Sample zone is UTC+4 at this point, so this is 14:00Z.
    const end = SampleZone.AtStrictly(new LocalDateTime(2014, 8, 14, 18, 0));
    const expected = Duration.Add(Duration.FromHours(8), Duration.FromMinutes(9));
    assertNodaEqual(ZonedDateTime.Subtract(end, start), expected);
    assertNodaEqual(end.Minus(start), expected);
    assertNodaEqual(ZonedDateTime.Subtract(end, start), expected);
  },

  WithZone() {
    const instant = Instant.FromUtc(2012, 2, 4, 12, 35);
    const zoned = new ZonedDateTime(instant, SampleZone);
    assertNodaEqual(zoned.LocalDateTime, new LocalDateTime(2012, 2, 4, 16, 35, 0));

    // Will be UTC-8 for our instant.
    const newZone: DateTimeZone = new SingleTransitionDateTimeZone(Instant.FromUtc(2000, 1, 1, 0, 0), -7, -8);
    const converted = zoned.WithZone(newZone);
    assertNodaEqual(converted.LocalDateTime, new LocalDateTime(2012, 2, 4, 4, 35, 0));
    assertNodaEqual(instant, converted.ToInstant());
  },

  IsDaylightSavings() {
    // Use a real time zone rather than a single-transition zone, so that we can get
    // a savings offset.
    const zone = tzdb.Get("Europe/London");
    const winterSummerTransition = Instant.FromUtc(2014, 3, 30, 1, 0);
    const winter = Instant.Subtract(winterSummerTransition, Duration.Epsilon).InZone(zone);
    const summer = winterSummerTransition.InZone(zone);
    expect(winter.IsDaylightSavingTime()).toBe(false);
    expect(summer.IsDaylightSavingTime()).toBe(true);
  },

  ToOffsetDateTime() {
    const local = new LocalDateTime(1911, 3, 5, 1, 0, 0); // Early interval
    const zoned = SampleZone.AtStrictly(local);
    const offsetDateTime = zoned.ToOffsetDateTime();
    assertNodaEqual(offsetDateTime.LocalDateTime, local);
    assertNodaEqual(offsetDateTime.Offset, SampleZone.EarlyInterval.WallOffset);
  },

  Equality() {
    // Goes back from 2am to 1am on June 13th
    const zone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);
    const sample = zone.MapLocal(new LocalDateTime(2011, 6, 13, 1, 30)).First();
    const fromUtc = Instant.FromUtc(2011, 6, 12, 21, 30).InZone(zone);

    // Checks all the overloads etc: first check is that the zone matters
    TestHelper.testEqualsStruct(sample, fromUtc, Instant.FromUtc(2011, 6, 12, 21, 30).InUtc());
    TestHelper.testOperatorEquality(sample, fromUtc, Instant.FromUtc(2011, 6, 12, 21, 30).InUtc());

    // Now just use a simple inequality check for other aspects...

    // Different offset
    const later = zone.MapLocal(new LocalDateTime(2011, 6, 13, 1, 30)).Last();
    assertNodaEqual(later.LocalDateTime, sample.LocalDateTime);
    assertNotEqual(later.Offset, sample.Offset);
    assertNotEqual(later, sample);

    // Different local time
    assertNotEqual(zone.MapLocal(new LocalDateTime(2011, 6, 13, 1, 29)).First(), sample);

    // Different calendar
    const withOtherCalendar = zone.MapLocal(new LocalDateTime(2011, 6, 13, 1, 30, CalendarSystem.Gregorian)).First();
    assertNotEqual(withOtherCalendar, sample);
  },

  Constructor_ArgumentValidation() {
    assertThrows(ArgumentNullError, () => new ZonedDateTime(Instant.FromUnixTimeTicks(1000), null as unknown as DateTimeZone));
    assertThrows(ArgumentNullError, () => new ZonedDateTime(Instant.FromUnixTimeTicks(1000), null as unknown as DateTimeZone, CalendarSystem.Iso));
    assertThrows(ArgumentNullError, () => new ZonedDateTime(Instant.FromUnixTimeTicks(1000), SampleZone, null as unknown as CalendarSystem));
  },

  Construct_FromLocal_ValidUnambiguousOffset() {
    const zone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

    const local = new LocalDateTime(2000, 1, 2, 3, 4, 5);
    const zoned = new ZonedDateTime(local, zone, zone.EarlyInterval.WallOffset);
    assertNodaEqual(local.InZoneStrictly(zone), zoned);
  },

  Construct_FromLocal_ValidEarlierOffset() {
    const zone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

    const local = new LocalDateTime(2011, 6, 13, 1, 30);
    const zoned = new ZonedDateTime(local, zone, zone.EarlyInterval.WallOffset);

    // Map the local time to the earlier of the offsets in a way which is tested elsewhere.
    const resolver = Resolvers.CreateMappingResolver(Resolvers.ReturnEarlier, Resolvers.ThrowWhenSkipped);
    assertNodaEqual(local.InZone(zone, resolver), zoned);
  },

  Construct_FromLocal_ValidLaterOffset() {
    const zone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

    const local = new LocalDateTime(2011, 6, 13, 1, 30);
    const zoned = new ZonedDateTime(local, zone, zone.LateInterval.WallOffset);

    // Map the local time to the later of the offsets in a way which is tested elsewhere.
    const resolver = Resolvers.CreateMappingResolver(Resolvers.ReturnLater, Resolvers.ThrowWhenSkipped);
    assertNodaEqual(local.InZone(zone, resolver), zoned);
  },

  Construct_FromLocal_InvalidOffset() {
    const zone = new SingleTransitionDateTimeZone(Instant.FromUtc(2011, 6, 12, 22, 0), 4, 3);

    // Attempt to ask for the later offset in the earlier interval
    const local = new LocalDateTime(2000, 1, 1, 0, 0, 0);
    assertThrows(ArgumentError, () => new ZonedDateTime(local, zone, zone.LateInterval.WallOffset));
  },

  ZonedDateTime_ToString() {
    const local = new LocalDateTime(2013, 7, 23, 13, 5, 20);
    const zoned = local.InZoneStrictly(SampleZone);
    assertNodaEqual(zoned.toString(), "2013-07-23T13:05:20 Single (+04)");
  },

  ZonedDateTime_ToString_WithFormat() {
    const local = new LocalDateTime(2013, 7, 23, 13, 5, 20);
    const zoned = local.InZoneStrictly(SampleZone);
    assertNodaEqual(zoned.toString("uuuu/MM/dd HH:mm:ss z", NodaCultureInfo.InvariantCulture), "2013/07/23 13:05:20 Single");
  },

  LocalComparer() {
    // noda-js: the londonPersian (CalendarSystem.PersianSimple) checks and GetHashCode checks are omitted (not ported).
    const london = tzdb.Get("Europe/London");
    const losAngeles = tzdb.Get("America/Los_Angeles");

    // LA is 8 hours behind London. So the London evening occurs before the LA afternoon.
    const londonEvening = new LocalDateTime(2014, 7, 9, 20, 32).InZoneStrictly(london);
    const losAngelesAfternoon = new LocalDateTime(2014, 7, 9, 14, 0).InZoneStrictly(losAngeles);

    // Same local time as losAngelesAfternoon
    const londonAfternoon = losAngelesAfternoon.LocalDateTime.InZoneStrictly(london);

    const comparer = ZonedDateTime.Comparer.Local;
    TestHelper.testComparerStruct(comparer, losAngelesAfternoon, londonAfternoon, londonEvening);
    expect(comparer.Equals(londonAfternoon, londonEvening)).toBe(false);
    expect(comparer.Equals(londonAfternoon, losAngelesAfternoon)).toBe(true);
  },

  InstantComparer() {
    // noda-js: the londonPersian (CalendarSystem.PersianSimple) checks and GetHashCode checks are omitted (not ported).
    const london = tzdb.Get("Europe/London");
    const losAngeles = tzdb.Get("America/Los_Angeles");

    // LA is 8 hours behind London. So the London evening occurs before the LA afternoon.
    const londonEvening = new LocalDateTime(2014, 7, 9, 20, 32).InZoneStrictly(london);
    const losAngelesAfternoon = new LocalDateTime(2014, 7, 9, 14, 0).InZoneStrictly(losAngeles);

    // Same instant as londonEvening
    const losAngelesLunchtime = new LocalDateTime(2014, 7, 9, 12, 32).InZoneStrictly(losAngeles);

    const comparer = ZonedDateTime.Comparer.Instant;
    TestHelper.testComparerStruct(comparer, londonEvening, losAngelesLunchtime, losAngelesAfternoon);
    expect(comparer.Equals(losAngelesLunchtime, londonEvening)).toBe(true);
    expect(comparer.Equals(losAngelesAfternoon, londonEvening)).toBe(false);
  },

  Deconstruction() {
    const saoPaulo = tzdb.Get("America/Sao_Paulo");
    const value = new LocalDateTime(2017, 10, 15, 21, 30, 15).InZoneStrictly(saoPaulo);
    const expectedDateTime = new LocalDateTime(2017, 10, 15, 21, 30, 15);
    const expectedZone = saoPaulo;
    const expectedOffset = Offset.FromHours(-2);

    // noda-js: Deconstruct is omitted; JS destructuring reads the getters.
    const { LocalDateTime: actualDateTime, Zone: actualZone, Offset: actualOffset } = value;

    assertNodaEqual(actualDateTime, expectedDateTime);
    assertNodaEqual(actualZone, expectedZone);
    assertNodaEqual(actualOffset, expectedOffset);
  },
}, {
  skip: {
    FromDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_JulianCalendar: "BCL interop (DateTimeOffset, JulianCalendar) isn't ported",
    ToDateTimeOffset_TruncatedOffset: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_OffsetOutOfRange: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_OffsetEdgeOfRange: "BCL interop (DateTimeOffset) isn't ported",
    ToBclTypes_DateOutOfRange: "BCL interop (DateTimeOffset, DateTime) isn't ported",
    ToBclTypes_TruncateNanosTowardStartOfTime: "BCL interop (DateTimeOffset, DateTime) isn't ported",
    ToDateTimeUtc: "BCL interop (DateTime) isn't ported",
    ToDateTimeUtc_InRangeAfterUtcAdjustment: "BCL interop (DateTime, DateTimeOffset) isn't ported",
    ToDateTimeUnspecified: "BCL interop (DateTime) isn't ported",
    ToDateTimeUnspecified_JulianCalendar: "BCL interop (DateTime, JulianCalendar) isn't ported",
    DefaultConstructor: "C# default(ZonedDateTime) struct construction; ZonedDateTime has no parameterless constructor in noda-js",
    XmlSerialization_Iso: "XML serialization isn't ported",
    XmlSerialization_Bcl: "XML serialization and BclDateTimeZone aren't ported",
    XmlSerialization_NonIso: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
