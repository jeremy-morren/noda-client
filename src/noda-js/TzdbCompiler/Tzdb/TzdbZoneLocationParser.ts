// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler/Tzdb/TzdbZoneLocationParser.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { Preconditions, TzdbZone1970Location, TzdbZoneLocation } from "../../internal.ts";
import type { TzdbZone1970LocationCountry } from "../../internal.ts";
import { GetValue, ParseInt32 } from "../internal.ts";

/**
 * Separate class for parsing zone location data from zone.tab and iso3166.tab.
 * Stateless, simply static methods - only separated from TzdbZoneInfoCompiler to make the
 * organization a little cleaner.
 * @internal
 */
export class TzdbZoneLocationParser {
  static ParseLocation(line: string, countryMapping: ReadonlyMap<string, string>): TzdbZoneLocation {
    const bits = line.split("\t");
    Preconditions.CheckArgument(bits.length === 3 || bits.length === 4, "line", "Line must have 3 or 4 tab-separated values");
    const countryCode = bits[0]!;
    const countryName = GetValue(countryMapping, countryCode);
    const latLong = TzdbZoneLocationParser.ParseCoordinates(bits[1]!);
    const zoneId = bits[2]!;
    const comment = bits.length === 4 ? bits[3]! : "";
    return new TzdbZoneLocation(latLong[0]!, latLong[1]!, countryName, countryCode, zoneId, comment);
  }

  static ParseEnhancedLocation(line: string, countryMapping: ReadonlyMap<string, TzdbZone1970LocationCountry>): TzdbZone1970Location {
    const bits = line.split("\t");
    Preconditions.CheckArgument(bits.length === 3 || bits.length === 4, "line", "Line must have 3 or 4 tab-separated values");
    const countryCodes = bits[0]!;
    const countries = countryCodes.split(",").map(code => GetValue(countryMapping, code));
    const latLong = TzdbZoneLocationParser.ParseCoordinates(bits[1]!);
    const zoneId = bits[2]!;
    const comment = bits.length === 4 ? bits[3]! : "";
    return new TzdbZone1970Location(latLong[0]!, latLong[1]!, countries, zoneId, comment);
  }

  // Internal for testing
  /**
   * Parses a string such as "-7750+16636" or "+484531-0913718" into a pair of Int32
   * values: the latitude and longitude of the coordinates, in seconds.
   */
  static ParseCoordinates(text: string): number[] {
    Preconditions.CheckArgument(text.length === 11 || text.length === 15, "point", "Invalid coordinates");
    let latDegrees: number;
    let latMinutes: number;
    let latSeconds = 0;
    let latSign: number;
    let longDegrees: number;
    let longMinutes: number;
    let longSeconds = 0;
    let longSign: number;

    if (text.length === 11 /* +-DDMM+-DDDMM */) {
      latSign = text.charAt(0) === "-" ? -1 : 1;
      latDegrees = ParseInt32(text.substring(1, 3));
      latMinutes = ParseInt32(text.substring(3, 5));
      longSign = text.charAt(5) === "-" ? -1 : 1;
      longDegrees = ParseInt32(text.substring(6, 9));
      longMinutes = ParseInt32(text.substring(9, 11));
    } else /* +-DDMMSS+-DDDMMSS */ {
      latSign = text.charAt(0) === "-" ? -1 : 1;
      latDegrees = ParseInt32(text.substring(1, 3));
      latMinutes = ParseInt32(text.substring(3, 5));
      latSeconds = ParseInt32(text.substring(5, 7));
      longSign = text.charAt(7) === "-" ? -1 : 1;
      longDegrees = ParseInt32(text.substring(8, 11));
      longMinutes = ParseInt32(text.substring(11, 13));
      longSeconds = ParseInt32(text.substring(13, 15));
    }
    return [
      latSign * (latDegrees * 3600 + latMinutes * 60 + latSeconds),
      longSign * (longDegrees * 3600 + longMinutes * 60 + longSeconds),
    ];
  }
}
