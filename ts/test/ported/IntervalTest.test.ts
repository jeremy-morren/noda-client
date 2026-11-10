// Ported from NodaTime 3.3.7: src/NodaTime.Test/IntervalTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import {
  Duration,
  Instant,
  InstantPattern,
  Interval,
  LocalDateTime,
  NodaConstants,
} from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/IntervalTest.generated.ts";

const SampleStart = NodaConstants.UnixEpoch.PlusNanoseconds(-30001);
const SampleEnd = NodaConstants.UnixEpoch.PlusNanoseconds(40001);

const XmlNotPorted = "XML serialization isn't ported";

port(fixture, {
  Construction_Success() {
    const interval = new Interval(SampleStart, SampleEnd);
    assertNodaEqual(interval.Start, SampleStart);
    assertNodaEqual(interval.End, SampleEnd);
  },

  Construction_EqualStartAndEnd() {
    const interval = new Interval(SampleStart, SampleStart);
    assertNodaEqual(interval.Start, SampleStart);
    assertNodaEqual(interval.End, SampleStart);
    assertNodaEqual(interval.Duration, Duration.Zero);
  },

  Construction_EndBeforeStart() {
    assertThrows("ArgumentOutOfRangeException", () => new Interval(SampleEnd, SampleStart));
    // noda-js: the (Instant?, Instant?) overload is the same constructor.
    assertThrows("ArgumentOutOfRangeException", () => new Interval(SampleEnd as Instant | null, SampleStart as Instant | null));
  },

  Equals() {
    TestHelper.testEqualsStruct(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      new Interval(NodaConstants.UnixEpoch, SampleEnd));
    TestHelper.testEqualsStruct(
      new Interval(null, SampleEnd),
      new Interval(null, SampleEnd),
      new Interval(NodaConstants.UnixEpoch, SampleEnd));
    TestHelper.testEqualsStruct(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      new Interval(NodaConstants.UnixEpoch, SampleEnd));
    TestHelper.testEqualsStruct(
      new Interval(null, null),
      new Interval(null, null),
      new Interval(NodaConstants.UnixEpoch, SampleEnd));
  },

  Operators() {
    TestHelper.testOperatorEquality(
      new Interval(SampleStart, SampleEnd),
      new Interval(SampleStart, SampleEnd),
      new Interval(NodaConstants.UnixEpoch, SampleEnd));
  },

  Duration() {
    const interval = new Interval(SampleStart, SampleEnd);
    assertNodaEqual(interval.Duration, Duration.FromNanoseconds(70002));
  },

  ToStringUsesExtendedIsoFormat() {
    const start = new LocalDateTime(2013, 4, 12, 17, 53, 23).PlusNanoseconds(123456789).InUtc().ToInstant();
    const end = new LocalDateTime(2013, 10, 12, 17, 1, 2, 120).InUtc().ToInstant();
    const value = new Interval(start, end);
    expect(value.toString()).toBe("2013-04-12T17:53:23.123456789Z/2013-10-12T17:01:02.12Z");
  },

  ToString_Infinite() {
    const value = new Interval(null, null);
    expect(value.toString()).toBe("StartOfTime/EndOfTime");
  },

  Contains(candidateText: string, expectedResult: boolean) {
    const start = Instant.FromUtc(2000, 1, 1, 0, 0);
    const end = Instant.FromUtc(2020, 1, 1, 0, 0);
    const interval = new Interval(start, end);
    const candidate = InstantPattern.ExtendedIso.Parse(candidateText).Value;
    expect(interval.Contains(candidate)).toBe(expectedResult);
  },

  Contains_Infinite() {
    const interval = new Interval(null, null);
    expect(interval.Contains(Instant.MaxValue)).toBe(true);
    expect(interval.Contains(Instant.MinValue)).toBe(true);
  },

  HasStart() {
    expect(new Interval(Instant.MinValue, null).HasStart).toBe(true);
    expect(new Interval(null, Instant.MinValue).HasStart).toBe(false);
  },

  HasEnd() {
    expect(new Interval(null, Instant.MaxValue).HasEnd).toBe(true);
    expect(new Interval(Instant.MaxValue, null).HasEnd).toBe(false);
  },

  Start() {
    assertNodaEqual(new Interval(NodaConstants.UnixEpoch, null).Start, NodaConstants.UnixEpoch);
    const noStart = new Interval(null, NodaConstants.UnixEpoch);
    assertThrows("InvalidOperationException", () => noStart.Start.toString());
  },

  End() {
    assertNodaEqual(new Interval(null, NodaConstants.UnixEpoch).End, NodaConstants.UnixEpoch);
    const noEnd = new Interval(NodaConstants.UnixEpoch, null);
    assertThrows("InvalidOperationException", () => noEnd.End.toString());
  },

  Contains_EmptyInterval() {
    const instant = NodaConstants.UnixEpoch;
    const interval = new Interval(instant, instant);
    expect(interval.Contains(instant)).toBe(false);
  },

  Contains_EmptyInterval_MaxValue() {
    const instant = Instant.MaxValue;
    const interval = new Interval(instant, instant);
    // This would have been true under Noda Time 1.x
    expect(interval.Contains(instant)).toBe(false);
  },

  Deconstruction() {
    // noda-js: C#'s new Instant() is the Unix epoch.
    const start = NodaConstants.UnixEpoch;
    const end = start.PlusTicks(1_000_000);
    const value = new Interval(start, end);

    const { Start: actualStart, End: actualEnd } = value;

    assertNodaEqual(actualStart, start);
    assertNodaEqual(actualEnd, end);
  },
}, {
  skip: {
    DefaultConstructor: "C# default(Interval) struct construction; Interval has no parameterless constructor in noda-js",
    XmlSerialization: XmlNotPorted,
    XmlSerialization_Extremes: XmlNotPorted,
    XmlSerialization_ExtraContent: XmlNotPorted,
    XmlSerialization_SwapAttributeOrder: XmlNotPorted,
    XmlSerialization_FromBeginningOfTime: XmlNotPorted,
    XmlSerialization_ToEndOfTime: XmlNotPorted,
    XmlSerialization_AllOfTime: XmlNotPorted,
    XmlSerialization_Invalid: XmlNotPorted,
    Deconstruction_IntervalWithoutStart: "Deconstruct isn't ported (it yields a null start); JS destructuring reads the start getter, which throws",
    Deconstruction_IntervalWithoutEnd: "Deconstruct isn't ported (it yields a null end); JS destructuring reads the end getter, which throws",
  },
});
