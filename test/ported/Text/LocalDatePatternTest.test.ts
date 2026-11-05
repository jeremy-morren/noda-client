// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/LocalDatePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { CalendarSystem, LocalDate, LocalDatePattern } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/LocalDatePatternTest.generated.ts";
import {
  assertParseNull,
  BclFormattingSkip,
  CurrentCultureSkip,
  patternTestBaseBodies,
  type PatternTestData,
} from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<LocalDate>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<LocalDate>) => LocalDatePattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    WithCalendar() {
      const pattern = LocalDatePattern.Iso.WithCalendar(CalendarSystem.Coptic);
      const value = pattern.Parse("0284-08-29").Value;
      assertNodaEqual(value, new LocalDate(284, 8, 29, CalendarSystem.Coptic));
    },

    ParseNull: () => assertParseNull(LocalDatePattern.Iso),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = LocalDatePattern.CreateWithInvariantCulture("yy-MM-dd").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows("ArgumentOutOfRangeException", () => LocalDatePattern.Iso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  },
  {
    skip: {
      BclLongDatePatternGivesSameResultsInNoda: BclFormattingSkip,
      BclShortDatePatternGivesSameResultsInNoda: BclFormattingSkip,
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
