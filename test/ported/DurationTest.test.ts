// Ported from NodaTime 3.3.0: src/NodaTime.Test/DurationTest.cs (+ .Construction.cs, .Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators map to Duration.add / subtract / multiply / divide / negate, and the internal constructor
// Duration(int days, long nanoOfDay) to Duration.newDaysNanoOfDay. C# long arguments beyond 2^53 are decimal strings.
// ToBigIntegerNanoseconds and FromNanoseconds(BigInteger) aren't ported (no BigInt in ES2015): where a test uses them
// only as an exact reference, the internal exact equivalents toDecimalNanoseconds / fromDecimalNanoseconds
// (WideInteger) are used instead.

import { expect } from "vitest";
import {
  ArgumentOutOfRangeError,
  DivideByZeroError,
  Duration,
  Int64,
  MillisecondsPerDay,
  MinutesPerDay,
  NanosecondsPerDay,
  NanosecondsPerHour,
  NanosecondsPerMillisecond,
  NanosecondsPerMinute,
  NanosecondsPerSecond,
  NanosecondsPerTick,
  OverflowError,
  SecondsPerDay,
  TicksPerHour,
  WideInteger,
  HoursPerDay,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/DurationTest.generated.ts";

/** C# `new Duration(days, nanoOfDay)` (internal constructor, validating days). */
function newDuration(days: number, nanoOfDay: number): Duration {
  return Duration.NewDaysNanoOfDay(days, nanoOfDay);
}

/** NUnit's Assert.AreEqual(double expected, double actual, double delta). */
function assertAreEqualWithin(expected: number, actual: number, delta: number): void {
  expect(Math.abs(expected - actual), `expected ${expected} +/- ${delta} but was ${actual}`).toBeLessThanOrEqual(delta);
}

/** The exact value of a C# long argument (number or decimal string). */
function wide(value: number | string): WideInteger {
  return WideInteger.FromInt64(Int64.FromArgument(value, "value"));
}

// #region DurationTest.Construction.cs

// Test cases for factory methods. In general, we want to check the limits, very small, very large
// and medium values, with a mixture of positive and negative, "on and off" day boundaries.

const DayCases: readonly number[] = [
  Duration.MinDays, -3000 * 365, -100, -1, 0, 1, 100, 3000 * 365, Duration.MaxDays,
];

const HourCases: readonly number[] = [
  Duration.MinDays * HoursPerDay, -3000 * 365 * HoursPerDay, -100, -48, -1, 0,
  1, 48, 100, 3000 * 365 * HoursPerDay, ((Duration.MaxDays + 1) * HoursPerDay) - 1,
];

const MinuteCases = generateCases(MinutesPerDay);
const SecondCases = generateCases(SecondsPerDay);
const MillisecondCases = generateCases(MillisecondsPerDay);
// noda-js: TickCases (whose values go beyond 2^53) are only used as scenario data, which the harness supplies.

// noda-js: all of these values are safe integers for minutes, seconds and milliseconds.
function generateCases(unitsPerDay: number): number[] {
  return [
    Duration.MinDays * unitsPerDay,
    -3000 * 365 * unitsPerDay - 1,
    -3000 * 365 * unitsPerDay,
    Math.trunc(-5 * unitsPerDay / 2),
    -2 * unitsPerDay
    - 1,
    0,
    1,
    2 * unitsPerDay,
    Math.trunc(5 * unitsPerDay / 2),
    3000 * 365 * unitsPerDay,
    3000 * 365 * unitsPerDay + 1,
    ((Duration.MaxDays + 1) * unitsPerDay) - 1,
  ];
}

/** TestFactoryMethod: ToBigIntegerNanoseconds is replaced by the exact toDecimalNanoseconds. */
function testFactoryMethod(method: (value: number) => Duration, value: number, nanosecondsPerUnit: number): void {
  const duration = method(value);
  const expectedNanoseconds = WideInteger.FromNumber(value).Multiply(WideInteger.FromNumber(nanosecondsPerUnit));
  expect(duration.ToDecimalNanoseconds().toString()).toBe(expectedNanoseconds.toString());
}

/** C# BitConverter.Int64BitsToDouble(BitConverter.DoubleToInt64Bits(start) + change), for a small change. */
function nextDouble(start: number, change: number): number {
  const buffer = new ArrayBuffer(8);
  const doubles = new Float64Array(buffer);
  const words = new Uint32Array(buffer); // little-endian: [low, high]
  doubles[0] = start;
  const low = words[0]! + change;
  words[0] = low >>> 0;
  words[1] = words[1]! + Math.floor(low / 2 ** 32);
  return doubles[0]!;
}

const constructionBodies = {
  Zero() {
    const test = Duration.Zero;
    assertNodaEqual(test.BclCompatibleTicks, 0);
    assertNodaEqual(test.NanosecondOfFloorDay, 0);
    assertNodaEqual(test.FloorDays, 0);
  },

  FromDays_Int32(days: number) {
    testFactoryMethod(Duration.FromDays, days, NanosecondsPerDay);
  },

  FromHours_Int32(hours: number) {
    testFactoryMethod(Duration.FromHours, hours, NanosecondsPerHour);
  },

  FromMinutes_Int64(minutes: number) {
    testFactoryMethod(Duration.FromMinutes, minutes, NanosecondsPerMinute);
  },

  FromSeconds_Int64(seconds: number) {
    testFactoryMethod(Duration.FromSeconds, seconds, NanosecondsPerSecond);
  },

  FromMilliseconds_Int64(milliseconds: number) {
    testFactoryMethod(Duration.FromMilliseconds, milliseconds, NanosecondsPerMillisecond);
  },

  FromTicks(ticks: number | string) {
    const nanoseconds = Duration.FromTicks(ticks);
    expect(nanoseconds.ToDecimalNanoseconds().toString()).toBe(wide(ticks).Multiply(WideInteger.FromNumber(NanosecondsPerTick)).toString());

    // Just another sanity check, although Ticks is covered in more detail later.
    // noda-js: bclCompatibleTicks is a number (the nearest double to the C# long).
    assertNodaEqual(nanoseconds.BclCompatibleTicks, Number(ticks));
  },

  FromDays_Double(days: number, expectedDays: number, expectedNanoOfDay: number) {
    const actual = Duration.FromDays(days);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  FromHours_Double(hours: number, expectedDays: number, expectedNanoOfDay: number) {
    const actual = Duration.FromHours(hours);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  FromMinutes_Double(minutes: number, expectedDays: number, expectedNanoOfDay: number) {
    const actual = Duration.FromMinutes(minutes);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  FromSeconds_Double(seconds: number, expectedDays: number, expectedNanoOfDay: number) {
    const actual = Duration.FromSeconds(seconds);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  FromMilliseconds_Double(milliseconds: number, expectedDays: number, expectedNanoOfDay: number) {
    const actual = Duration.FromMilliseconds(milliseconds);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  FromNanoseconds_Int64() {
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay - 1), Duration.OneDay.Minus(Duration.Epsilon));
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay), Duration.OneDay);
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay + 1), Duration.OneDay.Plus(Duration.Epsilon));

    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay - 1), Duration.Negate(Duration.OneDay).Minus(Duration.Epsilon));
    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay), Duration.Negate(Duration.OneDay));
    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay + 1), Duration.Negate(Duration.OneDay).Plus(Duration.Epsilon));
  },

  // noda-js: Duration.MinDecimalNanoseconds / MaxDecimalNanoseconds and FromNanoseconds(decimal) are internal; their
  // equivalents are the exact values below and Duration.fromDecimalNanoseconds.
  FromNanosecondsDecimal_Limits() {
    // MinDays * NanosecondsPerDay is exactly representable as a double.
    const minDecimalNanoseconds = WideInteger.FromNumber(Duration.MinDays * NanosecondsPerDay);
    const maxDecimalNanoseconds = minDecimalNanoseconds.Negate().Subtract(WideInteger.FromNumber(1));
    const one = WideInteger.FromNumber(1);
    assertNodaEqual(Duration.FromDecimalNanoseconds(minDecimalNanoseconds), Duration.MinValue);
    assertNodaEqual(Duration.FromDecimalNanoseconds(maxDecimalNanoseconds), Duration.MaxValue);
    assertThrows(ArgumentOutOfRangeError, () => Duration.FromDecimalNanoseconds(minDecimalNanoseconds.Subtract(one)));
    assertThrows(ArgumentOutOfRangeError, () => Duration.FromDecimalNanoseconds(maxDecimalNanoseconds.Add(one)));
  },

  // noda-js: an integral double can't be told apart from a long at runtime, so the integral values here go to the
  // FromNanoseconds(long) overload (with the same results); the large values below do use FromNanoseconds(double).
  FromNanoseconds_Double() {
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay - 1), Duration.OneDay.Minus(Duration.Epsilon));
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay + 0), Duration.OneDay);
    assertNodaEqual(Duration.FromNanoseconds(NanosecondsPerDay + 1), Duration.OneDay.Plus(Duration.Epsilon));

    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay - 1), Duration.Negate(Duration.OneDay).Minus(Duration.Epsilon));
    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay + 0), Duration.Negate(Duration.OneDay));
    assertNodaEqual(Duration.FromNanoseconds(-NanosecondsPerDay + 1), Duration.Negate(Duration.OneDay).Plus(Duration.Epsilon));

    // Checks for values outside the range of long...
    // Find a value which is pretty big, but will definitely still convert back to a positive long.
    // (long.MaxValue / 16) * 15 in long arithmetic is 8646911284551352305; converted to the nearest double.
    const largeDoubleValue = Number("8646911284551352305");
    const largeInt64Value = Int64.ToString(Int64.FromArgument(largeDoubleValue, "largeDoubleValue")); // This won't be exactly long.MaxValue
    assertNodaEqual(Duration.FromNanoseconds(largeDoubleValue * 8), Duration.Multiply(Duration.FromNanoseconds(largeInt64Value), 8));
  },

  FactoryMethods_OutOfRange() {
    // Each set of cases starts with the minimum and ends with the maximum, so we can test just beyond the limits easily.
    assertLimits(Duration.FromDays, DayCases);
    assertLimits(Duration.FromHours, HourCases);
    assertLimits(Duration.FromMinutes, MinuteCases);
    assertLimits(Duration.FromSeconds, SecondCases);
    assertLimits(Duration.FromMilliseconds, MillisecondCases);
    // FromTicks(long) never throws.

    const bigBadDoubles = [Number.NEGATIVE_INFINITY, -Number.MAX_VALUE, Number.MAX_VALUE, Number.POSITIVE_INFINITY, Number.NaN];
    assertOutOfRange(Duration.FromDays, ...bigBadDoubles);
    assertOutOfRange(Duration.FromHours, ...bigBadDoubles);
    assertOutOfRange(Duration.FromMinutes, ...bigBadDoubles);
    assertOutOfRange(Duration.FromSeconds, ...bigBadDoubles);
    assertOutOfRange(Duration.FromMilliseconds, ...bigBadDoubles);
    assertOutOfRange(Duration.FromTicks, ...bigBadDoubles);
    assertOutOfRange(Duration.FromNanoseconds, ...bigBadDoubles);
    // (double) Duration.MinNanoseconds is exact; (double) Duration.MaxNanoseconds rounds to (MaxDays + 1) days.
    assertOutOfRange(Duration.FromNanoseconds,
      // You might have expected -1L here, but the layout of double means
      // this really is the next value *lower* than MinNanoseconds.
      nextDouble(Duration.MinDays * NanosecondsPerDay, 1),
      nextDouble((Duration.MaxDays + 1) * NanosecondsPerDay, 1));

    // No such concept as BigInteger.Min/MaxValue, so use the values we know to be just outside valid bounds.
    // noda-js: FromNanoseconds(BigInteger) isn't ported; fromDecimalNanoseconds is its exact internal equivalent.
    const minNanoseconds = WideInteger.FromNumber(Duration.MinDays * NanosecondsPerDay);
    const maxNanoseconds = minNanoseconds.Negate().Subtract(WideInteger.FromNumber(1));
    assertOutOfRange(Duration.FromDecimalNanoseconds,
      minNanoseconds.Subtract(WideInteger.FromNumber(1)), maxNanoseconds.Add(WideInteger.FromNumber(1)));

    // Not ported: the FromNanoseconds(Int128) checks (no Int128 in noda-js).

    function assertLimits(factoryMethod: (value: number) => Duration, allCases: readonly number[]): void {
      assertOutOfRange(factoryMethod, allCases[0]! - 1, allCases[allCases.length - 1]! + 1);
    }

    function assertOutOfRange<T>(factoryMethod: (value: T) => Duration, ...values: T[]): void {
      for (const value of values) {
        assertThrows(ArgumentOutOfRangeError, () => factoryMethod(value));
      }
    }
  },
};

