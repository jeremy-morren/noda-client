// Ported from NodaTime 3.3.7: src/NodaTime.TzdbCompiler.Test/ProgramTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TzdbCompiler/ProgramTest.generated.ts";

port(fixture, {}, {
  skip: {
    MergeWindowsZones: "Program (the compiler's command line, including Program.MergeWindowsZones) isn't ported",
  },
});
