// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/InstantPatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { ArgumentOutOfRangeError, Duration, Instant, InstantPattern } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual, assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/InstantPatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<Instant>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<Instant>) => InstantPattern.CreateWithInvariantCulture(data.pattern!).WithTemplateValue(data.template!).WithCulture(data.culture!),
    }),

    IsoHandlesCommas() {
      const expected = Instant.Add(Instant.FromUtc(2012, 1, 1, 0, 0), Duration.Epsilon);
      const actual = InstantPattern.ExtendedIso.Parse("2012-01-01T00:00:00,000000001Z").Value;
      assertNodaEqual(actual, expected);
    },

    Create() {
      const pattern = InstantPattern.Create("HH:mm:ss", scenarioCulture("Cultures.DotTimeSeparator"));
      const text = pattern.Format(Instant.FromUtc(2000, 1, 1, 12, 34, 56));
      expect(text).toBe("12.34.56");
    },

    ParseNull: () => assertParseNull(InstantPattern.General),

    WithTwoDigitYearMax(twoDigitYearMax: number, text: string, expectedYear: number) {
      const pattern = InstantPattern.CreateWithInvariantCulture("yy-MM-dd'T'HH:mm:ss").WithTwoDigitYearMax(twoDigitYearMax);
      const value = pattern.Parse(text).Value;
      expect(value.InUtc().Year).toBe(expectedYear);
    },

    WithTwoDigitYearMax_Invalid: (twoDigitYearMax: number) =>
      assertThrows(ArgumentOutOfRangeError, () => InstantPattern.General.WithTwoDigitYearMax(twoDigitYearMax)),
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
