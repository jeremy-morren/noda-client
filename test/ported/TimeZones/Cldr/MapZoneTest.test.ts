// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/Cldr/MapZoneTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { MapZone } from "../../../../src/noda-js/internal.ts";
import { port } from "../../../helpers/scenarios.ts";
import { TestHelper } from "../../../helpers/TestHelper.ts";
import { fixture } from "../../../scenarios/TimeZones/Cldr/MapZoneTest.generated.ts";

port(
  fixture,
  {
    Equality() {
      const zone1 = new MapZone("windowsId", "territory", ["id1", "id2", "id3"]);
      const zone2 = new MapZone("windowsId", "territory", ["id1", "id2", "id3"]);
      const zone3 = new MapZone("otherWindowsId", "territory", ["id1", "id2", "id3"]);
      const zone4 = new MapZone("windowsId", "otherTerritory", ["id1", "id2", "id3"]);
      const zone5 = new MapZone("windowsId", "territory", ["id1", "id2"]);
      const zone6 = new MapZone("windowsId", "territory", ["id1", "id2", "id4"]);
      TestHelper.testEqualsClass(zone1, zone2, zone3);
      TestHelper.testEqualsClass(zone1, zone2, zone4);
      TestHelper.testEqualsClass(zone1, zone2, zone5);
      TestHelper.testEqualsClass(zone1, zone2, zone6);
    },

    ToString() {
      const zone = new MapZone("windowsId", "territory", ["id1", "id2", "id3"]);
      const expected = "Windows ID: windowsId; Territory: territory; TzdbIds: id1 id2 id3";
      expect(zone.toString()).toBe(expected);
    },
  },
  {
    skip: {
      ReadWrite: "Needs DateTimeZoneWriter (MapZone.Write), which isn't ported",
    },
  },
);
