// Ported from NodaTime 3.3.0: src/NodaTime.Test/OffsetDateTimeTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators map to OffsetDateTime.add / subtract; OffsetDateTime.With(Func<LocalTime, LocalTime>) is
// withTimeAdjuster. DateTimeZoneProviders.Tzdb is `tzdb` from the bundled tzdb entry point.

import { expect } from "vitest";
import {
  ArgumentError,
  CalendarSystem,
  NodaCultureInfo,
  DateAdjusters,
  DateTimeZone,
  Duration,
  Instant,
  LocalDate,
  LocalDateTime,
  LocalTime,
  NodaConstants,
  Offset,
  OffsetDate,
  OffsetDateTime,
  OffsetTime,
  TimeAdjusters,
  ZonedDateTime,
} from "../../src/noda-js/internal.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/OffsetDateTimeTest.generated.ts";

/** The instance getters declared on a class (C# Type.DeclaredProperties, instance members only). */
function declaredGetters(type: { prototype: object }): string[] {
  return Object.entries(Object.getOwnPropertyDescriptors(type.prototype))
    .filter(([, descriptor]) => descriptor.get !== undefined)
    .map(([name]) => name);
}

port(fixture, {
  LocalDateTimeProperties() {
    const local = new LocalDateTime(2012, 6, 19, 1, 2, 3, CalendarSystem.Julian).PlusNanoseconds(123456789);
    const offset = Offset.FromHours(5);

    const odt = new OffsetDateTime(local, offset);

    const localDateTimePropertyNames = new Set(declaredGetters(LocalDateTime));
    const commonProperties = declaredGetters(OffsetDateTime).filter(p => localDateTimePropertyNames.has(p));
    expect(commonProperties.length).toBeGreaterThan(0);
    for (const property of commonProperties) {
      assertNodaEqual((odt as any)[property], (local as any)[property], property);
    }
  },

  OffsetProperty() {
    const offset = Offset.FromHours(5);

    const odt = new OffsetDateTime(new LocalDateTime(2012, 1, 2, 3, 4), offset);
    assertNodaEqual(odt.Offset, offset);
  },

  LocalDateTimeProperty() {
    const local = new LocalDateTime(2012, 6, 19, 1, 2, 3, CalendarSystem.Julian).PlusNanoseconds(123456789);
    const offset = Offset.FromHours(5);

    const odt = new OffsetDateTime(local, offset);
    assertNodaEqual(odt.LocalDateTime, local);
  },

  ToInstant() {
    const instant = Instant.FromUtc(2012, 6, 25, 16, 5, 20);
    const local = new LocalDateTime(2012, 6, 25, 21, 35, 20);
    const offset = Offset.FromHoursAndMinutes(5, 30);

    const odt = new OffsetDateTime(local, offset);
    assertNodaEqual(odt.ToInstant(), instant);
  },

  Equality() {
    const local1 = new LocalDateTime(2012, 10, 6, 1, 2, 3);
    const local2 = new LocalDateTime(2012, 9, 5, 1, 2, 3);
    const offset1 = Offset.FromHours(1);
    const offset2 = Offset.FromHours(2);

    const equal1 = new OffsetDateTime(local1, offset1);
    const equal2 = new OffsetDateTime(local1, offset1);
    const unequalByOffset = new OffsetDateTime(local1, offset2);
    const unequalByLocal = new OffsetDateTime(local2, offset1);

    TestHelper.testEqualsStruct(equal1, equal2, unequalByOffset);
    TestHelper.testEqualsStruct(equal1, equal2, unequalByLocal);

    TestHelper.testOperatorEquality(equal1, equal2, unequalByOffset);
    TestHelper.testOperatorEquality(equal1, equal2, unequalByLocal);
  },

  InFixedZone() {
    const offset = Offset.FromHours(5);
    const local = new LocalDateTime(2012, 1, 2, 3, 4);
    const odt = new OffsetDateTime(local, offset);

    const zoned = odt.InFixedZone();
    assertNodaEqual(zoned, DateTimeZone.ForOffset(offset).AtStrictly(local));
  },

  ToString_WholeHourOffset() {
    const local = new LocalDateTime(2012, 10, 6, 1, 2, 3);
    const offset = Offset.FromHours(1);
    const odt = new OffsetDateTime(local, offset);
    assertNodaEqual(odt.toString(), "2012-10-06T01:02:03+01");
  },

  ToString_PartHourOffset() {
    const local = new LocalDateTime(2012, 10, 6, 1, 2, 3);
    const offset = Offset.FromHoursAndMinutes(1, 30);
    const odt = new OffsetDateTime(local, offset);
    assertNodaEqual(odt.toString(), "2012-10-06T01:02:03+01:30");
  },

  ToString_Utc() {
    const local = new LocalDateTime(2012, 10, 6, 1, 2, 3);
    const odt = new OffsetDateTime(local, Offset.Zero);
    assertNodaEqual(odt.toString(), "2012-10-06T01:02:03Z");
  },

  ToString_WithFormat() {
    const local = new LocalDateTime(2012, 10, 6, 1, 2, 3);
    const offset = Offset.FromHours(1);
    const odt = new OffsetDateTime(local, offset);
    assertNodaEqual(odt.toString("uuuu/MM/dd HH:mm:ss o<-HH>", NodaCultureInfo.InvariantCulture), "2012/10/06 01:02:03 01");
  },

  LocalComparer() {
    // noda-js: the GetHashCode checks are omitted (GetHashCode isn't ported).
    const localControl = new LocalDateTime(2013, 4, 2, 19, 54);
    const control = new OffsetDateTime(localControl, Offset.Zero);
    const negativeOffset = control.LocalDateTime.WithOffset(Offset.FromHours(-1));
    const positiveOffset = control.LocalDateTime.WithOffset(Offset.FromHours(1));
    const differentCalendar = control.LocalDateTime.WithCalendar(CalendarSystem.Coptic).WithOffset(Offset.FromHours(5));
    // Later instant, earlier local
    const earlierLocal = control.LocalDateTime.PlusHours(-2).WithOffset(Offset.FromHours(-10));
    // Same offset, previous day
    const muchEarlierLocal = control.PlusHours(-24);
    // Earlier instant, later local
    const laterLocal = control.LocalDateTime.PlusHours(2).WithOffset(Offset.FromHours(10));
    // Same offset, next day
    const muchLaterLocal = control.PlusHours(24);

    const comparer = OffsetDateTime.Comparer.Local;

    assertNodaEqual(comparer.Compare(control, negativeOffset), 0);
    assertNodaEqual(comparer.Compare(control, positiveOffset), 0);
    assertThrows(ArgumentError, () => comparer.Compare(control, differentCalendar));
    assertNodaEqual(Math.sign(comparer.Compare(control, earlierLocal)), 1);
    assertNodaEqual(Math.sign(comparer.Compare(control, muchEarlierLocal)), 1);
    assertNodaEqual(Math.sign(comparer.Compare(earlierLocal, control)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(muchEarlierLocal, control)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(control, laterLocal)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(control, muchLaterLocal)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(laterLocal, control)), 1);
    assertNodaEqual(Math.sign(comparer.Compare(muchLaterLocal, control)), 1);

    expect(comparer.Equals(control, differentCalendar)).toBe(false);
    expect(comparer.Equals(control, earlierLocal)).toBe(false);
    expect(comparer.Equals(control, muchEarlierLocal)).toBe(false);
    expect(comparer.Equals(control, laterLocal)).toBe(false);
    expect(comparer.Equals(control, muchLaterLocal)).toBe(false);
    expect(comparer.Equals(control, control)).toBe(true);
  },

  InstantComparer() {
    // noda-js: the GetHashCode checks are omitted (GetHashCode isn't ported).
    const localControl = new LocalDateTime(2013, 4, 2, 19, 54);
    const control = new OffsetDateTime(localControl, Offset.Zero);
    const equalAndOppositeChanges = control.LocalDateTime.PlusHours(1).WithOffset(Offset.FromHours(1));
    const differentCalendar = control.LocalDateTime.WithCalendar(CalendarSystem.Coptic).WithOffset(Offset.Zero);

    // Negative offset means later instant
    const negativeOffset = control.LocalDateTime.WithOffset(Offset.FromHours(-1));
    // Positive offset means earlier instant
    const positiveOffset = control.LocalDateTime.WithOffset(Offset.FromHours(1));

    // Later instant, earlier local
    const earlierLocal = control.LocalDateTime.PlusHours(-2).WithOffset(Offset.FromHours(-10));
    // Earlier instant, later local
    const laterLocal = control.LocalDateTime.PlusHours(2).WithOffset(Offset.FromHours(10));

    const comparer = OffsetDateTime.Comparer.Instant;

    assertNodaEqual(comparer.Compare(control, differentCalendar), 0);
    assertNodaEqual(comparer.Compare(control, equalAndOppositeChanges), 0);

    assertNodaEqual(Math.sign(comparer.Compare(control, negativeOffset)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(negativeOffset, control)), 1);
    assertNodaEqual(comparer.Compare(control, positiveOffset), 1);
    assertNodaEqual(Math.sign(comparer.Compare(positiveOffset, control)), -1);

    assertNodaEqual(Math.sign(comparer.Compare(control, earlierLocal)), -1);
    assertNodaEqual(Math.sign(comparer.Compare(earlierLocal, control)), 1);
    assertNodaEqual(Math.sign(comparer.Compare(control, laterLocal)), 1);
    assertNodaEqual(Math.sign(comparer.Compare(laterLocal, control)), -1);

    expect(comparer.Equals(control, differentCalendar)).toBe(true);
    expect(comparer.Equals(control, earlierLocal)).toBe(false);
    expect(comparer.Equals(control, equalAndOppositeChanges)).toBe(true);
  },

  Subtraction_Duration() {
    // Test all three approaches... not bothering to check a different calendar,
    // but we'll use two different offsets.
    const end = new LocalDateTime(2014, 8, 14, 15, 0).WithOffset(Offset.FromHours(1));
    const duration = Duration.Add(Duration.FromHours(8), Duration.FromMinutes(9));
    const expected = new LocalDateTime(2014, 8, 14, 6, 51).WithOffset(Offset.FromHours(1));
    assertNodaEqual(OffsetDateTime.Subtract(end, duration), expected);
    assertNodaEqual(end.Minus(duration), expected);
    assertNodaEqual(OffsetDateTime.Subtract(end, duration), expected);
  },

  Addition_Duration() {
    const minutes = 23;
    const hours = 3;
    const milliseconds = 40000;
    const seconds = 321;
    const nanoseconds = 12345;
    const ticks = 5432112345;

    // Test all three approaches... not bothering to check a different calendar,
    // but we'll use two different offsets.
    const start = new LocalDateTime(2014, 8, 14, 6, 51).WithOffset(Offset.FromHours(1));
    const duration = Duration.Add(Duration.FromHours(8), Duration.FromMinutes(9));
    const expected = new LocalDateTime(2014, 8, 14, 15, 0).WithOffset(Offset.FromHours(1));
    assertNodaEqual(OffsetDateTime.Add(start, duration), expected);
    assertNodaEqual(start.Plus(duration), expected);
    assertNodaEqual(OffsetDateTime.Add(start, duration), expected);

    assertNodaEqual(start.PlusHours(hours), OffsetDateTime.Add(start, Duration.FromHours(hours)));
    assertNodaEqual(start.PlusHours(-hours), OffsetDateTime.Add(start, Duration.FromHours(-hours)));

    assertNodaEqual(start.PlusMinutes(minutes), OffsetDateTime.Add(start, Duration.FromMinutes(minutes)));
    assertNodaEqual(start.PlusMinutes(-minutes), OffsetDateTime.Add(start, Duration.FromMinutes(-minutes)));

    assertNodaEqual(start.PlusSeconds(seconds), OffsetDateTime.Add(start, Duration.FromSeconds(seconds)));
    assertNodaEqual(start.PlusSeconds(-seconds), OffsetDateTime.Add(start, Duration.FromSeconds(-seconds)));

    assertNodaEqual(start.PlusMilliseconds(milliseconds), OffsetDateTime.Add(start, Duration.FromMilliseconds(milliseconds)));
    assertNodaEqual(start.PlusMilliseconds(-milliseconds), OffsetDateTime.Add(start, Duration.FromMilliseconds(-milliseconds)));

    assertNodaEqual(start.PlusTicks(ticks), OffsetDateTime.Add(start, Duration.FromTicks(ticks)));
    assertNodaEqual(start.PlusTicks(-ticks), OffsetDateTime.Add(start, Duration.FromTicks(-ticks)));

    assertNodaEqual(start.PlusNanoseconds(nanoseconds), OffsetDateTime.Add(start, Duration.FromNanoseconds(nanoseconds)));
    assertNodaEqual(start.PlusNanoseconds(-nanoseconds), OffsetDateTime.Add(start, Duration.FromNanoseconds(-nanoseconds)));
  },

  Subtraction_OffsetDateTime() {
    // Test all three approaches... not bothering to check a different calendar,
    // but we'll use two different offsets.
    const start = new LocalDateTime(2014, 8, 14, 6, 51).WithOffset(Offset.FromHours(1));
    const end = new LocalDateTime(2014, 8, 14, 18, 0).WithOffset(Offset.FromHours(4));
    const expected = Duration.Add(Duration.FromHours(8), Duration.FromMinutes(9));
    assertNodaEqual(OffsetDateTime.Subtract(end, start), expected);
    assertNodaEqual(end.Minus(start), expected);
    assertNodaEqual(OffsetDateTime.Subtract(end, start), expected);
  },

  WithOffset() {
    const morning = new LocalDateTime(2014, 1, 31, 9, 30);
    const original = new OffsetDateTime(morning, Offset.FromHours(-8));
    const evening = new LocalDateTime(2014, 1, 31, 19, 30);
    const newOffset = Offset.FromHours(2);
    const expected = new OffsetDateTime(evening, newOffset);
    assertNodaEqual(original.WithOffset(newOffset), expected);
  },

  WithOffset_CrossDates() {
    const noon = new OffsetDateTime(new LocalDateTime(2017, 8, 22, 12, 0, 0), Offset.FromHours(0));
    const previousNight = noon.WithOffset(Offset.FromHours(-14));
    const nextMorning = noon.WithOffset(Offset.FromHours(14));
    assertNodaEqual(previousNight.LocalDateTime, new LocalDateTime(2017, 8, 21, 22, 0, 0));
    assertNodaEqual(nextMorning.LocalDateTime, new LocalDateTime(2017, 8, 23, 2, 0, 0));
  },

  WithOffset_TwoDaysForwardAndBack() {
    // Go from UTC-18 to UTC+18
    const night = new OffsetDateTime(new LocalDateTime(2017, 8, 21, 18, 0, 0), Offset.FromHours(-18));
    const morning = night.WithOffset(Offset.FromHours(18));
    assertNodaEqual(morning.LocalDateTime, new LocalDateTime(2017, 8, 23, 6, 0, 0));
    const backAgain = morning.WithOffset(Offset.FromHours(-18));
    assertNodaEqual(backAgain, night);
  },

  WithCalendar() {
    const julianCalendar = CalendarSystem.Julian;
    const gregorianEpoch = NodaConstants.UnixEpoch.WithOffset(Offset.Zero);

    const expected = new LocalDate(1969, 12, 19, julianCalendar).AtMidnight().WithOffset(Offset.FromHours(0));
    const actual = gregorianEpoch.WithCalendar(CalendarSystem.Julian);
    assertNodaEqual(actual, expected);
  },

  With_TimeAdjuster() {
    const offset = Offset.FromHoursAndMinutes(2, 30);
    const start = new LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
    const expected = new LocalDateTime(2014, 6, 27, 12, 15, 8).WithOffset(offset);
    assertNodaEqual(start.WithTimeAdjuster(TimeAdjusters.TruncateToSecond), expected);
  },

  With_DateAdjuster() {
    const offset = Offset.FromHoursAndMinutes(2, 30);
    const start = new LocalDateTime(2014, 6, 27, 12, 5, 8).PlusNanoseconds(123456789).WithOffset(offset);
    const expected = new LocalDateTime(2014, 6, 30, 12, 5, 8).PlusNanoseconds(123456789).WithOffset(offset);
    assertNodaEqual(start.With(DateAdjusters.EndOfMonth), expected);
  },

  InZone() {
    const offset = Offset.FromHours(-7);
    const start = new LocalDateTime(2017, 10, 31, 18, 12, 0).WithOffset(offset);
    const zone = tzdb.get("Europe/London");
    const zoned = start.InZone(zone);

    // On October 31st, the UK had already gone back, so the offset is 0.
    // Importantly, it's not the offset of the original OffsetDateTime: we're testing
    // that InZone *doesn't* require that.
    const expected = ZonedDateTime.NewOffsetDateTimeZone(new LocalDateTime(2017, 11, 1, 1, 12, 0).WithOffset(Offset.Zero), zone);
    assertNodaEqual(zoned, expected);
  },

  Deconstruction() {
    const dateTime = new LocalDateTime(2017, 10, 15, 21, 30);
    const offset = Offset.FromHours(-2);
    const value = new OffsetDateTime(dateTime, offset);

    // noda-js: Deconstruct is omitted; JS destructuring reads the getters.
    const { LocalDateTime: actualDateTime, Offset: actualOffset } = value;

    assertNodaEqual(actualDateTime, dateTime);
    assertNodaEqual(actualOffset, offset);
  },

  MoreGranularDeconstruction() {
    const date = new LocalDate(2017, 10, 15);
    const time = new LocalTime(21, 30, 15);
    const offset = Offset.FromHours(-2);

    const value = new OffsetDateTime(date.At(time), offset);

    // noda-js: Deconstruct is omitted; JS destructuring reads the getters.
    const { Date: actualDate, TimeOfDay: actualTime, Offset: actualOffset } = value;

    assertNodaEqual(actualDate, date);
    assertNodaEqual(actualTime, time);
    assertNodaEqual(actualOffset, offset);
  },

  ToOffsetDate() {
    const offset = Offset.FromHoursAndMinutes(2, 30);
    const odt = new LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
    const expected = new OffsetDate(new LocalDate(2014, 6, 27), offset);
    assertNodaEqual(odt.ToOffsetDate(), expected);
  },

  ToOffsetTime() {
    const offset = Offset.FromHoursAndMinutes(2, 30);
    const odt = new LocalDateTime(2014, 6, 27, 12, 15, 8).PlusNanoseconds(123456789).WithOffset(offset);
    const expected = new OffsetTime(new LocalTime(12, 15, 8).PlusNanoseconds(123456789), offset);
    assertNodaEqual(odt.ToOffsetTime(), expected);
  },
}, {
  skip: {
    ToDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_JulianCalendar: "BCL interop (DateTimeOffset, JulianCalendar) isn't ported",
    ToDateTimeOffset_TruncatedOffset: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_OffsetOutOfRange: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_OffsetEdgeOfRange: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_DateOutOfRange: "BCL interop (DateTimeOffset) isn't ported",
    ToDateTimeOffset_TruncateNanosTowardStartOfTime: "BCL interop (DateTimeOffset) isn't ported",
    FromDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported",
    DefaultConstructor: "C# default(OffsetDateTime) struct construction; OffsetDateTime has no parameterless constructor in noda-js",
    XmlSerialization_Iso: "XML serialization isn't ported",
    XmlSerialization_ZeroOffset: "XML serialization isn't ported",
    XmlSerialization_NonIso: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
