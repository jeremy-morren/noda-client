// Ported from NodaTime 3.3.7: src/NodaTime.Test/Utility/PreconditionsTest.cs
// Copyright 2014 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: Debug* checks are off, as in a release build, so the scenarios are the "NotDebug" variants.

import { expect } from "vitest";
import { Preconditions } from "../../../src/noda-js/internal.ts";
import { assertThrows } from "../../helpers/assertions.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Utility/PreconditionsTest.generated.ts";

port(fixture, {
  // This overload is only called from one place, and only when it's going to fail...
  CheckArgument2_Success() {
    Preconditions.CheckArgument(true, "param", "{0} is {1}", 1, 10);
  },

  CheckArgument2_Failure() {
    const exception = assertThrows("ArgumentException", () => Preconditions.CheckArgument(false, "param", "{0} is {1}", 1, 10));
    expect(exception).not.toBeNodaError("ArgumentNullException");
    expect(exception.ParamName).toBe("param");
    expect(exception.message.includes("1 is 10")).toBe(true);
  },

  // It's really not worth inventing parameters for these...
  DebugCheckArgumentRange_NotDebug() {
    Preconditions.DebugCheckArgumentRange("ignore", 5, 0, 10);
    Preconditions.DebugCheckArgumentRange("ignore", 5, 0, 10);
    Preconditions.DebugCheckArgumentRange("ignore", 10, 0, 5);
    Preconditions.DebugCheckArgumentRange("ignore", 10, 0, 5);
  },

  DebugCheckNotNull_NotDebug() {
    Preconditions.DebugCheckNotNull("value", "ignore");
    Preconditions.DebugCheckNotNull(null as string | null, "ignore");
  },
});
