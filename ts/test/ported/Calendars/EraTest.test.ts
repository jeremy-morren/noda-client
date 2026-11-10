// Ported from NodaTime 3.3.7: src/NodaTime.Test/Calendars/EraTest.cs
// Copyright 2013 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { expect } from "vitest";
import { NodaCultureInfo, Era } from "../../../src/noda-js/internal.ts";
import { assertNodaEqual } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Calendars/EraTest.generated.ts";

interface NamedWrapper<T> {
  readonly value: T;
  readonly name: string;
}

port(fixture, {
  ResourcePresence(eraWrapper: NamedWrapper<Era>) {
    const era = eraWrapper.value;
    const valueByName = NodaCultureInfo.InvariantCulture.GetPatternResource(era.ResourceIdentifier);
    expect(valueByName, `Missing resource for ${era.ResourceIdentifier}`).not.toBeNull();
  },

  ToStringReturnsName(eraWrapper: NamedWrapper<Era>) {
    const era = eraWrapper.value;
    assertNodaEqual(era.toString(), era.Name);
  },
});
