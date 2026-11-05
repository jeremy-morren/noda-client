// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/TzdbZoneLocationTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneWriter isn't ported. ReadInvalid feeds the reader the bytes the C# test writes
// (see IO/DtzIoHelper.ts); Serialization (a write/read round trip) is skipped.

import { expect } from "vitest";
import { ArgumentNullError, ArgumentOutOfRangeError, InvalidNodaDataError, TzdbZoneLocation } from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { TestHelper } from "../../helpers/TestHelper.ts";
import { fixture } from "../../scenarios/TimeZones/TzdbZoneLocationTest.generated.ts";
import { readerFor, signedCountBytes, stringBytes } from "./IO/DtzIoHelper.ts";

port(
  fixture,
  {
    Valid() {
      const location = new TzdbZoneLocation(60 * 3600 + 15 * 60 + 5, 100 * 3600 + 30 * 60 + 10, "Country name", "CO", "Etc/MadeUpZone", "Comment");
      expect(location.Latitude).toBeCloseTo(60.25 + 5.0 / 3600, 6);
      expect(location.Longitude).toBeCloseTo(100.5 + 10.0 / 3600, 6);
      expect(location.CountryName).toBe("Country name");
      expect(location.CountryCode).toBe("CO");
      expect(location.ZoneId).toBe("Etc/MadeUpZone");
      expect(location.Comment).toBe("Comment");
    },

    LatitudeRange() {
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZoneLocation(90 * 3600 + 1, 0, "Name", "CO", "Zone", ""));
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZoneLocation(-90 * 3600 - 1, 0, "Name", "CO", "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZoneLocation(90 * 3600, 0, "Name", "CO", "Zone", "");
      new TzdbZoneLocation(-90 * 3600, 0, "Name", "CO", "Zone", "");
    },

    LongitudeRange() {
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZoneLocation(0, 180 * 3600 + 1, "Name", "CO", "Zone", ""));
      assertThrows(ArgumentOutOfRangeError, () => new TzdbZoneLocation(0, -180 * 3600 - 1, "Name", "CO", "Zone", ""));
      // We'll assume these are built correctly: we're just checking the constructor doesn't throw.
      new TzdbZoneLocation(0, 180 * 3600, "Name", "CO", "Zone", "");
      new TzdbZoneLocation(0, -180 * 3600, "Name", "CO", "Zone", "");
    },

    Constructor_InvalidArguments() {
      assertThrows(ArgumentNullError, () => new TzdbZoneLocation(0, 0, null!, "CO", "Zone", ""));
      assertThrows(ArgumentNullError, () => new TzdbZoneLocation(0, 0, "Name", null!, "Zone", ""));
      assertThrows(ArgumentNullError, () => new TzdbZoneLocation(0, 0, "Name", "CO", null!, ""));
      assertThrows(ArgumentNullError, () => new TzdbZoneLocation(0, 0, "Name", "CO", "Zone", null!));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "", "CO", "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "Name", "Long code", "Zone", ""));
      TestHelper.assertInvalid(() => new TzdbZoneLocation(0, 0, "Name", "S", "Zone", ""));
    },

    ReadInvalid() {
      const bytes = [
        // This is invalid
        ...signedCountBytes(90 * 3600 + 1),
        ...signedCountBytes(0),
        ...stringBytes("name"),
        ...stringBytes("co"),
        ...stringBytes("Europe/Somewhere"),
        ...stringBytes(""),
      ];
      const reader = readerFor(bytes);
      assertThrows(InvalidNodaDataError, () => TzdbZoneLocation.Read(reader));
    },
  },
  {
    skip: {
      Serialization: "Needs DateTimeZoneWriter (TzdbZoneLocation.Write), which isn't ported",
    },
  },
);