// #endregion

// #region DurationTest.cs

const durationTestBodies = {
  DefaultConstructor() {
    // noda-js: there's no public constructor; the C# default value is Duration.zero.
    const actual = Duration.NewDaysNanoOfDay(0, 0);
    assertNodaEqual(actual, Duration.Zero);
  },

  // Tests copied from Nanoseconds in its brief existence... there may well be some overlap between
  // this and older Duration tests.

  Int64Conversions(int64Nanos: number | string) {
    const nanoseconds = Duration.FromNanoseconds(int64Nanos);
    expect(Int64.ToString(nanoseconds.ToInt64NanosecondsExact())).toBe(String(int64Nanos));
    // The public accessor returns the nearest number.
    assertNodaEqual(nanoseconds.ToInt64Nanoseconds(), Number(int64Nanos));
  },

  ConstituentParts_Positive() {
    const nanos = Duration.FromNanoseconds(NanosecondsPerDay * 5 + 100);
    assertNodaEqual(nanos.FloorDays, 5);
    assertNodaEqual(nanos.NanosecondOfFloorDay, 100);
  },

  ConstituentParts_Negative() {
    const nanos = Duration.FromNanoseconds(NanosecondsPerDay * -5 + 100);
    assertNodaEqual(nanos.FloorDays, -5);
    assertNodaEqual(nanos.NanosecondOfFloorDay, 100);
  },

  ConstituentParts_Large() {
    // And outside the normal range of long...
    // noda-js: FromNanoseconds(BigInteger) isn't ported; fromDecimalNanoseconds is its exact internal equivalent.
    const nanos = Duration.FromDecimalNanoseconds(
      WideInteger.FromNumber(NanosecondsPerDay).Multiply(WideInteger.FromNumber(365000)).Add(WideInteger.FromNumber(500)));
    assertNodaEqual(nanos.FloorDays, 365000);
    assertNodaEqual(nanos.NanosecondOfFloorDay, 500);
  },

  Addition_Subtraction(leftDays: number, leftNanos: number, rightDays: number, rightNanos: number, resultDays: number, resultNanos: number) {
    const left = newDuration(leftDays, leftNanos);
    const right = newDuration(rightDays, rightNanos);
    const result = newDuration(resultDays, resultNanos);

    assertNodaEqual(Duration.Add(left, right), result);
    assertNodaEqual(left.Plus(right), result);
    assertNodaEqual(Duration.Add(left, right), result);

    assertNodaEqual(Duration.Subtract(result, right), left);
    assertNodaEqual(result.Minus(right), left);
    assertNodaEqual(Duration.Subtract(result, right), left);
  },

  Equality() {
    const equal1 = newDuration(1, NanosecondsPerHour);
    const equal2 = Duration.FromTicks(TicksPerHour * 25);
    const different1 = newDuration(1, 200);
    const different2 = newDuration(2, TicksPerHour);

    TestHelper.testEqualsStruct(equal1, equal2, different1);
    TestHelper.testOperatorEquality(equal1, equal2, different1);

    TestHelper.testEqualsStruct(equal1, equal2, different2);
    TestHelper.testOperatorEquality(equal1, equal2, different2);
  },

  Comparison() {
    const equal1 = newDuration(1, NanosecondsPerHour);
    const equal2 = Duration.FromTicks(TicksPerHour * 25);
    const greater1 = newDuration(1, NanosecondsPerHour + 1);
    const greater2 = newDuration(2, 0);

    TestHelper.testCompareToStruct(equal1, equal2, greater1);
    TestHelper.testNonGenericCompareTo(equal1, equal2, greater1);
    TestHelper.testOperatorComparisonEquality(equal1, equal2, greater1, greater2);
  },

  Multiplication(startDays: number, startNanoOfDay: number, scalar: number | string, expectedDays: number, expectedNanoOfDay: number) {
    const start = newDuration(startDays, startNanoOfDay);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(Duration.Multiply(start, scalar), expected);
  },

  UnaryNegation(startDays: number, startNanoOfDay: number, expectedDays: number, expectedNanoOfDay: number) {
    const start = newDuration(startDays, startNanoOfDay);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(Duration.Negate(start), expected);
    // Test it the other way round as well...
    assertNodaEqual(Duration.Negate(expected), start);
  },

  Division(startDays: number, startNanoOfDay: number, divisor: number | string, expectedDays: number, expectedNanoOfDay: number) {
    const start = newDuration(startDays, startNanoOfDay);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(Duration.Divide(start, divisor), expected);
  },

  BclCompatibleTick_Zero() {
    assertNodaEqual(Duration.FromTicks(0).BclCompatibleTicks, 0);
    assertNodaEqual(Duration.FromNanoseconds(99).BclCompatibleTicks, 0);
    assertNodaEqual(Duration.FromNanoseconds(-99).BclCompatibleTicks, 0);
  },

  // noda-js: bclCompatibleTicks is a number (the nearest double to the C# long), so for ticks beyond 2^53 the +/- 1
  // checks compare nearest doubles.
  BclCompatibleTick_Positive(ticks: number | string) {
    expect(Int64.Compare(Int64.FromArgument(ticks, "ticks"), 0) > 0).toBe(true);
    const start = Duration.FromTicks(ticks);
    assertNodaEqual(start.BclCompatibleTicks, Number(ticks));

    // We truncate towards zero... so subtracting 1 nanosecond should
    // reduce the number of ticks, and adding 99 nanoseconds should not change it
    assertNodaEqual(start.MinusSmallNanoseconds(1).BclCompatibleTicks, Int64.ToNumber(Int64.Subtract(Int64.FromArgument(ticks, "ticks"), 1)));
    assertNodaEqual(start.PlusSmallNanoseconds(99).BclCompatibleTicks, Number(ticks));
  },

  BclCompatibleTicks_Negative(ticks: number | string) {
    expect(Int64.Compare(Int64.FromArgument(ticks, "ticks"), 0) < 0).toBe(true);
    const start = Duration.FromTicks(ticks);
    assertNodaEqual(start.BclCompatibleTicks, Number(ticks));

    // We truncate towards zero... so subtracting 99 nanoseconds should
    // have no effect, and adding 1 should increase the number of ticks
    assertNodaEqual(start.MinusSmallNanoseconds(99).BclCompatibleTicks, Number(ticks));
    assertNodaEqual(start.PlusSmallNanoseconds(1).BclCompatibleTicks, Int64.ToNumber(Int64.Add(Int64.FromArgument(ticks, "ticks"), 1)));
  },

  BclCompatibleTicks_MinValue() {
    assertThrows(OverflowError, () => Duration.MinValue.BclCompatibleTicks.toString());
  },

  Validation() {
    TestHelper.assertValid(Duration.FromDays, (1 << 24) - 1);
    TestHelper.assertOutOfRange(Duration.FromDays, 1 << 24);
    TestHelper.assertValid(Duration.FromDays, -(1 << 24));
    TestHelper.assertOutOfRange(Duration.FromDays, -(1 << 24) - 1);
  },

  BclCompatibleTicks_Overflow() {
    const maxTicks = Duration.FromTicks("9223372036854775807").Plus(Duration.FromTicks(1));
    assertThrows(OverflowError, () => maxTicks.BclCompatibleTicks.toString());
  },

  PositiveComponents() {
    // Worked out with a calculator :)
    const duration = Duration.FromNanoseconds(1234567890123456);
    assertNodaEqual(duration.Days, 14);
    assertNodaEqual(duration.NanosecondOfDay, 24967890123456);
    assertNodaEqual(duration.Hours, 6);
    assertNodaEqual(duration.Minutes, 56);
    assertNodaEqual(duration.Seconds, 7);
    assertNodaEqual(duration.Milliseconds, 890);
    assertNodaEqual(duration.SubsecondTicks, 8901234);
    assertNodaEqual(duration.SubsecondNanoseconds, 890123456);
  },

  NegativeComponents() {
    // Worked out with a calculator :)
    const duration = Duration.FromNanoseconds(-1234567890123456);
    assertNodaEqual(duration.Days, -14);
    assertNodaEqual(duration.NanosecondOfDay, -24967890123456);
    assertNodaEqual(duration.Hours, -6);
    assertNodaEqual(duration.Minutes, -56);
    assertNodaEqual(duration.Seconds, -7);
    assertNodaEqual(duration.Milliseconds, -890);
    assertNodaEqual(duration.SubsecondTicks, -8901234);
    assertNodaEqual(duration.SubsecondNanoseconds, -890123456);
  },

  PositiveTotals() {
    const duration = Duration.FromDays(4).Plus(Duration.FromHours(3)).Plus(Duration.FromMinutes(2)).Plus(Duration.FromSeconds(1))
      .Plus(Duration.FromNanoseconds(123456789));
    assertAreEqualWithin(4.1264, duration.TotalDays, 0.0001);
    assertAreEqualWithin(99.0336, duration.TotalHours, 0.0001);
    assertAreEqualWithin(5942.0187, duration.TotalMinutes, 0.0001);
    assertAreEqualWithin(356521.123456789, duration.TotalSeconds, 0.000000001);
    assertAreEqualWithin(356521123.456789, duration.TotalMilliseconds, 0.000001);
    assertAreEqualWithin(3565211234567.89, duration.TotalTicks, 0.01);
    assertAreEqualWithin(356521123456789, duration.TotalNanoseconds, 1);
  },

  NegativeTotals() {
    const duration = Duration.FromDays(-4).Plus(Duration.FromHours(-3)).Plus(Duration.FromMinutes(-2)).Plus(Duration.FromSeconds(-1))
      .Plus(Duration.FromNanoseconds(-123456789));
    assertAreEqualWithin(-4.1264, duration.TotalDays, 0.0001);
    assertAreEqualWithin(-99.0336, duration.TotalHours, 0.0001);
    assertAreEqualWithin(-5942.0187, duration.TotalMinutes, 0.0001);
    assertAreEqualWithin(-356521.123456789, duration.TotalSeconds, 0.000000001);
    assertAreEqualWithin(-356521123.456789, duration.TotalMilliseconds, 0.000001);
    assertAreEqualWithin(-356521123456789, duration.TotalNanoseconds, 1);
  },

  MaxMinRelationship() {
    // Max and Min work like they do for other signed types - basically the max value is one less than the absolute
    // of the min value.
    assertNodaEqual(Duration.Negate(Duration.MaxValue).Minus(Duration.Epsilon), Duration.MinValue);
  },

  Max() {
    const x = Duration.FromNanoseconds(100);
    const y = Duration.FromNanoseconds(200);
    assertNodaEqual(Duration.Max(x, y), y);
    assertNodaEqual(Duration.Max(y, x), y);
    assertNodaEqual(Duration.Max(x, Duration.MinValue), x);
    assertNodaEqual(Duration.Max(Duration.MinValue, x), x);
    assertNodaEqual(Duration.Max(Duration.MaxValue, x), Duration.MaxValue);
    assertNodaEqual(Duration.Max(x, Duration.MaxValue), Duration.MaxValue);
  },

  Min() {
    const x = Duration.FromNanoseconds(100);
    const y = Duration.FromNanoseconds(200);
    assertNodaEqual(Duration.Min(x, y), x);
    assertNodaEqual(Duration.Min(y, x), x);
    assertNodaEqual(Duration.Min(x, Duration.MinValue), Duration.MinValue);
    assertNodaEqual(Duration.Min(Duration.MinValue, x), Duration.MinValue);
    assertNodaEqual(Duration.Min(Duration.MaxValue, x), x);
    assertNodaEqual(Duration.Min(x, Duration.MaxValue), x);
  },
};

