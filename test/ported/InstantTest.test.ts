// Ported from NodaTime 3.3.7: src/NodaTime.Test/InstantTest.cs, src/NodaTime.Test/InstantTest.Format.cs,
// src/NodaTime.Test/InstantTest.Operators.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators are Instant.add / plus (+), Instant.subtract / minus (-), Duration.negate (unary -),
// CompareTo / Equals (comparisons). C# long results are numbers (the nearest double beyond 2^53), so checks
// that need the exact tick count use ToUnixTimeTicksExact below.

import { expect } from "vitest";
import {
  CalendarSystem,
  DateTimeZone,
  Duration,
  Instant,
  Int64,
  InvalidPatternException,
  IslamicEpoch,
  IslamicLeapYearPattern,
  LocalDateTime,
  LocalInstant,
  NodaConstants,
  NodaCultureInfo,
  Offset,
  OffsetDateTime,
  TickArithmetic,
  type Int64Value,
} from "../../src/noda-js/internal.ts";
import { GetIslamicCalendar } from "../../src/noda-js/entries/calendars/islamic.ts";
import { tzdb } from "../../src/noda-js/entries/tzdb-bundled.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/InstantTest.generated.ts";

const one = Instant.FromUntrustedDuration(Duration.FromNanoseconds(1));
const threeMillion = Instant.FromUntrustedDuration(Duration.FromNanoseconds(3000000));
const negativeFiftyMillion = Instant.FromUntrustedDuration(Duration.FromNanoseconds(-50000000));

/**
 * noda-js: the exact C# long value of instant.ToUnixTimeTicks() (ToUnixTimeTicks() returns the nearest number,
 * which isn't exact beyond 2^53). Computed as Instant.ToUnixTimeTicks does, and checked against it.
 */
function toUnixTimeTicksExact(instant: Instant): Int64Value {
  const exact = TickArithmetic.BoundedDaysAndTickOfDayToTicks(
    instant.DaysSinceEpoch, Math.trunc(instant.NanosecondOfDay / NodaConstants.NanosecondsPerTick));
  expect(instant.ToUnixTimeTicks()).toBe(Int64.ToNumber(exact));
  return exact;
}

function testToStringBase(value: Instant, gvalue: string): void {
  let actual = value.toString();
  assertNodaEqual(actual, gvalue);
  actual = value.toString("g", null);
  assertNodaEqual(actual, gvalue);
  actual = value.toString("g", NodaCultureInfo.InvariantCulture);
  assertNodaEqual(actual, gvalue);

  actual = `${value}`;
  assertNodaEqual(actual, gvalue);
  // noda-js: JS template literals have no format strings; C# $"{value:g}" is value.ToString("g", null).
  actual = value.toString("g");
  assertNodaEqual(actual, gvalue);
}

