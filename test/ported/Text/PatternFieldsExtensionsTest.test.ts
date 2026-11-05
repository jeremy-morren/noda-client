// Ported from NodaTime 3.3.0: src/NodaTime.Test/Text/Patterns/PatternFieldsExtensionsTest.cs
// Copyright 2011 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: the C# extension methods x.HasAny(y) / x.HasAll(y) are the functions hasAny(x, y) / hasAll(x, y).

import { expect } from "vitest";
import { HasAll, HasAny, PatternFields } from "../../../src/noda-js/internal.ts";
import { port } from "../../helpers/scenarios.ts";
import { fixture } from "../../scenarios/Text/PatternFieldsExtensionsTest.generated.ts";

const { Hours12, Hours24, Minutes, Seconds } = PatternFields;

port(fixture, {
  IsUsed_NoMatch() {
    expect(HasAny(Hours12 | Minutes, Hours24)).toBe(false);
  },

  IsUsed_SingleValueMatch() {
    expect(HasAny(Hours24, Hours24)).toBe(true);
  },

  IsFieldUsed_MultiValueMatch() {
    expect(HasAny(Hours24 | Minutes, Hours24)).toBe(true);
  },

  AllAreUsed_NoMatch() {
    expect(HasAll(Hours12 | Minutes, Hours24 | Seconds)).toBe(false);
  },

  AllAreUsed_PartialMatch() {
    expect(HasAll(Hours12 | Minutes, Hours12 | Seconds)).toBe(false);
  },

  AllAreUsed_CompleteMatch() {
    expect(HasAll(Hours12 | Minutes, Hours12 | Minutes)).toBe(true);
  },

  AllAreUsed_CompleteMatchWithMore() {
    expect(HasAll(Hours24 | Minutes | Hours12, Hours24 | Minutes)).toBe(true);
  },
});
