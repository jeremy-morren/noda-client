// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/ZoneIntervalTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the C# == / != operators on ZoneInterval (reference types, so null-safe) are equals(); a null left operand
// is compared with the C# operator semantics (null == null is true). The internal Instant + Offset operator (giving a
// LocalInstant) is Instant.plus(Offset). toString() always uses the invariant culture, so no CultureSaver is needed.

import { expect } from "vitest";
import {
  Duration,
  Instant,
  InvalidOperationError,
  LocalDateTime,
  Offset,
  OverflowError,
  ZoneInterval,
} from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/ZoneIntervalTest.generated.ts";

const SampleStart = Instant.FromUtc(2011, 6, 3, 10, 15);
const SampleEnd = Instant.FromUtc(2011, 8, 2, 13, 45);

const SampleInterval =
  new ZoneInterval("TestTime", SampleStart, SampleEnd,
    Offset.FromHours(9), Offset.FromHours(1));

/** The C# operator == for ZoneInterval (null-safe). */
function opEquality(left: ZoneInterval | null, right: ZoneInterval | null): boolean {
  if (left === right) {
    return true;
  }
  if (left === null || right === null) {
    return false;
  }
  return left.Equals(right);
}

/** The C# operator != for ZoneInterval. */
function opInequality(left: ZoneInterval | null, right: ZoneInterval | null): boolean {
  return !opEquality(left, right);
}

