// Ported from NodaTime 3.3.7: src/NodaTime.Test/OffsetTest.cs (+ .Construction.cs, .Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# operators map to Offset.add / subtract / negate; unary plus is dropped, so UnaryPlusOperator checks
// the values unchanged.

import { NodaConstants, Offset } from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { TestObjects } from "../helpers/TestObjects.ts";
import { fixture } from "../scenarios/OffsetTest.generated.ts";

const ThreeHours = TestObjects.createPositiveOffset(3, 0, 0);
const NegativeThreeHours = TestObjects.createNegativeOffset(3, 0, 0);
const NegativeTwelveHours = TestObjects.createNegativeOffset(12, 0, 0);

port(fixture, {
  // #region OffsetTest.Construction.cs
  Zero() {
    const test = Offset.Zero;
    assertNodaEqual(test.Milliseconds, 0);
  },

  FromSeconds_Valid() {
    const test = Offset.FromSeconds(12345);
    assertNodaEqual(test.Seconds, 12345);
  },

  FromSeconds_Invalid() {
    const seconds = 18 * NodaConstants.SecondsPerHour + 1;
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromSeconds(seconds));
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromSeconds(-seconds));
  },

  FromMilliseconds_Valid() {
    const value = Offset.FromMilliseconds(-15 * NodaConstants.MillisecondsPerMinute);
    assertNodaEqual(value.Seconds, -15 * NodaConstants.SecondsPerMinute);
    assertNodaEqual(value.Milliseconds, -15 * NodaConstants.MillisecondsPerMinute);
  },

  FromMilliseconds_Invalid() {
    const millis = 18 * NodaConstants.MillisecondsPerHour + 1;
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromMilliseconds(millis));
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromMilliseconds(-millis));
  },

  FromTicks_Valid() {
    const value = Offset.FromTicks(-15 * NodaConstants.TicksPerMinute);
    assertNodaEqual(value.Seconds, -15 * NodaConstants.SecondsPerMinute);
    assertNodaEqual(value.Ticks, -15 * NodaConstants.TicksPerMinute);
  },

  FromTicks_Invalid() {
    const ticks = 18 * NodaConstants.TicksPerHour + 1;
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromTicks(ticks));
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromTicks(-ticks));
  },

  FromNanoseconds_Valid() {
    const value = Offset.FromNanoseconds(-15 * NodaConstants.NanosecondsPerMinute);
    assertNodaEqual(value.Seconds, -15 * NodaConstants.SecondsPerMinute);
    assertNodaEqual(value.Nanoseconds, -15 * NodaConstants.NanosecondsPerMinute);
  },

  FromNanoseconds_Invalid() {
    const nanos = 18 * NodaConstants.NanosecondsPerHour + 1;
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromNanoseconds(nanos));
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromNanoseconds(-nanos));
  },

  FromHours_Valid() {
    const value = Offset.FromHours(-15);
    assertNodaEqual(value.Seconds, -15 * NodaConstants.SecondsPerHour);
  },

  FromHours_Invalid() {
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromHours(19));
    assertThrows("ArgumentOutOfRangeException", () => Offset.FromHours(-19));
  },

  FromHoursAndMinutes_Valid() {
    const value = Offset.FromHoursAndMinutes(5, 30);
    assertNodaEqual(value.Seconds, 5 * NodaConstants.SecondsPerHour + 30 * NodaConstants.SecondsPerMinute);
  },
  // #endregion

  // #region OffsetTest.Operators.cs
  IEquatableIComparable_Tests() {
    const value = Offset.FromSeconds(12345);
    const equalValue = Offset.FromSeconds(12345);
    const greaterValue = Offset.FromSeconds(54321);

    TestHelper.testEqualsStruct(value, equalValue, greaterValue);
    TestHelper.testCompareToStruct(value, equalValue, greaterValue);
    TestHelper.testNonGenericCompareTo(value, equalValue, greaterValue);
    TestHelper.testOperatorComparisonEquality(value, equalValue, greaterValue);
  },

  UnaryPlusOperator() {
    // noda-js: unary + is dropped (porting conventions); the operand is unchanged.
    assertNodaEqual(Offset.Zero, Offset.Zero, "+ 0");
    assertNodaEqual(Offset.FromSeconds(1), Offset.FromSeconds(1), "+ 1");
    assertNodaEqual(Offset.FromSeconds(-7), Offset.FromSeconds(-7), "+ (-7)");
  },

  NegateOperator() {
    assertNodaEqual(Offset.Negate(Offset.Zero), Offset.Zero, "-0");
    assertNodaEqual(Offset.Negate(Offset.FromSeconds(1)), Offset.FromSeconds(-1), "-1");
    assertNodaEqual(Offset.Negate(Offset.FromSeconds(-7)), Offset.FromSeconds(7), "- (-7)");
  },

  NegateMethod() {
    assertNodaEqual(Offset.Negate(Offset.Zero), Offset.Zero, "-0");
    assertNodaEqual(Offset.Negate(Offset.FromSeconds(1)), Offset.FromSeconds(-1), "-1");
    assertNodaEqual(Offset.Negate(Offset.FromSeconds(-7)), Offset.FromSeconds(7), "- (-7)");
  },

  // #region operator +
  OperatorPlus_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Add(Offset.Zero, Offset.Zero).Seconds, 0, "0 + 0");
    assertNodaEqual(Offset.Add(ThreeHours, Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours + 0");
    assertNodaEqual(Offset.Add(Offset.Zero, ThreeHours), TestObjects.createPositiveOffset(3, 0, 0), "0 + ThreeHours");
  },

  OperatorPlus_NonZero() {
    assertNodaEqual(Offset.Add(ThreeHours, ThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours + ThreeHours");
    assertNodaEqual(Offset.Add(ThreeHours, NegativeThreeHours), Offset.Zero, "ThreeHours + (-ThreeHours)");
    assertNodaEqual(Offset.Add(NegativeTwelveHours, ThreeHours), TestObjects.createNegativeOffset(9, 0, 0), "-TwelveHours + ThreeHours");
  },

  // Static method equivalents
  MethodAdd_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Add(Offset.Zero, Offset.Zero).Milliseconds, 0, "0 + 0");
    assertNodaEqual(Offset.Add(ThreeHours, Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours + 0");
    assertNodaEqual(Offset.Add(Offset.Zero, ThreeHours), TestObjects.createPositiveOffset(3, 0, 0), "0 + ThreeHours");
  },

  MethodAdd_NonZero() {
    assertNodaEqual(Offset.Add(ThreeHours, ThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours + ThreeHours");
    assertNodaEqual(Offset.Add(ThreeHours, NegativeThreeHours), Offset.Zero, "ThreeHours + (-ThreeHours)");
    assertNodaEqual(Offset.Add(NegativeTwelveHours, ThreeHours), TestObjects.createNegativeOffset(9, 0, 0), "-TwelveHours + ThreeHours");
  },

  // Instance method equivalents
  MethodPlus_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Zero.Plus(Offset.Zero).Milliseconds, 0, "0 + 0");
    assertNodaEqual(ThreeHours.Plus(Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours + 0");
    assertNodaEqual(Offset.Zero.Plus(ThreeHours), TestObjects.createPositiveOffset(3, 0, 0), "0 + ThreeHours");
  },

  MethodPlus_NonZero() {
    assertNodaEqual(ThreeHours.Plus(ThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours + ThreeHours");
    assertNodaEqual(ThreeHours.Plus(NegativeThreeHours), Offset.Zero, "ThreeHours + (-ThreeHours)");
    assertNodaEqual(NegativeTwelveHours.Plus(ThreeHours), TestObjects.createNegativeOffset(9, 0, 0), "-TwelveHours + ThreeHours");
  },
  // #endregion

  // #region operator -
  OperatorMinus_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Subtract(Offset.Zero, Offset.Zero), Offset.Zero, "0 - 0");
    assertNodaEqual(Offset.Subtract(ThreeHours, Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours - 0");
    assertNodaEqual(Offset.Subtract(Offset.Zero, ThreeHours), TestObjects.createNegativeOffset(3, 0, 0), "0 - ThreeHours");
  },

  OperatorMinus_NonZero() {
    assertNodaEqual(Offset.Subtract(ThreeHours, ThreeHours), Offset.Zero, "ThreeHours - ThreeHours");
    assertNodaEqual(Offset.Subtract(ThreeHours, NegativeThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours - (-ThreeHours)");
    assertNodaEqual(Offset.Subtract(NegativeTwelveHours, ThreeHours), TestObjects.createNegativeOffset(15, 0, 0), "-TwelveHours - ThreeHours");
  },

  // Static method equivalents
  Subtract_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Subtract(Offset.Zero, Offset.Zero), Offset.Zero, "0 - 0");
    assertNodaEqual(Offset.Subtract(ThreeHours, Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours - 0");
    assertNodaEqual(Offset.Subtract(Offset.Zero, ThreeHours), TestObjects.createNegativeOffset(3, 0, 0), "0 - ThreeHours");
  },

  Subtract_NonZero() {
    assertNodaEqual(Offset.Subtract(ThreeHours, ThreeHours), Offset.Zero, "ThreeHours - ThreeHours");
    assertNodaEqual(Offset.Subtract(ThreeHours, NegativeThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours - (-ThreeHours)");
    assertNodaEqual(Offset.Subtract(NegativeTwelveHours, ThreeHours), TestObjects.createNegativeOffset(15, 0, 0), "-TwelveHours - ThreeHours");
  },

  // Instance method equivalents
  Minus_Zero_IsNeutralElement() {
    assertNodaEqual(Offset.Zero.Minus(Offset.Zero), Offset.Zero, "0 - 0");
    assertNodaEqual(ThreeHours.Minus(Offset.Zero), TestObjects.createPositiveOffset(3, 0, 0), "ThreeHours - 0");
    assertNodaEqual(Offset.Zero.Minus(ThreeHours), TestObjects.createNegativeOffset(3, 0, 0), "0 - ThreeHours");
  },

  Minus_NonZero() {
    assertNodaEqual(ThreeHours.Minus(ThreeHours), Offset.Zero, "ThreeHours - ThreeHours");
    assertNodaEqual(ThreeHours.Minus(NegativeThreeHours), TestObjects.createPositiveOffset(6, 0, 0), "ThreeHours - (-ThreeHours)");
    assertNodaEqual(NegativeTwelveHours.Minus(ThreeHours), TestObjects.createNegativeOffset(15, 0, 0), "-TwelveHours - ThreeHours");
  },
  // #endregion
  // #endregion

  // #region OffsetTest.cs
  Max() {
    const x = Offset.FromSeconds(100);
    const y = Offset.FromSeconds(200);
    assertNodaEqual(Offset.Max(x, y), y);
    assertNodaEqual(Offset.Max(y, x), y);
    assertNodaEqual(Offset.Max(x, Offset.MinValue), x);
    assertNodaEqual(Offset.Max(Offset.MinValue, x), x);
    assertNodaEqual(Offset.Max(Offset.MaxValue, x), Offset.MaxValue);
    assertNodaEqual(Offset.Max(x, Offset.MaxValue), Offset.MaxValue);
  },

  Min() {
    const x = Offset.FromSeconds(100);
    const y = Offset.FromSeconds(200);
    assertNodaEqual(Offset.Min(x, y), x);
    assertNodaEqual(Offset.Min(y, x), x);
    assertNodaEqual(Offset.Min(x, Offset.MinValue), Offset.MinValue);
    assertNodaEqual(Offset.Min(Offset.MinValue, x), Offset.MinValue);
    assertNodaEqual(Offset.Min(Offset.MaxValue, x), x);
    assertNodaEqual(Offset.Min(x, Offset.MaxValue), x);
  },

  MinMaxValue() {
    TestHelper.assertMinMaxValue(Offset, Offset.MinValue, Offset.MaxValue);
  },

  DefaultConstructor() {
    // noda-js: there's no public constructor; the C# default value is an offset of zero seconds.
    const actual = Offset.NewSeconds(0);
    assertNodaEqual(actual, Offset.Zero);
  },
  // #endregion
}, {
  skip: {
    ToTimeSpan: "BCL interop (TimeSpan) isn't ported",
    FromTimeSpan_OutOfRange: "BCL interop (TimeSpan) isn't ported",
    FromTimeSpan_Truncation: "BCL interop (TimeSpan) isn't ported",
    FromTimeSpan_Simple: "BCL interop (TimeSpan) isn't ported",
    XmlSerialization: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
