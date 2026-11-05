// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/Tzdb/CldrWindowsZonesParserTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TzdbCompiler/Tzdb/CldrWindowsZonesParserTest.generated.ts";

const NotPorted = "CldrWindowsZonesParser (CLDR windowsZones.xml parsing) isn't ported: noda-js has the CLDR Windows mapping as generated data";

port(fixture, {}, {
  skip: {
    Versions_Present: NotPorted,
    Versions_Absent: NotPorted,
    MapZones: NotPorted,
  },
});
