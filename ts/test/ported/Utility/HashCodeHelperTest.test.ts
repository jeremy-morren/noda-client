// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/HashCodeHelperTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Utility/HashCodeHelperTest.generated.ts";

const NotPorted = "HashCodeHelper isn't ported: noda-js has no GetHashCode (docs/porting-conventions.md)";

port(fixture, {}, {
  skip: {
    Hash_Nulls: NotPorted,
  },
});
