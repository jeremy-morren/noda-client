// Ported from NodaTime 6e024dde: src/NodaTime.TzdbCompiler.Test/FileUtilityTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/TzdbCompiler/FileUtilityTest.generated.ts";

const NotPorted = "NodaTime.Tools.Common.FileUtility (loading a file or URL) isn't ported: noda-js/tzdb/compiler takes the " +
  "archive's bytes, URL, Blob or stream (TzdbCompiler/Input.ts) and, like FileUtility, decompresses it if it starts with " +
  "gzip's magic number (TzdbCompiler/Archive.ts; test/tzdb-compiler/)";

port(fixture, {}, {
  skip: {
    LoadFileAsync: NotPorted,
    LoadCompressedUrlAsync: NotPorted,
    LoadUncompressedUrlAsync: NotPorted,
  },
});
