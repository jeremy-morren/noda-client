// Ported from NodaTime 3.3.0: src/NodaTime.Test/OffsetTimeTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, NodaCultureInfo, LocalDate, LocalTime, Offset, OffsetTime, TimeAdjusters } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/OffsetTimeTest.generated.ts";

/** The instance getters declared on a class (C# Type.DeclaredProperties, instance members only). */
function declaredGetters(type: { prototype: object }): string[] {
  return Object.entries(Object.getOwnPropertyDescriptors(type.prototype))
    .filter(([, descriptor]) => descriptor.get !== undefined)
    .map(([name]) => name);
}

port(fixture, {
  LocalTimeProperties() {
    const local = new LocalTime(5, 23, 45).PlusNanoseconds(987654321);
    const offset = Offset.FromHours(5);

    const od = new OffsetTime(local, offset);

    const localTimeProperties = new Set(declaredGetters(LocalTime));
    const commonProperties = declaredGetters(OffsetTime).filter(p => localTimeProperties.has(p));
    expect(commonProperties.length).toBeGreaterThan(0);
    for (const property of commonProperties) {
      assertNodaEqual((od as any)[property], (local as any)[property], property);
    }
  },

  ComponentProperties() {
    const time = new LocalTime(12, 34, 15);
    const offset = Offset.FromHours(5);

    const offsetDate = new OffsetTime(time, offset);
    assertNodaEqual(offsetDate.Offset, offset);
    assertNodaEqual(offsetDate.TimeOfDay, time);
  },

  Equality() {
    const time1 = new LocalTime(4, 56, 23, 123);
    const time2 = new LocalTime(6, 23, 12, 987);
    const offset1 = Offset.FromHours(1);
    const offset2 = Offset.FromHours(2);

    const equal1 = new OffsetTime(time1, offset1);
    const equal2 = new OffsetTime(time1, offset1);
    const unequalByOffset = new OffsetTime(time1, offset2);
    const unequalByLocal = new OffsetTime(time2, offset1);

    TestHelper.testEqualsStruct(equal1, equal2, unequalByOffset);
    TestHelper.testEqualsStruct(equal1, equal2, unequalByLocal);

    TestHelper.testOperatorEquality(equal1, equal2, unequalByOffset);
    TestHelper.testOperatorEquality(equal1, equal2, unequalByLocal);
  },

  On() {
    const time = new LocalTime(14, 15, 12).PlusNanoseconds(123456789);
    const date = new LocalDate(2012, 6, 19, CalendarSystem.Julian);
    const offset = Offset.FromHours(5);

    assertNodaEqual(time.On(date).WithOffset(offset), new OffsetTime(time, offset).On(date));
  },

  WithOffset() {
    const time = new LocalTime(14, 15, 12).PlusNanoseconds(123456789);
    const initial = new OffsetTime(time, Offset.FromHours(2));
    const actual = initial.WithOffset(Offset.FromHours(5));
    const expected = new OffsetTime(time, Offset.FromHours(5));
    assertNodaEqual(actual, expected);
  },

  WithAdjuster() {
    const initial = new OffsetTime(new LocalTime(14, 15, 12), Offset.FromHours(-5));
    const actual = initial.With(TimeAdjusters.TruncateToHour);
    const expected = new OffsetTime(new LocalTime(14, 0), Offset.FromHours(-5));
    assertNodaEqual(actual, expected);
  },

  ToString_WithFormat() {
    const time = new LocalTime(14, 15, 12, 123);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetTime(time, offset);
    assertNodaEqual(offsetDate.toString("HH:mm:ss.fff o<-HH>", NodaCultureInfo.InvariantCulture), "14:15:12.123 01");
  },

  ToString_WithNullFormat() {
    const time = new LocalTime(14, 15, 12, 123);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetTime(time, offset);
    assertNodaEqual(offsetDate.toString(null, NodaCultureInfo.InvariantCulture), "14:15:12+01");
  },

  ToString_NoFormat() {
    const time = new LocalTime(14, 15, 12, 123);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetTime(time, offset);
    // noda-js: toString() always uses the invariant culture (no CultureSaver needed).
    assertNodaEqual(offsetDate.toString(), "14:15:12+01");
  },

  Deconstruction() {
    const time = new LocalTime(15, 33);
    const offset = Offset.FromHours(-2);
    const offsetTime = new OffsetTime(time, offset);

    // noda-js: Deconstruct is omitted; JS destructuring reads the getters.
    const { TimeOfDay: actualTime, Offset: actualOffset } = offsetTime;

    assertNodaEqual(actualTime, time);
    assertNodaEqual(actualOffset, offset);
  },
}, {
  skip: {
    XmlSerialization: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
