// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/YearMonthPatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { ArgumentOutOfRangeError, NodaCultureInfo, YearMonth, YearMonthPattern } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/YearMonthPatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<YearMonth>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<YearMonth>) => YearMonthPattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    CreateWithSpecificCulture() {
      const pattern = YearMonthPattern.Create("uuuu/MM", scenarioCulture("Cultures.FrCa"));
      expect(pattern.Format(new YearMonth(2017, 8))).toBe("2017-08");
    },

    CreateWithTemplateValue() {
      // This is testing the Create call specifying the template directly, instead of the WithTemplate method
      const template = new YearMonth(2000, 6);
      const pattern = YearMonthPattern.Create("uuuu", NodaCultureInfo.InvariantCulture, template);
      assertNodaEqual(pattern.TemplateValue, template);
      const parseResult = pattern.Parse("1990");
      expect(parseResult.Success).toBe(true);
      assertNodaEqual(parseResult.Value, new YearMonth(1990, 6));
    },

    ParseNull: () => assertParseNull(YearMonthPattern.Iso),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = YearMonthPattern.CreateWithInvariantCulture("yy-MM").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid(twoDigitYearMax: number) {
      assertThrows(ArgumentOutOfRangeError, () => YearMonthPattern.Iso.WithTwoDigitYearMax(twoDigitYearMax));
    },
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
