// Ported from NodaTime 3.3.0: src/NodaTime.Test/PeriodBuilderTest.cs
// Copyright 2012 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { ArgumentOutOfRangeError, Period, PeriodBuilder, PeriodUnits } from "../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../helpers/assertions.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/PeriodBuilderTest.generated.ts";

/** `new PeriodBuilder { ... }` (C# object initializer): Object.assign invokes the builder's property setters. */
function newPeriodBuilder(init: Partial<Pick<PeriodBuilder, "Years" | "Months" | "Weeks" | "Days" | "Hours" | "Minutes" | "Seconds"
  | "Milliseconds" | "Ticks" | "Nanoseconds">>): PeriodBuilder {
  return Object.assign(new PeriodBuilder(), init);
}

function call(_ignored: unknown): void {
}

port(fixture, {
  Indexer_Getter_ValidUnits() {
    const builder = newPeriodBuilder({
      Months: 1,
      Weeks: 2,
      Days: 3,
      Hours: 4,
      Minutes: 5,
      Seconds: 6,
      Milliseconds: 7,
      Ticks: 8,
      Nanoseconds: 9,
    });
    assertNodaEqual(builder.Get(PeriodUnits.Years), 0);
    assertNodaEqual(builder.Get(PeriodUnits.Months), 1);
    assertNodaEqual(builder.Get(PeriodUnits.Weeks), 2);
    assertNodaEqual(builder.Get(PeriodUnits.Days), 3);
    assertNodaEqual(builder.Get(PeriodUnits.Hours), 4);
    assertNodaEqual(builder.Get(PeriodUnits.Minutes), 5);
    assertNodaEqual(builder.Get(PeriodUnits.Seconds), 6);
    assertNodaEqual(builder.Get(PeriodUnits.Milliseconds), 7);
    assertNodaEqual(builder.Get(PeriodUnits.Ticks), 8);
    assertNodaEqual(builder.Get(PeriodUnits.Nanoseconds), 9);
  },

  Index_Getter_InvalidUnits() {
    const builder = new PeriodBuilder();
    assertThrows(ArgumentOutOfRangeError, () => call(builder.Get(0 as PeriodUnits)));
    assertThrows(ArgumentOutOfRangeError, () => call(builder.Get(-1 as PeriodUnits)));
    assertThrows(ArgumentOutOfRangeError, () => call(builder.Get(PeriodUnits.DateAndTime)));
  },

  Indexer_Setter_ValidUnits() {
    const builder = new PeriodBuilder();
    builder.Set(PeriodUnits.Months, 1);
    builder.Set(PeriodUnits.Weeks, 2);
    builder.Set(PeriodUnits.Days, 3);
    builder.Set(PeriodUnits.Hours, 4);
    builder.Set(PeriodUnits.Minutes, 5);
    builder.Set(PeriodUnits.Seconds, 6);
    builder.Set(PeriodUnits.Milliseconds, 7);
    builder.Set(PeriodUnits.Ticks, 8);
    const expected = newPeriodBuilder({
      Years: 0,
      Months: 1,
      Weeks: 2,
      Days: 3,
      Hours: 4,
      Minutes: 5,
      Seconds: 6,
      Milliseconds: 7,
      Ticks: 8,
    }).Build();
    assertNodaEqual(builder.Build(), expected);
  },

  Index_Setter_InvalidUnits() {
    const builder = new PeriodBuilder();
    assertThrows(ArgumentOutOfRangeError, () => builder.Set(0 as PeriodUnits, 1));
    assertThrows(ArgumentOutOfRangeError, () => builder.Set(-1 as PeriodUnits, 1));
    assertThrows(ArgumentOutOfRangeError, () => builder.Set(PeriodUnits.DateAndTime, 1));
  },

  Build_SingleUnit() {
    const period = newPeriodBuilder({ Hours: 10 }).Build();

    const expected = Period.FromHours(10);
    assertNodaEqual(period, expected);
  },

  Build_MultipleUnits() {
    const period = newPeriodBuilder({ Days: 5, Minutes: -10 }).Build();

    const expected = Period.Add(Period.FromDays(5), Period.FromMinutes(-10));
    assertNodaEqual(period, expected);
  },

  Build_Zero() {
    assertNodaEqual(new PeriodBuilder().Build(), Period.Zero);
  },
}, {
  skip: {
    XmlSerialization: "XML serialization is .NET-only",
    XmlSerialization_ExpectedUse: "XML serialization is .NET-only",
  },
});
