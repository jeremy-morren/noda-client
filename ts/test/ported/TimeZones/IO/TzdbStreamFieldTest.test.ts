// Ported from NodaTime 3.3.7: src/NodaTime.Test/TimeZones/IO/TzdbStreamFieldTest.cs
// Copyright 2009 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.

import { DateTimeZoneWriter, InvalidNodaDataException, MemoryStream, TzdbStreamField } from "../../../../src/noda-js/internal.ts";
import { assertThrows } from "../../../helpers/assertions.ts";
import { port } from "../../../helpers/scenarios.ts";
import { fixture } from "../../../scenarios/TimeZones/IO/TzdbStreamFieldTest.generated.ts";

port(fixture, {
  // Only tests for situations which aren't covered elsewhere

  InsufficientData() {
    const stream = new MemoryStream();
    const writer = DateTimeZoneWriter.NewOutputStringPool(stream, null);
    writer.WriteByte(1);
    writer.WriteCount(10);

    stream.Position = 0;
    const iterator = TzdbStreamField.ReadFields(stream)[Symbol.iterator]();

    assertThrows(InvalidNodaDataException, () => iterator.next());
  },
});
