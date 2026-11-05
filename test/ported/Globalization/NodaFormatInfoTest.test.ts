// Ported from NodaTime 3.3.7: src/NodaTime.Test/Globalization/NodaFormatInfoTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: cultures are immutable and always read-only, so C#'s Clone()/CultureInfo.ReadOnly() become
// NodaCultureInfo.FromData() with (modified) culture data.

import { expect } from "vitest";
import {
  NodaCultureInfo,
  DateTimeFormatInfo,
  Era,
  NodaFormatInfo,
  type CultureData,
} from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { scenarioCulture } from "../../helpers/decode.ts";
import { port } from "../../helpers/scenarios.ts";
import { scenarioCultures } from "../../scenarios/cultures.generated.ts";
import { fixture } from "../../scenarios/Globalization/NodaFormatInfoTest.generated.ts";

const enUs = scenarioCulture("en-US");
const enGb = scenarioCulture("en-GB");

/** C#'s new CultureInfo(name): a new (not cached) culture instance with the same data. */
function newCulture(name: string): NodaCultureInfo {
  return NodaCultureInfo.FromData(scenarioCultures[name] as CultureData);
}

port(
  fixture,
  {
    // Just check we can actually build a NodaFormatInfo for every culture, outside
    // text-specific tests.
    ConvertCulture(culture: NodaCultureInfo) {
      NodaFormatInfo.GetFormatInfo(culture);
    },

    TestCachingWithReadOnly() {
      const original = newCulture("en-US");
      // Use a read-only wrapper so that it gets cached
      // (noda-js: cultures are always read-only.)
      const wrapper = original;

      const nodaWrapper1 = NodaFormatInfo.GetFormatInfo(wrapper);
      const nodaWrapper2 = NodaFormatInfo.GetFormatInfo(wrapper);
      expect(nodaWrapper2).toBe(nodaWrapper1);
    },

    TestCachingWithClonedCulture() {
      const data = scenarioCultures["en-US"] as CultureData;
      const original = NodaCultureInfo.FromData(data);
      const dayNames = [...data.DateTimeFormat.DayNames];
      dayNames[1] = "@@@";
      const clone = NodaCultureInfo.FromData({ ...data, DateTimeFormat: { ...data.DateTimeFormat, DayNames: dayNames } });
      expect(clone.Name).toBe(original.Name);

      // Fool Noda Time into believing both are read-only, so it can use a cache...
      // (noda-js: cultures are always read-only.)

      const nodaOriginal = NodaFormatInfo.GetFormatInfo(original);
      const nodaClone = NodaFormatInfo.GetFormatInfo(clone);
      expect(nodaOriginal.LongDayNames[1]).toBe(original.DateTimeFormat.DayNames[1]);
      expect(nodaClone.LongDayNames[1]).toBe(clone.DateTimeFormat.DayNames[1]);
      // Just check we made a difference...
      expect(nodaClone.LongDayNames[1]).not.toBe(nodaOriginal.LongDayNames[1]);
    },

    TestConstructor(initializeEagerly: boolean) {
      const info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, initializeEagerly);
      expect(info.CultureInfo).toBe(enUs);
      expect(info.DateTimeFormat).not.toBeNull();
      expect(info.TimeSeparator).toBe(":");
      expect(info.DateSeparator).toBe("/");
      expect(typeof info.OffsetPatternLong).toBe("string");
      expect(typeof info.OffsetPatternMedium).toBe("string");
      expect(typeof info.OffsetPatternShort).toBe("string");
      expect(info.toString()).toBe("NodaFormatInfo[en-US]");
    },

    TestConstructor_null() {
      assertThrows("ArgumentNullException", () => NodaFormatInfo.NewCultureInfoInitializeEagerly(null!, true));
    },

    TestDateTimeFormat() {
      const format = DateTimeFormatInfo.InvariantInfo;
      const info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, true);
      expect(info.DateTimeFormat).not.toBe(format);
    },

    TestGetFormatInfo() {
      NodaFormatInfo.ClearCache();
      const info1 = NodaFormatInfo.GetFormatInfo(enUs);
      expect(info1).not.toBeNull();

      const info2 = NodaFormatInfo.GetFormatInfo(enUs);
      expect(info2).toBe(info1);

      const info3 = NodaFormatInfo.GetFormatInfo(enGb);
      expect(info3).not.toBe(info1);
    },

    TestGetFormatInfo_null() {
      NodaFormatInfo.ClearCache();
      assertThrows("ArgumentNullException", () => NodaFormatInfo.GetFormatInfo(null!));
    },

    TestGetInstance_CultureInfo() {
      NodaFormatInfo.ClearCache();
      // (C# sets the current culture to en-US here, to check it isn't used; noda-js has no current culture.)
      const actual = NodaFormatInfo.GetInstance(enGb);
      expect(actual.CultureInfo).toBe(enGb);
    },

    TestGetInstance_UnusableType() {
      NodaFormatInfo.ClearCache();
      // C#: CultureInfo.InvariantCulture.NumberFormat (noda-js has no NumberFormatInfo; any other object will do).
      const e = assertThrows("ArgumentException", () => NodaFormatInfo.GetInstance({} as never));
      expect(e).not.toBeNodaError("ArgumentNullException");
    },

    TestGetInstance_DateTimeFormatInfo() {
      NodaFormatInfo.ClearCache();
      const info = NodaFormatInfo.GetInstance(enGb.DateTimeFormat);
      expect(info.DateTimeFormat).toBe(enGb.DateTimeFormat);
      expect(info.CultureInfo).toBe(NodaCultureInfo.InvariantCulture);
    },

    TestOffsetPatternLong() {
      const pattern = "This is a test";
      const info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      expect(info.OffsetPatternLong).not.toBe(pattern);
    },

    TestOffsetPatternMedium() {
      const pattern = "This is a test";
      const info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      expect(info.OffsetPatternMedium).not.toBe(pattern);
    },

    TestOffsetPatternShort() {
      const pattern = "This is a test";
      const info = NodaFormatInfo.NewCultureInfoInitializeEagerly(enUs, false);
      expect(info.OffsetPatternShort).not.toBe(pattern);
    },

    TestGetEraNames() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      const names = info.GetEraNames(Era.BeforeCommon);
      expect(names).toEqual(["B.C.E.", "B.C.", "BCE", "BC"]);
    },

    TestGetEraNames_NoSuchEra() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      expect(info.GetEraNames(Era.NewNameResourceIdentifier("Ignored", "NonExistentResource")).length).toBe(0);
    },

    TestEraGetNames_Null() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      assertThrows("ArgumentNullException", () => info.GetEraNames(null!));
    },

    TestGetEraPrimaryName() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      expect(info.GetEraPrimaryName(Era.BeforeCommon)).toBe("B.C.");
    },

    TestGetEraPrimaryName_NoSuchEra() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      expect(info.GetEraPrimaryName(Era.NewNameResourceIdentifier("Ignored", "NonExistentResource"))).toBe("");
    },

    TestEraGetEraPrimaryName_Null() {
      const info = NodaFormatInfo.GetFormatInfo(enUs);
      assertThrows("ArgumentNullException", () => info.GetEraPrimaryName(null!));
    },

    TestIntegerGenitiveMonthNames() {
      // Emulate behavior of Mono 3.0.6
      const invariant = NodaCultureInfo.InvariantCulture;
      const numbers = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"];
      const culture = NodaCultureInfo.FromData({
        Name: invariant.Name,
        DateTimeFormat: { ...invariant.DateTimeFormat, MonthGenitiveNames: numbers, AbbreviatedMonthGenitiveNames: numbers },
      });
      const info = NodaFormatInfo.GetFormatInfo(culture);
      expect(info.LongMonthNames).toEqual(info.LongMonthGenitiveNames);
      expect(info.ShortMonthNames).toEqual(info.ShortMonthGenitiveNames);
    },
  },
  {
    skip: {
      TestGetInstance_null: "Checks that a null provider means CultureInfo.CurrentCulture; noda-js has no current culture (null means the invariant culture)",
    },
  },
);
