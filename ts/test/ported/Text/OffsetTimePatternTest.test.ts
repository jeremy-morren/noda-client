// Ported from NodaTime 3.3.7: src/NodaTime.Test/Text/OffsetTimePatternTest.cs
// Copyright The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { LocalTime, NodaFormatInfo, Offset, OffsetTimePattern, type OffsetTime } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/OffsetTimePatternTest.generated.ts";
import { assertParseNull, CurrentCultureSkip, patternTestBaseBodies, type PatternTestData } from "./PatternTestSupport.ts";

port(
  fixture,
  {
    ...patternTestBaseBodies<OffsetTime>({
      // Data.CreatePattern()
      createPattern: (data: PatternTestData<OffsetTime>) => OffsetTimePattern.Create(data.pattern!, data.culture!, data.template!),
    }),

    CreateWithInvariantCulture() {
      const pattern = OffsetTimePattern.CreateWithInvariantCulture("HH:mm:sso<g>");
      expect(pattern.FormatInfo).toBe(NodaFormatInfo.InvariantInfo);
      const ot = new LocalTime(12, 34, 56).WithOffset(Offset.FromHours(2));
      expect(pattern.Format(ot)).toBe("12:34:56+02");
    },

    WithCulture() {
      const pattern = OffsetTimePattern.CreateWithInvariantCulture("HH:mm").WithCulture(scenarioCulture("Cultures.DotTimeSeparator"));
      const text = pattern.Format(new LocalTime(19, 30).WithOffset(Offset.Zero));
      expect(text).toBe("19.30");
    },

    WithPatternText() {
      const pattern = OffsetTimePattern.CreateWithInvariantCulture("HH:mm:ss").WithPatternText("HH:mm");
      const value = new LocalTime(13, 30).WithOffset(Offset.FromHours(2));
      const text = pattern.Format(value);
      expect(text).toBe("13:30");
    },

    WithTemplateValue() {
      const pattern = OffsetTimePattern.CreateWithInvariantCulture("o<G>").WithTemplateValue(new LocalTime(13, 30).WithOffset(Offset.Zero));
      const parsed = pattern.Parse("+02").Value;
      // Local time is taken from the template value; offset is from the text
      assertNodaEqual(parsed.TimeOfDay, new LocalTime(13, 30));
      assertNodaEqual(parsed.Offset, Offset.FromHours(2));
    },

    ParseNull: () => assertParseNull(OffsetTimePattern.ExtendedIso),
  },
  {
    skip: {
      CreateWithCurrentCulture: CurrentCultureSkip,
    },
  },
);
