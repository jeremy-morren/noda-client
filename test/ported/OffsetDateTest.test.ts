// Ported from NodaTime 3.3.7: src/NodaTime.Test/OffsetDateTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, NodaCultureInfo, DateAdjusters, LocalDate, LocalTime, Offset, OffsetDate } from "../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { TestHelper } from "../helpers/TestHelper.ts";
import { fixture } from "../scenarios/OffsetDateTest.generated.ts";

/** The instance getters declared on a class (C# Type.DeclaredProperties, instance members only). */
function declaredGetters(type: { prototype: object }): string[] {
  return Object.entries(Object.getOwnPropertyDescriptors(type.prototype))
    .filter(([, descriptor]) => descriptor.get !== undefined)
    .map(([name]) => name);
}

port(fixture, {
  LocalDateProperties() {
    const local = new LocalDate(2012, 6, 19, CalendarSystem.Julian);
    const offset = Offset.FromHours(5);

    const od = new OffsetDate(local, offset);

    const localDateProperties = new Set(declaredGetters(LocalDate));
    const commonProperties = declaredGetters(OffsetDate).filter(p => localDateProperties.has(p));
    expect(commonProperties.length).toBeGreaterThan(0);
    for (const property of commonProperties) {
      assertNodaEqual((od as any)[property], (local as any)[property], property);
    }
  },

  ComponentProperties() {
    const date = new LocalDate(2012, 1, 2);
    const offset = Offset.FromHours(5);

    const offsetDate = new OffsetDate(date, offset);
    assertNodaEqual(offsetDate.Offset, offset);
    assertNodaEqual(offsetDate.Date, date);
  },

  Equality() {
    const date1 = new LocalDate(2012, 10, 6);
    const date2 = new LocalDate(2012, 9, 5);
    const offset1 = Offset.FromHours(1);
    const offset2 = Offset.FromHours(2);

    const equal1 = new OffsetDate(date1, offset1);
    const equal2 = new OffsetDate(date1, offset1);
    const unequalByOffset = new OffsetDate(date1, offset2);
    const unequalByLocal = new OffsetDate(date2, offset1);

    TestHelper.testEqualsStruct(equal1, equal2, unequalByOffset);
    TestHelper.testEqualsStruct(equal1, equal2, unequalByLocal);

    TestHelper.testOperatorEquality(equal1, equal2, unequalByOffset);
    TestHelper.testOperatorEquality(equal1, equal2, unequalByLocal);
  },

  At() {
    const date = new LocalDate(2012, 6, 19, CalendarSystem.Julian);
    const offset = Offset.FromHours(5);
    const time = new LocalTime(14, 15, 12).PlusNanoseconds(123456789);

    assertNodaEqual(date.At(time).WithOffset(offset), new OffsetDate(date, offset).At(time));
  },

  WithOffset() {
    const date = new LocalDate(2012, 6, 19);
    const initial = new OffsetDate(date, Offset.FromHours(2));
    const actual = initial.WithOffset(Offset.FromHours(5));
    const expected = new OffsetDate(date, Offset.FromHours(5));
    assertNodaEqual(actual, expected);
  },

  WithCalendar() {
    const julianDate = new LocalDate(2012, 6, 19, CalendarSystem.Julian);
    const isoDate = julianDate.WithCalendar(CalendarSystem.Iso);
    const offset = Offset.FromHours(5);
    const actual = new OffsetDate(julianDate, offset).WithCalendar(CalendarSystem.Iso);
    const expected = new OffsetDate(isoDate, offset);
    assertNodaEqual(actual, expected);
  },

  WithAdjuster() {
    const initial = new OffsetDate(new LocalDate(2016, 6, 19), Offset.FromHours(-5));
    const actual = initial.With(DateAdjusters.StartOfMonth);
    const expected = new OffsetDate(new LocalDate(2016, 6, 1), Offset.FromHours(-5));
    assertNodaEqual(actual, expected);
  },

  ToString_WithFormat() {
    const date = new LocalDate(2012, 10, 6);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetDate(date, offset);
    assertNodaEqual(offsetDate.toString("uuuu/MM/dd o<-HH>", NodaCultureInfo.InvariantCulture), "2012/10/06 01");
  },

  ToString_WithNullFormat() {
    const date = new LocalDate(2012, 10, 6);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetDate(date, offset);
    assertNodaEqual(offsetDate.toString(null, NodaCultureInfo.InvariantCulture), "2012-10-06+01");
  },

  ToString_NoFormat() {
    const date = new LocalDate(2012, 10, 6);
    const offset = Offset.FromHours(1);
    const offsetDate = new OffsetDate(date, offset);
    // noda-js: toString() always uses the invariant culture (no CultureSaver needed).
    assertNodaEqual(offsetDate.toString(), "2012-10-06+01");
  },

  Deconstruction() {
    const date = new LocalDate(2015, 3, 28);
    const offset = Offset.FromHours(-2);
    const offsetDate = new OffsetDate(date, offset);

    // noda-js: Deconstruct is omitted; JS destructuring reads the getters.
    const { Date: actualDate, Offset: actualOffset } = offsetDate;

    assertNodaEqual(actualDate, date);
    assertNodaEqual(actualOffset, offset);
  },
}, {
  skip: {
    XmlSerialization_Iso: "XML serialization isn't ported",
    XmlSerialization_Bce: "XML serialization isn't ported",
    XmlSerialization_NonIso: "XML serialization isn't ported",
    XmlSerialization_Invalid: "XML serialization isn't ported",
  },
});