// #endregion

// #region DurationTest.Operators.cs

// noda-js: fields of the C# fixture; created lazily, per test.
const threeMillion = (): Duration => Duration.FromNanoseconds(3000000);
const negativeFiftyMillion = (): Duration => Duration.FromNanoseconds(-50000000);

const operatorBodies = {
  // #region operator +
  OperatorPlus_Zero_IsNeutralElement() {
    assertNodaEqual(Duration.Add(Duration.Zero, Duration.Zero).ToInt64Nanoseconds(), 0, "0 + 0");
    assertNodaEqual(Duration.Add(Duration.Epsilon, Duration.Zero).ToInt64Nanoseconds(), 1, "1 + 0");
    assertNodaEqual(Duration.Add(Duration.Zero, Duration.Epsilon).ToInt64Nanoseconds(), 1, "0 + 1");
  },

  OperatorPlus_NonZero() {
    assertNodaEqual(Duration.Add(threeMillion(), Duration.Epsilon).ToInt64Nanoseconds(), 3000001, "3,000,000 + 1");
    assertNodaEqual(Duration.Add(Duration.Epsilon, Duration.FromNanoseconds(-1)).ToInt64Nanoseconds(), 0, "1 + (-1)");
    assertNodaEqual(Duration.Add(negativeFiftyMillion(), Duration.Epsilon).ToInt64Nanoseconds(), -49999999, "-50,000,000 + 1");
  },

  OperatorPlus_MethodEquivalents() {
    const x = Duration.FromNanoseconds(100);
    const y = Duration.FromNanoseconds(200);
    assertNodaEqual(Duration.Add(x, y), Duration.Add(x, y));
    assertNodaEqual(x.Plus(y), Duration.Add(x, y));
  },
  // #endregion

  // #region operator -
  OperatorMinus_Zero_IsNeutralElement() {
    assertNodaEqual(Duration.Subtract(Duration.Zero, Duration.Zero).ToInt64Nanoseconds(), 0, "0 - 0");
    assertNodaEqual(Duration.Subtract(Duration.Epsilon, Duration.Zero).ToInt64Nanoseconds(), 1, "1 - 0");
    assertNodaEqual(Duration.Subtract(Duration.Zero, Duration.Epsilon).ToInt64Nanoseconds(), -1, "0 - 1");
  },

  OperatorMinus_NonZero() {
    const negativeEpsilon = Duration.FromNanoseconds(-1);
    assertNodaEqual(Duration.Subtract(threeMillion(), Duration.Epsilon).ToInt64Nanoseconds(), 2999999, "3,000,000 - 1");
    assertNodaEqual(Duration.Subtract(Duration.Epsilon, negativeEpsilon).ToInt64Nanoseconds(), 2, "1 - (-1)");
    assertNodaEqual(Duration.Subtract(negativeFiftyMillion(), Duration.Epsilon).ToInt64Nanoseconds(), -50000001, "-50,000,000 - 1");
  },

  OperatorMinus_MethodEquivalents() {
    const x = Duration.FromNanoseconds(100);
    const y = Duration.FromNanoseconds(200);
    assertNodaEqual(Duration.Subtract(x, y), Duration.Subtract(x, y));
    assertNodaEqual(x.Minus(y), Duration.Subtract(x, y));
  },
  // #endregion

  // #region operator /
  OperatorDivision_Int64(days: number, nanoOfDay: number, divisor: number | string, expectedDays: number, expectedNanoOfDay: number) {
    const duration = newDuration(days, nanoOfDay);
    const actual = Duration.Divide(duration, divisor);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  // noda-js: an integral divisor (2.0) can't be told apart from a long at runtime, so it uses the long overload
  // (with the same result).
  OperatorDivision_Double(days: number, nanoOfDay: number, divisor: number, expectedDays: number, expectedNanoOfDay: number) {
    const duration = newDuration(days, nanoOfDay);
    const actual = Duration.Divide(duration, divisor);
    const expected = newDuration(expectedDays, expectedNanoOfDay);
    assertNodaEqual(actual, expected);
  },

  OperatorDivision_Duration(dividendDays: number, dividendNanoOfDay: number, divisorDays: number, divisorNanoOfDay: number, expected: number) {
    const dividend = newDuration(dividendDays, dividendNanoOfDay);
    const divisor = newDuration(divisorDays, divisorNanoOfDay);
    const actual = Duration.Divide(dividend, divisor);
    assertNodaEqual(actual, expected);
  },

  // noda-js: 0d and 0 are the same number, so both use the long overload.
  OperatorDivision_ByZero_Throws() {
    assertThrows(DivideByZeroError, () => Duration.Divide(threeMillion(), 0.0).toString());
    assertThrows(DivideByZeroError, () => Duration.Divide(threeMillion(), 0).toString());
    assertThrows(DivideByZeroError, () => Duration.Divide(threeMillion(), Duration.Zero).toString());
  },

  OperatorDivision_MethodEquivalent() {
    assertNodaEqual(Duration.Divide(threeMillion(), 2000000), Duration.Divide(threeMillion(), 2000000));
    assertNodaEqual(Duration.Divide(threeMillion(), 2000000.0), Duration.Divide(threeMillion(), 2000000.0));
    assertNodaEqual(Duration.Divide(negativeFiftyMillion(), threeMillion()), Duration.Divide(negativeFiftyMillion(), threeMillion()));
  },
  // #endregion

  // #region operator *
  OperatorMultiplication_Int64(days: number, nanos: number, rightOperand: number) {
    // Rather than expressing an expected answer, just do a "long-hand" version
    // using ToBigIntegerNanoseconds and FromNanoseconds, trusting those two operations
    // to be correct.
    // noda-js: with their exact internal equivalents toDecimalNanoseconds and fromDecimalNanoseconds.
    const duration = Duration.FromDays(days).Plus(Duration.FromNanoseconds(nanos));
    const actual = Duration.Multiply(duration, rightOperand);

    const expected = Duration.FromDecimalNanoseconds(duration.ToDecimalNanoseconds().Multiply(WideInteger.FromNumber(rightOperand)));
    assertNodaEqual(actual, expected);
  },

  // noda-js: an integral rightOperand (2.0) uses the long overload (with the same result).
  OperatorMultiplication_Double(days: number, nanos: number, rightOperand: number, expectedDays: number, expectedNanos: number) {
    const start = newDuration(days, nanos);
    let actual = Duration.Multiply(start, rightOperand);
    const expected = newDuration(expectedDays, expectedNanos);
    assertNodaEqual(actual, expected);
    actual = Duration.Multiply(rightOperand, start);
    assertNodaEqual(actual, expected);
  },

  Commutation() {
    assertNodaEqual(Duration.Multiply(5, threeMillion()), Duration.Multiply(threeMillion(), 5));
    assertNodaEqual(Duration.Multiply(5.5, threeMillion()), Duration.Multiply(threeMillion(), 5.5));
  },

  OperatorMultiplication_MethodEquivalents() {
    assertNodaEqual(Duration.Multiply(Duration.FromNanoseconds(-50000), 1000), Duration.Multiply(Duration.FromNanoseconds(-50000), 1000));
    assertNodaEqual(Duration.Multiply(1000, Duration.FromNanoseconds(-50000)), Duration.Multiply(1000, Duration.FromNanoseconds(-50000)));
    assertNodaEqual(Duration.Multiply(Duration.FromNanoseconds(-50000), 1000.0), Duration.Multiply(Duration.FromNanoseconds(-50000), 1000.0));
    assertNodaEqual(Duration.Multiply(1000.0, Duration.FromNanoseconds(-50000)), Duration.Multiply(1000.0, Duration.FromNanoseconds(-50000)));
  },
  // #endregion

  UnaryMinusAndNegate() {
    const start = Duration.FromNanoseconds(5000);
    const expected = Duration.FromNanoseconds(-5000);
    assertNodaEqual(Duration.Negate(start), expected);
    assertNodaEqual(Duration.Negate(start), expected);
  },
};

// #endregion

port(fixture, { ...constructionBodies, ...durationTestBodies, ...operatorBodies }, {
  skip: {
    FromAndToTimeSpan: "Not ported: FromTimeSpan / ToTimeSpan (BCL interop)",
    FromNanoseconds_BigInteger: "Not ported: FromNanoseconds(BigInteger) (no BigInt in ES2015)",
    FromNanoseconds_Int128: "Not ported: FromNanoseconds(Int128) (no Int128 in noda-js)",
    XmlSerialization: "Not ported: XML serialization",
    XmlSerialization_Invalid: "Not ported: XML serialization",
    BigIntegerConversions: "Not ported: FromNanoseconds(BigInteger) / ToBigIntegerNanoseconds (no BigInt in ES2015)",
    Int128Conversions: "Not ported: FromNanoseconds(Int128) / ToInt128Nanoseconds (no Int128 in noda-js)",
    UnaryAddition: "Not ported: unary + (dropped in noda-js; see docs/porting-conventions.md)",
  },
});
