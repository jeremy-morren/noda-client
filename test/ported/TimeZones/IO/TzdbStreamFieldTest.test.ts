// Ported from NodaTime 3.3.0: src/NodaTime.Test/TimeZones/IO/TzdbStreamFieldTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: DateTimeZoneWriter isn't ported, so the stream holds the bytes the C# test writes (see DtzIoHelper.ts).

import { InvalidNodaDataError, MemoryStream, TzdbStreamField } from "../../../../src/noda-js/internal.ts";
import { assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/TzdbStreamFieldTest.generated.ts";
import { countBytes } from "./DtzIoHelper.ts";

port(fixture, {
  // Only tests for situations which aren't covered elsewhere

  InsufficientData() {
    // writer.WriteByte(1); writer.WriteCount(10);
    const stream = new MemoryStream(Uint8Array.from([1, ...countBytes(10)]));
    const iterator = TzdbStreamField.ReadFields(stream)[Symbol.iterator]();

    assertThrows(InvalidNodaDataError, () => iterator.next());
  },
});
