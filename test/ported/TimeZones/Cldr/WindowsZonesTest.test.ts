// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/Cldr/WindowsZonesTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the internal WindowsZones constructor is WindowsZones.newVersionTzdbVersionWindowsVersionMapZones.

import { expect } from "vitest";
import { MapZone, WindowsZones } from "../../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/Cldr/WindowsZonesTest.generated.ts";

const MapZone1 = new MapZone("windowsId1", "territory1", ["id1.1", "id1.2", "id1.3"]);
const MapZone2 = new MapZone("windowsId2", MapZone.PrimaryTerritory, ["primaryId2"]);
const MapZone3 = new MapZone("windowsId3", MapZone.PrimaryTerritory, ["primaryId3"]);

port(
  fixture,
  {
    Properties() {
      const zones = WindowsZones.NewVersionTzdbVersionWindowsVersionMapZones("version", "tzdbVersion", "windowsVersion", [MapZone1, MapZone2, MapZone3]);
      expect(zones.Version).toBe("version");
      expect(zones.TzdbVersion).toBe("tzdbVersion");
      expect(zones.WindowsVersion).toBe("windowsVersion");
      expect(zones.PrimaryMapping.get("windowsId2")).toBe("primaryId2");
      expect(zones.PrimaryMapping.get("windowsId3")).toBe("primaryId3");
      assertNodaEqual([...zones.MapZones], [MapZone1, MapZone2, MapZone3]);
    },
  },
  {
    skip: {
      ReadWrite: "Needs DateTimeZoneWriter (WindowsZones.Write), which isn't ported",
    },
  },
);
