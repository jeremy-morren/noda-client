// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/CompositePatternBuilderPatternTest.cs
// Copyright 2017 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C#'s collection initializers ({ { pattern, predicate }, ... }) are calls to add().

import { expect } from "vitest";
import {
  CompositePatternBuilder,
  LocalDate,
  LocalDatePattern,
  LocalDateTimePattern,
  type LocalDateTime,
} from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/CompositePatternBuilderPatternTest.generated.ts";

port(fixture, {
  // See https://github.com/nodatime/nodatime/issues/607
  IsoPattern(text: string) {
    // We assert that the text round-trips. If it does, it's
    // reasonable to assume it parsed correctly...
    const shortPattern = LocalDateTimePattern.CreateWithInvariantCulture("uuuu'-'MM'-'dd'T'HH':'mm");
    const builder = new CompositePatternBuilder<LocalDateTime>();
    builder.Add(LocalDateTimePattern.ExtendedIso, _ => true);
    builder.Add(shortPattern, ldt => ldt.Second === 0 && ldt.NanosecondOfSecond === 0);
    const pattern = builder.Build();
    const value = pattern.Parse(text).Value;
    const formatted = pattern.Format(value);
    expect(formatted).toBe(text);
  },

  Format_NoValidPattern() {
    const builder = new CompositePatternBuilder<LocalDate>();
    builder.Add(LocalDatePattern.Iso, _ => false);
    builder.Add(LocalDatePattern.CreateWithInvariantCulture("uuuu"), _ => false);
    const pattern = builder.Build();
    assertThrows("FormatException", () => pattern.Format(new LocalDate(2017, 1, 1)));
  },

  Parse() {
    const builder = new CompositePatternBuilder<LocalDate>();
    builder.Add(LocalDatePattern.Iso, _ => true);
    builder.Add(LocalDatePattern.CreateWithInvariantCulture("uuuu"), _ => false);
    const pattern = builder.Build();
    expect(pattern.Parse("2017-03-20").Success).toBe(true);
    expect(pattern.Parse("2017-03").Success).toBe(false);
    expect(pattern.Parse("2017").Success).toBe(true);
  },

  Build_Empty() {
    const pattern = new CompositePatternBuilder<LocalDate>();
    assertThrows("InvalidOperationException", () => pattern.Build());
  },

  Enumerators() {
    const pattern1 = LocalDatePattern.Iso;
    const pattern2 = LocalDatePattern.CreateWithInvariantCulture("uuuu");

    const builder = new CompositePatternBuilder<LocalDate>();
    builder.Add(pattern1, _ => true);
    builder.Add(pattern2, _ => false);

    expect([...builder]).toEqual([pattern1, pattern2]);
    // C#: builder.OfType<LocalDatePattern>()
    expect([...builder].filter(p => p instanceof LocalDatePattern)).toEqual([pattern1, pattern2]);
  },
});
