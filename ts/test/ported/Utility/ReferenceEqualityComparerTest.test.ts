// Ported from NodaTime 6e024dde: src/NodaTime.Test/Utility/ReferenceEqualityComparerTest.cs
// Copyright 2026 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Utility/ReferenceEqualityComparerTest.generated.ts";

const NotPorted = "ReferenceEqualityComparer isn't ported: noda-js's Maps compare objects by reference already, and it has no GetHashCode";

port(fixture, {}, {
  skip: {
    Equals: NotPorted,
    TestGetHashCode: NotPorted,
  },
});
