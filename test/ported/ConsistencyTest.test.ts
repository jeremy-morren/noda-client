// Ported from NodaTime 3.3.0: src/NodaTime.Test/ConsistencyTest.cs
// Copyright 2020 The Noda Time Authors. All rights reserved.
// Use of this source code is governed by the Apache License 2.0,
// as found in the LICENSE.txt file.
//
// noda-js: NodaTime checks its own assembly by reflection. Here the same check runs on NodaTime's public API as
// captured by reflection (test/api/nodatime-api.generated.ts): a type implementing IEquatable<T> (it has
// Equals(T other): bool) must have op_Equality, and one implementing IComparable<T> (CompareTo(T other): int) must
// have op_LessThan and op_LessThanOrEqual. As C# == and < map to equals/compareTo in noda-js, the noda-js type must
// also have those methods.

import { expect } from "vitest";
import * as noda from "../../src/noda-js/internal.ts";
import { notPorted } from "../api/differences.ts";
import { NodaTimeApi } from "../api/nodatime-api.generated.ts";
import type { ApiType } from "../api/types.ts";
import { port } from "../helpers/scenarios.ts";
import { fixture } from "../scenarios/ConsistencyTest.generated.ts";

const AllPublicTypes = NodaTimeApi;

/** Whether the type has an instance method `csName` with a signature `(<type> x): <result>` (IEquatable<T> / IComparable<T>). */
function implementsGeneric(type: ApiType, csName: string, result: string): boolean {
  const pattern = new RegExp(`^\\(${type.name} \\w+\\): ${result}$`);
  return type.members.some(m => m.csName === csName && !m.isStatic && m.signatures.some(s => pattern.test(s)));
}

function hasMember(type: ApiType, csName: string): boolean {
  return type.members.some(m => m.csName === csName);
}

/** The noda-js export of a NodaTime type (exceptions are "...Error"). */
function tsType(type: ApiType): any {
  const name = type.name.endsWith("Exception") ? type.name.slice(0, -"Exception".length) + "Error" : type.name;
  return (noda as any)[name];
}

function hasPrototypeMethod(type: ApiType, name: string): boolean {
  const ctor = tsType(type);
  return typeof ctor === "function" && typeof ctor.prototype?.[name] === "function";
}

port(fixture, {
  EqualityOperatorForEquatable() {
    const expectedExceptions = ["MapZone"];

    const failures = AllPublicTypes
      .filter(t => implementsGeneric(t, "Equals", "bool"))
      .filter(t => !hasMember(t, "op_Equality"))
      .filter(t => expectedExceptions.indexOf(t.name) < 0)
      .map(t => t.name);
    expect(failures).toEqual([]);

    // noda-js: op_Equality is equals().
    const jsFailures = AllPublicTypes
      .filter(t => implementsGeneric(t, "Equals", "bool"))
      .filter(t => notPorted[t.name] === undefined)
      .filter(t => !hasPrototypeMethod(t, "Equals"))
      .map(t => t.name);
    expect(jsFailures).toEqual([]);
  },

  ComparisonOperatorForComparable() {
    const expectedExceptions: string[] = [];

    const failures = AllPublicTypes
      .filter(t => implementsGeneric(t, "CompareTo", "int"))
      .filter(t => !hasMember(t, "op_LessThan") || !hasMember(t, "op_LessThanOrEqual"))
      .filter(t => expectedExceptions.indexOf(t.name) < 0)
      .map(t => t.name);
    expect(failures).toEqual([]);

    // noda-js: op_LessThan and op_LessThanOrEqual are compareTo().
    const jsFailures = AllPublicTypes
      .filter(t => implementsGeneric(t, "CompareTo", "int"))
      .filter(t => notPorted[t.name] === undefined)
      .filter(t => !hasPrototypeMethod(t, "CompareTo"))
      .map(t => t.name);
    expect(jsFailures).toEqual([]);
  },
});
