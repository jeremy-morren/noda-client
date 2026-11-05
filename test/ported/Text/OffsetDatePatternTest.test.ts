// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/OffsetDatePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { ArgumentOutOfRangeError, CalendarSystem, LocalDate, NodaFormatInfo, Offset, OffsetDatePattern, type OffsetDate } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/OffsetDatePatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<OffsetDate>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<OffsetDate>) => OffsetDatePattern.Create(data.pattern!, data.culture!, data.template!),
    }),

    CreateWithInvariantCulture() {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("uuuu-MM-ddo<g>");
      expect(pattern.FormatInfo).toBe(NodaFormatInfo.InvariantInfo);
      const od = new LocalDate(2017, 8, 23).WithOffset(Offset.FromHours(2));
      expect(pattern.Format(od)).toBe("2017-08-23+02");
    },

    WithCulture() {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("uuuu/MM/dd o<G>").WithCulture(scenarioCulture("Cultures.FrCa"));
      const text = pattern.Format(new LocalDate(2000, 1, 1).WithOffset(Offset.FromHours(1)));
      expect(text).toBe("2000-01-01 +01");
    },

    WithPatternText() {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("uuuu-MM-dd").WithPatternText("dd MM uuuu o<g>");
      const value = new LocalDate(1970, 1, 1).WithOffset(Offset.FromHours(2));
      const text = pattern.Format(value);
      expect(text).toBe("01 01 1970 +02");
    },

    WithTemplateValue() {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("MM-dd").WithTemplateValue(new LocalDate(1970, 1, 1).WithOffset(Offset.FromHours(2)));
      const parsed = pattern.Parse("08-23").Value;
      assertNodaEqual(parsed.Date, new LocalDate(1970, 8, 23));
      assertNodaEqual(parsed.Offset, Offset.FromHours(2));
    },

    WithCalendar() {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("uuuu-MM-dd")
        .WithCalendar(CalendarSystem.Coptic);
      const parsed = pattern.Parse("0284-08-29").Value;
      assertNodaEqual(parsed.Date, new LocalDate(284, 8, 29, CalendarSystem.Coptic));
    },

    ParseNull: () => assertParseNull(OffsetDatePattern.GeneralIso),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = OffsetDatePattern.CreateWithInvariantCulture("yy-MM-dd o<g>").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows(ArgumentOutOfRangeError, () => OffsetDatePattern.GeneralIso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