port(fixture, {
  JulianDateConversions(julianDate: number, year: number, month: number, day: number, hour: number, minute: number, second: number) {
    // When dealing with floating point binary data, if we're accurate to 50 milliseconds, that's fine...
    // (0.000001 days = ~86ms, as a guide to the scale involved...)
    const actual = Instant.FromJulianDate(julianDate);
    const expected = new LocalDateTime(year, month, day, hour, minute, second, CalendarSystem.Julian).InUtc().ToInstant();
    expect(Math.abs(expected.ToUnixTimeMilliseconds() - actual.ToUnixTimeMilliseconds()),
      `Expected ${expected}, was ${actual}`).toBeLessThanOrEqual(50);
    expect(Math.abs(julianDate - expected.ToJulianDate())).toBeLessThanOrEqual(0.000001);
  },

  FromUtcNoSeconds() {
    const viaUtc = DateTimeZone.Utc.AtStrictly(new LocalDateTime(2008, 4, 3, 10, 35, 0)).ToInstant();
    assertNodaEqual(Instant.FromUtc(2008, 4, 3, 10, 35), viaUtc);
  },

  FromUtcWithSeconds() {
    const viaUtc = DateTimeZone.Utc.AtStrictly(new LocalDateTime(2008, 4, 3, 10, 35, 23)).ToInstant();
    assertNodaEqual(Instant.FromUtc(2008, 4, 3, 10, 35, 23), viaUtc);
  },

  InUtc() {
    const viaInstant = Instant.FromUtc(2008, 4, 3, 10, 35, 23).InUtc();
    const expected = DateTimeZone.Utc.AtStrictly(new LocalDateTime(2008, 4, 3, 10, 35, 23));
    assertNodaEqual(viaInstant, expected);
  },

  InZone() {
    const london = tzdb.Get("Europe/London");
    const viaInstant = Instant.FromUtc(2008, 6, 10, 13, 16, 17).InZone(london);

    // London is UTC+1 in the Summer, so the above is 14:16:17 local.
    const local = new LocalDateTime(2008, 6, 10, 14, 16, 17);
    const expected = london.AtStrictly(local);

    assertNodaEqual(viaInstant, expected);
  },

  WithOffset() {
    // Jon talks about Noda Time at Leetspeak in Sweden on October 12th 2013, at 13:15 UTC+2
    const instant = Instant.FromUtc(2013, 10, 12, 11, 15);
    const offset = Offset.FromHours(2);
    const actual = instant.WithOffset(offset);
    const expected = new OffsetDateTime(new LocalDateTime(2013, 10, 12, 13, 15), offset);
    assertNodaEqual(actual, expected);
  },

  WithOffset_NonIsoCalendar() {
    // October 12th 2013 ISO is 1434-12-07 Islamic
    const calendar = GetIslamicCalendar(IslamicLeapYearPattern.Base15, IslamicEpoch.Civil);
    const instant = Instant.FromUtc(2013, 10, 12, 11, 15);
    const offset = Offset.FromHours(2);
    const actual = instant.WithOffset(offset, calendar);
    const expected = new OffsetDateTime(new LocalDateTime(1434, 12, 7, 13, 15, calendar), offset);
    assertNodaEqual(actual, expected);
  },

  FromTicksSinceUnixEpoch() {
    const instant = Instant.FromUnixTimeTicks(12345);
    assertNodaEqual(instant.ToUnixTimeTicks(), 12345);
  },

  FromUnixTimeMilliseconds_Valid() {
    const actual = Instant.FromUnixTimeMilliseconds(12345);
    const expected = Instant.FromUnixTimeTicks(12345 * NodaConstants.TicksPerMillisecond);
    assertNodaEqual(actual, expected);
  },

  FromUnixTimeMilliseconds_TooLarge() {
    // noda-js: milliseconds is a number; long.MaxValue / 100 is beyond 2^53, so this passes the nearest number.
    assertThrows("ArgumentOutOfRangeException", () => Instant.FromUnixTimeMilliseconds(Int64.ToNumber(Int64.Divide(Int64.MaxValue, 100))));
  },

  FromUnixTimeMilliseconds_TooSmall() {
    assertThrows("ArgumentOutOfRangeException", () => Instant.FromUnixTimeMilliseconds(Int64.ToNumber(Int64.Divide(Int64.MinValue, 100))));
  },

  FromUnixTimeSeconds_Valid() {
    const actual = Instant.FromUnixTimeSeconds(12345);
    const expected = Instant.FromUnixTimeTicks(12345 * NodaConstants.TicksPerSecond);
    assertNodaEqual(actual, expected);
  },

  FromUnixTimeSeconds_TooLarge() {
    assertThrows("ArgumentOutOfRangeException", () => Instant.FromUnixTimeSeconds(Int64.ToNumber(Int64.Divide(Int64.MaxValue, 1000000))));
  },

  FromUnixTimeSeconds_TooSmall() {
    assertThrows("ArgumentOutOfRangeException", () => Instant.FromUnixTimeSeconds(Int64.ToNumber(Int64.Divide(Int64.MinValue, 1000000))));
  },

  ToUnixTimeSeconds(milliseconds: number, expectedSeconds: number) {
    const instant = Instant.FromUnixTimeMilliseconds(milliseconds);
    assertNodaEqual(instant.ToUnixTimeSeconds(), expectedSeconds);
  },

  ToUnixTimeSecondsAndNanoseconds(milliseconds: number, expectedSeconds: number, expectedNanoseconds: number) {
    const instant = Instant.FromUnixTimeMilliseconds(milliseconds);
    const { seconds: actualSeconds, nanoseconds: actualNanoseconds } = instant.ToUnixTimeSecondsAndNanoseconds();
    assertNodaEqual(actualSeconds, expectedSeconds);
    assertNodaEqual(actualNanoseconds, expectedNanoseconds);
  },

  ToUnixTimeMilliseconds(ticks: number, expectedMilliseconds: number) {
    const instant = Instant.FromUnixTimeTicks(ticks);
    assertNodaEqual(instant.ToUnixTimeMilliseconds(), expectedMilliseconds);
  },

  UnixConversions_ExtremeValues() {
    // Round down to a whole second to make round-tripping work.
    const max = Instant.Add(Instant.Subtract(Instant.MaxValue, Duration.FromSeconds(1)), Duration.Epsilon);
    assertNodaEqual(Instant.FromUnixTimeSeconds(max.ToUnixTimeSeconds()), max);
    assertNodaEqual(Instant.FromUnixTimeMilliseconds(max.ToUnixTimeMilliseconds()), max);
    // noda-js: the tick count is beyond 2^53, so it round-trips as its exact decimal string.
    assertNodaEqual(Instant.FromUnixTimeTicks(Int64.ToString(toUnixTimeTicksExact(max))), max);

    const min = Instant.MinValue;
    assertNodaEqual(Instant.FromUnixTimeSeconds(min.ToUnixTimeSeconds()), min);
    assertNodaEqual(Instant.FromUnixTimeMilliseconds(min.ToUnixTimeMilliseconds()), min);
    assertNodaEqual(Instant.FromUnixTimeTicks(Int64.ToString(toUnixTimeTicksExact(min))), min);
  },

  InZoneWithCalendar() {
    const copticCalendar = CalendarSystem.Coptic;
    const london = tzdb.Get("Europe/London");
    const viaInstant = Instant.FromUtc(2004, 6, 9, 11, 10).InZone(london, copticCalendar);

    // Date taken from CopticCalendarSystemTest. Time will be 12:10 (London is UTC+1 in Summer)
    const local = new LocalDateTime(1720, 10, 2, 12, 10, 0, copticCalendar);
    const expected = london.AtStrictly(local);
    assertNodaEqual(viaInstant, expected);
  },

  Max() {
    const x = Instant.FromUnixTimeTicks(100);
    const y = Instant.FromUnixTimeTicks(200);
    assertNodaEqual(Instant.Max(x, y), y);
    assertNodaEqual(Instant.Max(y, x), y);
    assertNodaEqual(Instant.Max(x, Instant.MinValue), x);
    assertNodaEqual(Instant.Max(Instant.MinValue, x), x);
    assertNodaEqual(Instant.Max(Instant.MaxValue, x), Instant.MaxValue);
    assertNodaEqual(Instant.Max(x, Instant.MaxValue), Instant.MaxValue);
  },

  Min() {
    const x = Instant.FromUnixTimeTicks(100);
    const y = Instant.FromUnixTimeTicks(200);
    assertNodaEqual(Instant.Min(x, y), x);
    assertNodaEqual(Instant.Min(y, x), x);
    assertNodaEqual(Instant.Min(x, Instant.MinValue), Instant.MinValue);
    assertNodaEqual(Instant.Min(Instant.MinValue, x), Instant.MinValue);
    assertNodaEqual(Instant.Min(Instant.MaxValue, x), x);
    assertNodaEqual(Instant.Min(x, Instant.MaxValue), x);
  },

  TicksTruncatesDown(nanoseconds: number, expectedTicks: number) {
    const nanos = Duration.FromNanoseconds(nanoseconds);
    const instant = Instant.FromUntrustedDuration(nanos);
    assertNodaEqual(instant.ToUnixTimeTicks(), expectedTicks);
  },

  IsValid() {
    expect(Instant.BeforeMinValue.IsValid).toBe(false);
    expect(Instant.MinValue.IsValid).toBe(true);
    expect(Instant.MaxValue.IsValid).toBe(true);
    expect(Instant.AfterMaxValue.IsValid).toBe(false);
  },

  InvalidValues() {
    expect(Instant.AfterMaxValue.CompareTo(Instant.MaxValue)).toBeGreaterThan(0);
    expect(Instant.BeforeMinValue.CompareTo(Instant.MinValue)).toBeLessThan(0);
  },

  PlusDuration_Overflow() {
    TestHelper.assertOverflow(() => Instant.MinValue.Plus(Duration.Negate(Duration.Epsilon)));
    TestHelper.assertOverflow(() => Instant.MaxValue.Plus(Duration.Epsilon));
  },

  ExtremeArithmetic() {
    const hugeAndPositive = Instant.Subtract(Instant.MaxValue, Instant.MinValue);
    const hugeAndNegative = Instant.Subtract(Instant.MinValue, Instant.MaxValue);
    assertNodaEqual(Duration.Negate(hugeAndPositive), hugeAndNegative);
    assertNodaEqual(Instant.Subtract(Instant.MinValue, hugeAndNegative), Instant.MaxValue);
    assertNodaEqual(Instant.Add(Instant.MinValue, hugeAndPositive), Instant.MaxValue);
    assertNodaEqual(Instant.Add(Instant.MaxValue, hugeAndNegative), Instant.MinValue);
    assertNodaEqual(Instant.Subtract(Instant.MaxValue, hugeAndPositive), Instant.MinValue);
  },

  PlusOffset_Overflow() {
    TestHelper.assertOverflow(() => Instant.MinValue.Plus(Offset.FromSeconds(-1)));
    TestHelper.assertOverflow(() => Instant.MaxValue.Plus(Offset.FromSeconds(1)));
  },

  FromUnixTimeMilliseconds_Range() {
    const smallestValid = Int64.ToNumber(Int64.Divide(toUnixTimeTicksExact(Instant.MinValue), NodaConstants.TicksPerMillisecond));
    const largestValid = Int64.ToNumber(Int64.Divide(toUnixTimeTicksExact(Instant.MaxValue), NodaConstants.TicksPerMillisecond));
    TestHelper.assertValid(Instant.FromUnixTimeMilliseconds, smallestValid);
    TestHelper.assertOutOfRange(Instant.FromUnixTimeMilliseconds, smallestValid - 1);
    TestHelper.assertValid(Instant.FromUnixTimeMilliseconds, largestValid);
    TestHelper.assertOutOfRange(Instant.FromUnixTimeMilliseconds, largestValid + 1);
  },

  FromUnixTimeSeconds_Range() {
    const smallestValid = Int64.ToNumber(Int64.Divide(toUnixTimeTicksExact(Instant.MinValue), NodaConstants.TicksPerSecond));
    const largestValid = Int64.ToNumber(Int64.Divide(toUnixTimeTicksExact(Instant.MaxValue), NodaConstants.TicksPerSecond));
    TestHelper.assertValid(Instant.FromUnixTimeSeconds, smallestValid);
    TestHelper.assertOutOfRange(Instant.FromUnixTimeSeconds, smallestValid - 1);
    TestHelper.assertValid(Instant.FromUnixTimeSeconds, largestValid);
    TestHelper.assertOutOfRange(Instant.FromUnixTimeSeconds, largestValid + 1);
  },

  FromTicksSinceUnixEpoch_Range() {
    // noda-js: the tick counts are beyond 2^53, so they're passed as exact decimal strings.
    const smallestValid = toUnixTimeTicksExact(Instant.MinValue);
    const largestValid = toUnixTimeTicksExact(Instant.MaxValue);
    TestHelper.assertValid(Instant.FromUnixTimeTicks, Int64.ToString(smallestValid));
    TestHelper.assertOutOfRange(Instant.FromUnixTimeTicks, Int64.ToString(Int64.Subtract(smallestValid, 1)));
    TestHelper.assertValid(Instant.FromUnixTimeTicks, Int64.ToString(largestValid));
    TestHelper.assertOutOfRange(Instant.FromUnixTimeTicks, Int64.ToString(Int64.Add(largestValid, 1)));
  },

  PlusOffset() {
    const localInstant = NodaConstants.UnixEpoch.Plus(Offset.FromHours(1));
    assertNodaEqual(localInstant.TimeSinceLocalEpoch, Duration.FromHours(1));
  },

  SafePlus_NormalTime() {
    const localInstant = NodaConstants.UnixEpoch.SafePlus(Offset.FromHours(1));
    assertNodaEqual(localInstant.TimeSinceLocalEpoch, Duration.FromHours(1));
  },

  SafePlus_NearStartOfTime(initialOffset: number | null, offsetToAdd: number, finalOffset: number | null) {
    const start = initialOffset === null
      ? Instant.BeforeMinValue
      : Instant.Add(Instant.MinValue, Duration.FromHours(initialOffset));
    const expected = finalOffset === null
      ? LocalInstant.BeforeMinValue
      : Instant.MinValue.Plus(Offset.FromHours(finalOffset));
    const actual = start.SafePlus(Offset.FromHours(offsetToAdd));
    assertNodaEqual(actual, expected);
  },

  // A null offset indicates "AfterMaxValue". Otherwise, MaxValue.Plus(offset)
  SafePlus_NearEndOfTime(initialOffset: number | null, offsetToAdd: number, finalOffset: number | null) {
    const start = initialOffset === null
      ? Instant.AfterMaxValue
      : Instant.Add(Instant.MaxValue, Duration.FromHours(initialOffset));
    const expected = finalOffset === null
      ? LocalInstant.AfterMaxValue
      : Instant.MaxValue.Plus(Offset.FromHours(finalOffset));
    const actual = start.SafePlus(Offset.FromHours(offsetToAdd));
    assertNodaEqual(actual, expected);
  },

  // InstantTest.Format.cs

  TestToString_InvalidFormat() {
    assertThrows(InvalidPatternException, () => NodaConstants.UnixEpoch.toString("A", null));
  },

  TestToString_MinValue() {
    testToStringBase(Instant.MinValue, "-9998-01-01T00:00:00Z");
  },

  TestToString_MaxValue() {
    testToStringBase(Instant.MaxValue, "9999-12-31T23:59:59Z");
  },

  TestToString_UnixEpoch() {
    testToStringBase(NodaConstants.UnixEpoch, "1970-01-01T00:00:00Z");
  },

  TestToString_Padding() {
    testToStringBase(Instant.FromUtc(1, 1, 1, 12, 34, 56), "0001-01-01T12:34:56Z");
  },

  // InstantTest.Operators.cs

  Equality() {
    // noda-js: C# passes copies of the struct; TestHelper requires value and equalValue to be distinct objects.
    const equal = Instant.NewDaysNanoOfDay(1, 100);
    const equalCopy = Instant.NewDaysNanoOfDay(1, 100);
    const different1 = Instant.NewDaysNanoOfDay(1, 200);
    const different2 = Instant.NewDaysNanoOfDay(2, 100);

    TestHelper.testEqualsStruct(equal, equalCopy, different1);
    TestHelper.testOperatorEquality(equal, equalCopy, different1);

    TestHelper.testEqualsStruct(equal, equalCopy, different2);
    TestHelper.testOperatorEquality(equal, equalCopy, different2);
  },

  Comparison() {
    // noda-js: C# passes copies of the struct; TestHelper requires value and equalValue to be distinct objects.
    const equal = Instant.NewDaysNanoOfDay(1, 100);
    const equalCopy = Instant.NewDaysNanoOfDay(1, 100);
    const greater1 = Instant.NewDaysNanoOfDay(1, 101);
    const greater2 = Instant.NewDaysNanoOfDay(2, 0);

    TestHelper.testCompareToStruct(equal, equalCopy, greater1);
    TestHelper.testNonGenericCompareTo(equal, equalCopy, greater1);
    TestHelper.testOperatorComparisonEquality(equal, equalCopy, greater1, greater2);
  },

  // #region operator +
  PlusTicks() {
    const instant = Instant.FromUnixTimeTicks(5);
    assertNodaEqual(instant.PlusTicks(3), Instant.FromUnixTimeTicks(8));
  },

  PlusNanoseconds() {
    const instant = Instant.FromUnixTimeTicks(5);
    assertNodaEqual(instant.PlusNanoseconds(300), Instant.FromUnixTimeTicks(8));
  },

  OperatorPlusDuration_Zero_IsNeutralElement() {
    assertNodaEqual(Instant.Add(NodaConstants.UnixEpoch, Duration.Zero), NodaConstants.UnixEpoch, "UnixEpoch + Duration.Zero");
    assertNodaEqual(Instant.Add(one, Duration.Zero), one, "Instant(1) + Duration.Zero");
    assertNodaEqual(Instant.Add(NodaConstants.UnixEpoch, Duration.Epsilon), one, "UnixEpoch + Duration.Epsilon");
  },

  OperatorPlusDuration_NonZero() {
    assertNodaEqual(Instant.Add(threeMillion, Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), 3000001, "3,000,000 + 1");
    assertNodaEqual(Instant.Add(one, Duration.Negate(Duration.Epsilon)).TimeSinceEpoch.ToInt64Nanoseconds(), 0, "1 + (-1)");
    assertNodaEqual(Instant.Add(negativeFiftyMillion, Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), -49999999, "-50,000,000 + 1");
  },

  // Smoke tests for methods which simply delegate to the + operator.
  OperatorPlus_Equivalents() {
    assertNodaEqual(threeMillion.Plus(Duration.Epsilon), Instant.Add(threeMillion, Duration.Epsilon));
    assertNodaEqual(Instant.Add(threeMillion, Duration.Epsilon), Instant.Add(threeMillion, Duration.Epsilon));
  },

  // The Plus(Offset) method *would* be an operator, but can't be as LocalInstant is internal.
  OperatorPlusOffset_Zero_IsNeutralElement() {
    assertNodaEqual(NodaConstants.UnixEpoch.Plus(Offset.Zero), LocalInstant.NewDaysNanoOfDay(0, 0), "UnixEpoch + Offset.Zero");
    assertNodaEqual(one.Plus(Offset.Zero), LocalInstant.NewDaysNanoOfDay(0, 1), "Instant(1) + Offset.Zero");
    assertNodaEqual(NodaConstants.UnixEpoch.Plus(Offset.FromHours(1)), LocalInstant.NewDaysNanoOfDay(0, NodaConstants.NanosecondsPerHour), "UnixEpoch + offsetOneHour");
  },

  OperatorPlus_OutOfRange() {
    // noda-js: GetHashCode isn't ported; the addition itself throws.
    assertThrows("OverflowException", () => Instant.Add(Instant.MaxValue, Duration.Epsilon));
  },
  // #endregion

  // #region operator - (duration)
  OperatorMinusDuration() {
    assertNodaEqual(Instant.Subtract(threeMillion, Duration.Zero), threeMillion);
    assertNodaEqual(Instant.Subtract(threeMillion, Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), 2999999, "3,000,000 - 1");
    assertNodaEqual(Instant.Subtract(one, Duration.FromNanoseconds(-1)).TimeSinceEpoch.ToInt64Nanoseconds(), 2, "1 - (-1)");
    assertNodaEqual(Instant.Subtract(negativeFiftyMillion, Duration.Epsilon).TimeSinceEpoch.ToInt64Nanoseconds(), -50000001, "-50,000,000 - 1");
  },

  // Smoke tests for methods which simply delegate to the - operator.
  OperatorMinus_Duration_Equivalents() {
    assertNodaEqual(threeMillion.Minus(Duration.Epsilon), Instant.Subtract(threeMillion, Duration.Epsilon));
    assertNodaEqual(Instant.Subtract(threeMillion, Duration.Epsilon), Instant.Subtract(threeMillion, Duration.Epsilon));
  },

  OperatorMinus_OutOfRange() {
    // noda-js: GetHashCode isn't ported; the subtraction itself throws.
    assertThrows("OverflowException", () => Instant.Subtract(Instant.MinValue, Duration.Epsilon));
  },
  // #endregion

  // #region operator - (instant)
  OperatorMinusInstant_NonZero() {
    assertNodaEqual(Instant.Subtract(threeMillion, one).ToInt64Nanoseconds(), 2999999, "3,000,000 - 1");
    assertNodaEqual(Instant.Subtract(one, Instant.FromUntrustedDuration(Duration.FromNanoseconds(-1))).ToInt64Nanoseconds(), 2, "1 - (-1)");
    assertNodaEqual(Instant.Subtract(negativeFiftyMillion, one).ToInt64Nanoseconds(), -50000001, "-50,000,000 - 1");
  },

  OperatorMinusInstant_UnixEpoch_IsNeutralElement() {
    assertNodaEqual(Instant.Subtract(NodaConstants.UnixEpoch, NodaConstants.UnixEpoch).ToInt64Nanoseconds(), 0, "0 - 0");
    assertNodaEqual(Instant.Subtract(one, NodaConstants.UnixEpoch).ToInt64Nanoseconds(), 1, "1 - 0");
    assertNodaEqual(Instant.Subtract(NodaConstants.UnixEpoch, one).ToInt64Nanoseconds(), -1, "0 - 1");
  },

  // Smoke tests for methods which simply delegate to the - operator.
  OperatorMinus_Instant_Equivalents() {
    assertNodaEqual(threeMillion.Minus(one), Instant.Subtract(threeMillion, one));
    assertNodaEqual(Instant.Subtract(threeMillion, one), Instant.Subtract(threeMillion, one));
  },
  // #endregion
}, {
  skip: {
    ToDateTimeUtc: "BCL interop (DateTime) isn't ported; see Instant.toJsDate",
    ToBclTypes_DateOutOfRange: "BCL interop (DateTime, DateTimeOffset) isn't ported; see Instant.toJsDate",
    ToBclTypes_TruncateNanosTowardStartOfTime: "BCL interop (DateTime, DateTimeOffset) isn't ported; see Instant.toJsDate",
    ToDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported; see Instant.toJsDate",
    FromDateTimeOffset: "BCL interop (DateTimeOffset) isn't ported; see Instant.fromJsDate",
    FromDateTimeUtc_Invalid: "BCL interop (DateTime) isn't ported; see Instant.fromJsDate",
    FromDateTimeUtc_Valid: "BCL interop (DateTime) isn't ported; see Instant.fromJsDate",
    DefaultConstructor: "C# default(Instant) struct construction; Instant has no public constructor in noda-js",
    XmlSerialization: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
