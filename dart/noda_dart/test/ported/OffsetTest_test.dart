// Ported from NodaTime 6e024dde: src/NodaTime.Test/OffsetTest.cs (+ OffsetTest.Construction.cs, OffsetTest.Operators.cs)
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import 'dart:core' as core;
import 'dart:core' hide Duration;

import 'package:noda_dart/src/NodaConstants.dart';
import 'package:noda_dart/src/Offset.dart';

import '../helpers/Assertions.dart';
import '../helpers/Scenarios.dart';
import '../helpers/TestHelper.dart';
import '../helpers/TestObjects.dart';
import '../scenarios/OffsetTest.generated.dart' as scenarios;

final Offset ThreeHours = TestObjects.CreatePositiveOffset(3, 0, 0);
final Offset NegativeThreeHours = TestObjects.CreateNegativeOffset(3, 0, 0);
final Offset NegativeTwelveHours = TestObjects.CreateNegativeOffset(12, 0, 0);

void main() {
  port(scenarios.fixture, {
    // #region OffsetTest.Construction.cs
    'Zero': (args) {
      Offset test = Offset.Zero;
      Assert.AreEqual(0, test.Milliseconds);
    },

    'FromSeconds_Valid': (args) {
      var test = Offset.FromSeconds(12345);
      Assert.AreEqual(12345, test.Seconds);
    },

    'FromSeconds_Invalid': (args) {
      int seconds = 18 * NodaConstants.SecondsPerHour + 1;
      Assert.Throws<RangeError>(() => Offset.FromSeconds(seconds));
      Assert.Throws<RangeError>(() => Offset.FromSeconds(-seconds));
    },

    'FromMilliseconds_Valid': (args) {
      Offset value = Offset.FromMilliseconds(-15 * NodaConstants.MillisecondsPerMinute);
      Assert.AreEqual(-15 * NodaConstants.SecondsPerMinute, value.Seconds);
      Assert.AreEqual(-15 * NodaConstants.MillisecondsPerMinute, value.Milliseconds);
    },

    'FromMilliseconds_Invalid': (args) {
      int millis = 18 * NodaConstants.MillisecondsPerHour + 1;
      Assert.Throws<RangeError>(() => Offset.FromMilliseconds(millis));
      Assert.Throws<RangeError>(() => Offset.FromMilliseconds(-millis));
    },

    'FromTicks_Valid': (args) {
      Offset value = Offset.FromTicks(-15 * NodaConstants.TicksPerMinute);
      Assert.AreEqual(-15 * NodaConstants.SecondsPerMinute, value.Seconds);
      Assert.AreEqual(-15 * NodaConstants.TicksPerMinute, value.Ticks);
    },

    'FromTicks_Invalid': (args) {
      int ticks = 18 * NodaConstants.TicksPerHour + 1;
      Assert.Throws<RangeError>(() => Offset.FromTicks(ticks));
      Assert.Throws<RangeError>(() => Offset.FromTicks(-ticks));
    },

    'FromNanoseconds_Valid': (args) {
      Offset value = Offset.FromNanoseconds(-15 * NodaConstants.NanosecondsPerMinute);
      Assert.AreEqual(-15 * NodaConstants.SecondsPerMinute, value.Seconds);
      Assert.AreEqual(-15 * NodaConstants.NanosecondsPerMinute, value.Nanoseconds);
    },

    'FromNanoseconds_Invalid': (args) {
      int nanos = 18 * NodaConstants.NanosecondsPerHour + 1;
      Assert.Throws<RangeError>(() => Offset.FromNanoseconds(nanos));
      Assert.Throws<RangeError>(() => Offset.FromNanoseconds(-nanos));
    },

    'FromHours_Valid': (args) {
      Offset value = Offset.FromHours(-15);
      Assert.AreEqual(-15 * NodaConstants.SecondsPerHour, value.Seconds);
    },

    'FromHours_Invalid': (args) {
      Assert.Throws<RangeError>(() => Offset.FromHours(19));
      Assert.Throws<RangeError>(() => Offset.FromHours(-19));
    },

    'FromHoursAndMinutes_Valid': (args) {
      Offset value = Offset.FromHoursAndMinutes(5, 30);
      Assert.AreEqual(5 * NodaConstants.SecondsPerHour + 30 * NodaConstants.SecondsPerMinute, value.Seconds);
    },
    // #endregion

    // #region OffsetTest.cs
    'Max': (args) {
      Offset x = Offset.FromSeconds(100);
      Offset y = Offset.FromSeconds(200);
      Assert.AreEqual(y, Offset.Max(x, y));
      Assert.AreEqual(y, Offset.Max(y, x));
      Assert.AreEqual(x, Offset.Max(x, Offset.MinValue));
      Assert.AreEqual(x, Offset.Max(Offset.MinValue, x));
      Assert.AreEqual(Offset.MaxValue, Offset.Max(Offset.MaxValue, x));
      Assert.AreEqual(Offset.MaxValue, Offset.Max(x, Offset.MaxValue));
    },

    'Min': (args) {
      Offset x = Offset.FromSeconds(100);
      Offset y = Offset.FromSeconds(200);
      Assert.AreEqual(x, Offset.Min(x, y));
      Assert.AreEqual(x, Offset.Min(y, x));
      Assert.AreEqual(Offset.MinValue, Offset.Min(x, Offset.MinValue));
      Assert.AreEqual(Offset.MinValue, Offset.Min(Offset.MinValue, x));
      Assert.AreEqual(x, Offset.Min(Offset.MaxValue, x));
      Assert.AreEqual(x, Offset.Min(x, Offset.MaxValue));
    },

    // C#'s TimeSpan is Dart's core.Duration (ToTimeSpan → ToCoreDuration, FromTimeSpan → FromCoreDuration).
    'ToTimeSpan': (args) {
      core.Duration ts = Offset.FromSeconds(1234).ToCoreDuration();
      Assert.AreEqual(ts, core.Duration(seconds: 1234));
    },

    'FromTimeSpan_OutOfRange': (args) {
      final [int hours] = args;
      core.Duration ts = core.Duration(hours: hours);
      Assert.Throws<RangeError>(() => Offset.FromCoreDuration(ts));
    },

    'FromTimeSpan_Truncation': (args) {
      core.Duration ts = core.Duration(milliseconds: 1000 + 200);
      Assert.AreEqual(Offset.FromSeconds(1), Offset.FromCoreDuration(ts));
    },

    'FromTimeSpan_Simple': (args) {
      core.Duration ts = core.Duration(hours: 2);
      Assert.AreEqual(Offset.FromHours(2), Offset.FromCoreDuration(ts));
    },

    'TestToString': (args) {
      var offset = Offset.FromHoursAndMinutes(5, 30);
      Assert.AreEqual(offset.ToStringPattern(null, null), offset.toString());
    },
    // #endregion

    // #region OffsetTest.Operators.cs
    'IEquatableIComparable_Tests': (args) {
      var value = Offset.FromSeconds(12345);
      var equalValue = Offset.FromSeconds(12345);
      var greaterValue = Offset.FromSeconds(54321);

      TestHelper.TestEqualsStruct(value, equalValue, [greaterValue]);
      TestHelper.TestCompareToStruct(value, equalValue, [greaterValue]);
      TestHelper.TestNonGenericCompareTo(value, equalValue, [greaterValue]);
      TestHelper.TestOperatorComparisonEquality(value, equalValue, [greaterValue]);
    },

    'NegateOperator': (args) {
      Assert.AreEqual(Offset.Zero, -Offset.Zero, '-0');
      Assert.AreEqual(Offset.FromSeconds(-1), -Offset.FromSeconds(1), '-1');
      Assert.AreEqual(Offset.FromSeconds(7), -Offset.FromSeconds(-7), '- (-7)');
    },

    'NegateMethod': (args) {
      Assert.AreEqual(Offset.Zero, Offset.Negate(Offset.Zero), '-0');
      Assert.AreEqual(Offset.FromSeconds(-1), Offset.Negate(Offset.FromSeconds(1)), '-1');
      Assert.AreEqual(Offset.FromSeconds(7), Offset.Negate(Offset.FromSeconds(-7)), '- (-7)');
    },

    // #region operator +
    'OperatorPlus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(0, (Offset.Zero + Offset.Zero).Seconds, '0 + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), ThreeHours + Offset.Zero, 'ThreeHours + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), Offset.Zero + ThreeHours, '0 + ThreeHours');
    },

    'OperatorPlus_NonZero': (args) {
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), ThreeHours + ThreeHours, 'ThreeHours + ThreeHours');
      Assert.AreEqual(Offset.Zero, ThreeHours + NegativeThreeHours, 'ThreeHours + (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(9, 0, 0), NegativeTwelveHours + ThreeHours, '-TwelveHours + ThreeHours');
    },

    // Static method equivalents
    'MethodAdd_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(0, Offset.Add(Offset.Zero, Offset.Zero).Milliseconds, '0 + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), Offset.Add(ThreeHours, Offset.Zero), 'ThreeHours + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), Offset.Add(Offset.Zero, ThreeHours), '0 + ThreeHours');
    },

    'MethodAdd_NonZero': (args) {
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), Offset.Add(ThreeHours, ThreeHours), 'ThreeHours + ThreeHours');
      Assert.AreEqual(Offset.Zero, Offset.Add(ThreeHours, NegativeThreeHours), 'ThreeHours + (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(9, 0, 0), Offset.Add(NegativeTwelveHours, ThreeHours), '-TwelveHours + ThreeHours');
    },

    // Instance method equivalents
    'MethodPlus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(0, Offset.Zero.Plus(Offset.Zero).Milliseconds, '0 + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), ThreeHours.Plus(Offset.Zero), 'ThreeHours + 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), Offset.Zero.Plus(ThreeHours), '0 + ThreeHours');
    },

    'MethodPlus_NonZero': (args) {
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), ThreeHours.Plus(ThreeHours), 'ThreeHours + ThreeHours');
      Assert.AreEqual(Offset.Zero, ThreeHours.Plus(NegativeThreeHours), 'ThreeHours + (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(9, 0, 0), NegativeTwelveHours.Plus(ThreeHours), '-TwelveHours + ThreeHours');
    },
    // #endregion

    // #region operator -
    'OperatorMinus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(Offset.Zero, Offset.Zero - Offset.Zero, '0 - 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), ThreeHours - Offset.Zero, 'ThreeHours - 0');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(3, 0, 0), Offset.Zero - ThreeHours, '0 - ThreeHours');
    },

    'OperatorMinus_NonZero': (args) {
      Assert.AreEqual(Offset.Zero, ThreeHours - ThreeHours, 'ThreeHours - ThreeHours');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), ThreeHours - NegativeThreeHours, 'ThreeHours - (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(15, 0, 0), NegativeTwelveHours - ThreeHours, '-TwelveHours - ThreeHours');
    },

    // Static method equivalents
    'Subtract_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(Offset.Zero, Offset.Subtract(Offset.Zero, Offset.Zero), '0 - 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), Offset.Subtract(ThreeHours, Offset.Zero), 'ThreeHours - 0');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(3, 0, 0), Offset.Subtract(Offset.Zero, ThreeHours), '0 - ThreeHours');
    },

    'Subtract_NonZero': (args) {
      Assert.AreEqual(Offset.Zero, Offset.Subtract(ThreeHours, ThreeHours), 'ThreeHours - ThreeHours');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), Offset.Subtract(ThreeHours, NegativeThreeHours), 'ThreeHours - (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(15, 0, 0), Offset.Subtract(NegativeTwelveHours, ThreeHours), '-TwelveHours - ThreeHours');
    },

    // Instance method equivalents
    'Minus_Zero_IsNeutralElement': (args) {
      Assert.AreEqual(Offset.Zero, Offset.Zero.Minus(Offset.Zero), '0 - 0');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(3, 0, 0), ThreeHours.Minus(Offset.Zero), 'ThreeHours - 0');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(3, 0, 0), Offset.Zero.Minus(ThreeHours), '0 - ThreeHours');
    },

    'Minus_NonZero': (args) {
      Assert.AreEqual(Offset.Zero, ThreeHours.Minus(ThreeHours), 'ThreeHours - ThreeHours');
      Assert.AreEqual(TestObjects.CreatePositiveOffset(6, 0, 0), ThreeHours.Minus(NegativeThreeHours), 'ThreeHours - (-ThreeHours)');
      Assert.AreEqual(TestObjects.CreateNegativeOffset(15, 0, 0), NegativeTwelveHours.Minus(ThreeHours), '-TwelveHours - ThreeHours');
    },
    // #endregion
    // #endregion
  }, skip: {
    'MinMaxValue': SkipReasons.MinMaxValue,
    'DefaultConstructor': SkipReasons.DefaultConstructor,
    'XmlSerialization': SkipReasons.Xml,
    'XmlSerialization_Invalid': SkipReasons.Xml,
    'UnaryPlusOperator': SkipReasons.UnaryPlus,
  });
}