port(fixture, {
  PassthroughProperties() {
    expect(SampleInterval.Name).toBe("TestTime");
    assertNodaEqual(SampleInterval.StandardOffset, Offset.FromHours(8));
    assertNodaEqual(SampleInterval.Savings, Offset.FromHours(1));
    assertNodaEqual(SampleInterval.WallOffset, Offset.FromHours(9));
    assertNodaEqual(SampleInterval.Start, SampleStart);
    assertNodaEqual(SampleInterval.End, SampleEnd);
  },

  // Having one test per property feels like a waste of time to me (Jon)...
  // If any of them fail, I'm going to be looking here anyway, and they're
  // fairly interrelated anyway.
  ComputedProperties() {
    const start = new LocalDateTime(2011, 6, 3, 19, 15);
    const end = new LocalDateTime(2011, 8, 2, 22, 45);
    assertNodaEqual(SampleInterval.IsoLocalStart, start);
    assertNodaEqual(SampleInterval.IsoLocalEnd, end);
    assertNodaEqual(SampleInterval.Duration, SampleEnd.Minus(SampleStart));
  },

  Contains_Instant_Normal() {
    expect(SampleInterval.Contains(SampleStart)).toBe(true);
    expect(SampleInterval.Contains(SampleEnd)).toBe(false);
    expect(SampleInterval.Contains(Instant.MinValue)).toBe(false);
    expect(SampleInterval.Contains(Instant.MaxValue)).toBe(false);
  },

  Contains_Instant_WholeOfTime_ViaNullity() {
    const interval = new ZoneInterval("All Time", null, null,
      Offset.FromHours(9), Offset.FromHours(1));
    expect(interval.Contains(SampleStart)).toBe(true);
    expect(interval.Contains(Instant.MinValue)).toBe(true);
    expect(interval.Contains(Instant.MaxValue)).toBe(true);
  },

  Contains_Instant_WholeOfTime_ViaSpecialInstants() {
    const interval = new ZoneInterval("All Time", Instant.BeforeMinValue, Instant.AfterMaxValue,
      Offset.FromHours(9), Offset.FromHours(1));
    expect(interval.Contains(SampleStart)).toBe(true);
    expect(interval.Contains(Instant.MinValue)).toBe(true);
    expect(interval.Contains(Instant.MaxValue)).toBe(true);
  },

  Contains_LocalInstant_WholeOfTime() {
    const interval = new ZoneInterval("All Time", Instant.BeforeMinValue, Instant.AfterMaxValue,
      Offset.FromHours(9), Offset.FromHours(1));
    expect(interval.Contains(SampleStart.Plus(Offset.Zero))).toBe(true);
    expect(interval.Contains(Instant.MinValue.Plus(Offset.Zero))).toBe(true);
    expect(interval.Contains(Instant.MaxValue.Plus(Offset.Zero))).toBe(true);
  },

  Contains_OutsideLocalInstantange() {
    const veryEarly = new ZoneInterval("Very early", Instant.BeforeMinValue, Instant.MinValue.Plus(Duration.FromHours(8)), Offset.FromHours(-9), Offset.Zero);
    const veryLate = new ZoneInterval("Very late", Instant.MaxValue.Minus(Duration.FromHours(8)), Instant.AfterMaxValue, Offset.FromHours(9), Offset.Zero);
    // The instants are contained...
    expect(veryEarly.Contains(Instant.MinValue.Plus(Duration.FromHours(4)))).toBe(true);
    expect(veryLate.Contains(Instant.MaxValue.Minus(Duration.FromHours(4)))).toBe(true);
    // But there are no valid local instants
    expect(veryEarly.Contains(Instant.MinValue.Plus(Offset.Zero))).toBe(false);
    expect(veryLate.Contains(Instant.MaxValue.Plus(Offset.Zero))).toBe(false);
  },

  IsoLocalStartAndEnd_Infinite() {
    const interval = new ZoneInterval("All time", null, null, Offset.Zero, Offset.Zero);
    assertThrows(InvalidOperationError, () => interval.IsoLocalStart.toString());
    assertThrows(InvalidOperationError, () => interval.IsoLocalEnd.toString());
  },

  IsoLocalStartAndEnd_OutOfRange() {
    let interval = new ZoneInterval("All time", Instant.MinValue, null, Offset.FromHours(-1), Offset.Zero);
    assertThrows(OverflowError, () => interval.IsoLocalStart.toString());
    interval = new ZoneInterval("All time", null, Instant.MaxValue, Offset.FromHours(11), Offset.Zero);
    assertThrows(OverflowError, () => interval.IsoLocalEnd.toString());
  },

  Equality() {
    TestHelper.testEqualsClass(
      // Equal values
      new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
      new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
      // Unequal values
      new ZoneInterval("name2", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
      new ZoneInterval("name", SampleStart.PlusNanoseconds(1), SampleEnd, Offset.FromHours(1), Offset.FromHours(2)),
      new ZoneInterval("name", SampleStart, SampleEnd.PlusNanoseconds(1), Offset.FromHours(1), Offset.FromHours(2)),
      new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(2), Offset.FromHours(2)),
      new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(3)));
  },

  EqualityOperators() {
    const val1 = new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
    const val2 = new ZoneInterval("name", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
    const val3 = new ZoneInterval("name2", SampleStart, SampleEnd, Offset.FromHours(1), Offset.FromHours(2));
    const val4: ZoneInterval | null = null;

    expect(opEquality(val1, val2)).toBe(true);
    expect(opEquality(val1, val3)).toBe(false);
    expect(opEquality(val1, val4)).toBe(false);
    expect(opEquality(val4, val1)).toBe(false);
    expect(opEquality(val4, null)).toBe(true);
    expect(opEquality(null, val4)).toBe(true);

    expect(opInequality(val1, val2)).toBe(false);
    expect(opInequality(val1, val3)).toBe(true);
    expect(opInequality(val1, val4)).toBe(true);
    expect(opInequality(val4, val1)).toBe(true);
    expect(opInequality(val4, null)).toBe(false);
    expect(opInequality(null, val4)).toBe(false);
  },

  ZoneIntervalToString() {
    expect(SampleInterval.toString()).toBe("TestTime: [2011-06-03T10:15:00Z, 2011-08-02T13:45:00Z) +09 (+01)");
  },
});
