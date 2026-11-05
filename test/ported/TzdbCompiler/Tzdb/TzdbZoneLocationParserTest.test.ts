// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/TzdbZoneLocationParserTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { TzdbZone1970Location } from "../../../../src/noda-js/internal.ts";
import { TzdbZoneLocationParser } from "../../../../src/noda-js/TzdbCompiler/internal.ts";
import { assertNodaEqual, assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/TzdbZoneLocationParserTest.generated.ts";

const SampleCountryMapping: ReadonlyMap<string, string> = new Map([
  ["CA", "Canada"],
  ["GB", "Britain (UK)"],
]);

port(fixture, {
  ParseLocation_InvalidLength(line: string) {
    assertThrows("ArgumentException", () => TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping));
  },

  ParseLocation_InvalidCountryCode() {
    // Valid line, but not with our country code mapping...
    const line = "FK\t-5142-05751\tAtlantic/Stanley";
    assertThrows("KeyNotFoundException", () => TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping));
  },

  ParseLocation_Valid_NoComment() {
    const line = "GB\t+4000+03000\tEurope/London";
    const location = TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping);
    assertNodaEqual(location.CountryCode, "GB");
    assertNodaEqual(location.CountryName, "Britain (UK)");
    assertNodaEqual(location.Latitude, 40);
    assertNodaEqual(location.Longitude, 30);
    assertNodaEqual(location.ZoneId, "Europe/London");
    assertNodaEqual(location.Comment, "");
  },

  // Most of the code is just from ParseLocation; this is a smoke test, really.
  ParseEnhancedLocation_Valid() {
    const countries = new Map([
      ["CA", new TzdbZone1970Location.Country("Canada", "CA")],
      ["GB", new TzdbZone1970Location.Country("Britain (UK)", "GB")],
      ["US", new TzdbZone1970Location.Country("United States", "US")],
    ]);
    const line = "GB,CA\t+4000+03000\tEurope/London";
    const location = TzdbZoneLocationParser.ParseEnhancedLocation(line, countries);
    assertNodaEqual(location.Countries, [countries.get("GB"), countries.get("CA")]);
    assertNodaEqual(location.Latitude, 40);
    assertNodaEqual(location.Longitude, 30);
    assertNodaEqual(location.ZoneId, "Europe/London");
    assertNodaEqual(location.Comment, "");
  },

  ParseLocation_Valid_WithComment() {
    const line = "GB\t+4000+03000\tEurope/London\tSome comment";
    const location = TzdbZoneLocationParser.ParseLocation(line, SampleCountryMapping);
    assertNodaEqual(location.CountryCode, "GB");
    assertNodaEqual(location.CountryName, "Britain (UK)");
    assertNodaEqual(location.Latitude, 40);
    assertNodaEqual(location.Longitude, 30);
    assertNodaEqual(location.ZoneId, "Europe/London");
    assertNodaEqual(location.Comment, "Some comment");
  },

  ParseCoordinates_InvalidLength() {
    assertThrows("ArgumentException", () => TzdbZoneLocationParser.ParseCoordinates("-77+166"));
  },

  ParseCoordinates_Valid(text: string, expectedLatitude: number, expectedLongitude: number) {
    const actual = TzdbZoneLocationParser.ParseCoordinates(text);
    assertNodaEqual(actual[0], expectedLatitude);
    assertNodaEqual(actual[1], expectedLongitude);
  },
});
