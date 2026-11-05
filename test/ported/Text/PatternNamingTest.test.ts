// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/PatternNamingTest.cs
// Copyright 2016 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: C# reflects over every type in the NodaTime assembly; here we reflect over every export of the
// noda-js modules (src/noda-js/internal.ts), with static getters standing in for static properties.

import { expect } from "vitest";
import * as noda from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/PatternNamingTest.generated.ts";

port(fixture, {
  // https://github.com/nodatime/nodatime/issues/556
  NoPatternSuffix() {
    const properties: string[] = [];
    for (const [name, type] of Object.entries(noda)) {
      if (typeof type !== "function" || !name.endsWith("Pattern")) {
        continue;
      }
      for (const [propertyName, descriptor] of Object.entries(Object.getOwnPropertyDescriptors(type))) {
        if (descriptor.get !== undefined && propertyName.endsWith("Pattern")) {
          properties.push(`${name}.${propertyName}`);
        }
      }
    }
    expect(properties, `Badly named properties: ${properties.join(", ")}`).toEqual([]);
  },
});
